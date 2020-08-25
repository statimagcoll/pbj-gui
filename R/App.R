App <- setRefClass(
  Class = "PBJApp",
  fields = c("webRoot", "painRoot", "statMapRoot", "staticPaths", "routes",
             "token", "csvExt", "niftiExt", "study", "statMapJob"),
  methods = list(
    initialize = function() {
      csvExt <<- "\\.csv$"
      niftiExt <<- "\\.nii(\\.gz)?$"
      webRoot <<- file.path(find.package("pbjGUI"), "inst")
      painRoot <<- file.path(find.package("pain21"), "pain21")
      statMapRoot <<- tempfile()
      dir.create(statMapRoot)

      # setup static paths for httpuv
      staticPaths <<- list(
        "/static"  = httpuv::staticPath(file.path(webRoot, "static"),
                                        indexhtml = TRUE, fallthrough = TRUE)
      )

      # setup routes
      routes <<- list(
        list(method = "GET", path = "^/$", handler = .self$getIndex),
        list(method = "POST", path = "^/browse$", handler = .self$browse),
        list(method = "POST", path = "^/checkDataset$", handler = .self$checkDataset),
        list(method = "POST", path = "^/createStudy$", handler = .self$createStudy),
        list(method = "GET", path = "^/studyImage/", handler = .self$studyImage),
        list(method = "GET", path = "^/hist$", handler = .self$plotHist),
        list(method = "POST", path = "^/createStatMap$", handler = .self$createStatMap),
        list(method = "GET", path = "^/statMap$", handler = .self$getStatMap),
        list(method = "POST", path = "^/performSEI$", handler = .self$performSEI)
      )

      # generate a random token for this session
      token <<- paste(as.character(openssl::rand_bytes(12)), collapse = "")

      study <<- NULL
      statMapJob <<- NULL
    },

    call = function(req) {
      method <- req$REQUEST_METHOD
      path <- req$PATH_INFO
      cat("Method: ", method, " path: ", path, "\n", sep="")
      response <- NULL

      # always check for token
      query <- parseQuery(req)
      if (is.null(query$token) || query$token != token) {
        cat("Bad token\n")
        response <- makeTextResponse('Invalid token', 401L)
        return(response)
      }

      for (route in routes) {
        if (route$method == method && grepl(route$path, path)) {
          cat("Path matched route pattern: ", route$path, "\n", sep="")
          result <- try(route$handler(req, query))
          if (inherits(result, 'try-error')) {
            print(result)
            result <- makeErrorResponse(list(error = as.character(result)))
          }
          response <- result
          break
        }
      }

      if (is.null(response)) {
        # path didn't match (or handler returned NULL), return 404
        cat("Path didn't match or handler returned NULL\n")
        response <- makeTextResponse('Not found', 404L)
      }

      return(response)
    },

    # handler for GET /
    getIndex = function(req, query) {
      # read the study tab template to use as a partial template
      studyTemplate <- getTemplate("study.html")

      # render the main template
      mainTemplate <- getTemplate("index.html")
      vars <- getTemplateVars()
      body <- whisker::whisker.render(mainTemplate, data = vars,
                                      partials = list("study" = studyTemplate))

      # setup the response
      response <- makeHTMLResponse(body)
      return(response)
    },

    # handler for POST /browse
    browse = function(req, query) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      params <- result
      if (is.null(params$path)) {
        path <- getwd()
      } else {
        path <- params$path
      }
      errors <- validatePath(path, dir = TRUE)
      if (!is.null(errors)) {
        response <- makeErrorResponse(list(path = errors))
        return(response)
      }

      ext <- ""
      glob <- ""
      if (!is.null(params$type)) {
        if (params$type == "nifti") {
          ext <- niftiExt
          glob <- "*.nii, *.nii.gz"
        } else if (params$type == "csv") {
          ext <- csvExt
          glob <- "*.csv"
        }
      }

      files <- file.info(list.files(path, full.names = TRUE))
      files$path <- row.names(files)
      files$name <- basename(files$path)
      files <- files[grepl(ext, files$name) | files$isdir,]
      files$type <- ifelse(files$isdir, "folder", "file")
      files <- files[order(!files$isdir, files$name),]

      browseTemplate <- getTemplate("browse.html")
      vars <- list(
        path = path,
        parent = normalizePath(file.path(path, '..')),
        files = rowSplit(files),
        empty = (nrow(files) == 0)
      )
      data <- list(
        html = whisker::whisker.render(browseTemplate, data = vars),
        glob = glob
      )

      # setup the response
      response <- makeJSONResponse(data)
      return(response)
    },

    # handler for POST /checkDataset
    checkDataset = function(req, query) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      params <- result
      errors <- list()
      errors$path <- validatePath(params$path, dir = FALSE, pattern = csvExt)
      if (is.null(errors$path)) {
        # no errors so far
        path <- normalizePath(params$path, mustWork = TRUE)
        dataset <- try(read.csv(path))
        if (inherits(dataset, "try-error")) {
          errors$path <- "is not a valid CSV file"
        }

        # try to guess what columns contain image path information
        columns <- which(apply(dataset, MARGIN = 2,
                               FUN = function(col) any(grepl(niftiExt, col, ignore.case = TRUE))))
        if (length(columns) == 0) {
          errors$path <- "does not contain file paths to NIFTI images"
        } else {
          columns <- names(dataset)[columns]
        }
      }

      if (length(errors) > 0) {
        return(makeErrorResponse(errors))
      }

      template <- getTemplate("checkDataset.html")
      #subdataset <- lapply(1:nrow(dataset), function(i) {
        #list(values = unname(as.list(dataset[i, columns])))
      #})
      vars <- list(
        path = path,
        columns = lapply(columns, function(name) {
          list(name = name, values = dataset[[name]])
        })
      )
      html <- whisker::whisker.render(template, data = vars)

      # setup the response
      response <- makeHTMLResponse(html)
      return(response)
    },

    createStudy = function(req, query) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      params <- result
      errors <- list()
      errors$dataset <- validatePath(params$dataset, dir = FALSE, pattern = csvExt)
      errors$mask <- validatePath(params$mask, dir = FALSE, pattern = niftiExt)
      errors$template <- validatePath(params$template, dir = FALSE, pattern = niftiExt)

      if (is.null(errors$dataset)) {
        path <- normalizePath(params$dataset, mustWork = TRUE)
        dataset <- try(read.csv(path))
        if (inherits(dataset, 'try-error')) {
          errors$dataset <- 'is not a valid CSV file'
        } else {
          # check subject column
          if (is.null(params$subjectColumn)) {
            errors$subjectColumn <- 'is required'
          } else if (!(params$subjectColumn %in% names(dataset))) {
            errors$subjectColumn <- 'is not present in dataset'
          } else {
            # check for valid filenames
            info <- file.info(dataset[[params$subjectColumn]])
            bad <- subset(info, is.na(size))
            if (nrow(bad) > 0) {
              errors$subjectColumn <- paste0("contains missing files: ",
                                             paste(row.names(bad), collapse = ", "))
            }
          }

          # check weights column (if it exists)
          if (!is.null(params$weightsColumn)) {
            if (!(params$weightsColumn %in% names(dataset))) {
              errors$weightsColumn <- 'is not present in dataset'
            } else {
              # check for valid filenames
              info <- file.info(dataset[[params$weightsColumn]])
              bad <- subset(info, is.na(size))
              if (nrow(bad) > 0) {
                errors$weightsColumn <- paste0("contains missing files: ",
                                               paste(row.names(bad), collapse = ", "))
              }
            }
          }
        }
      }

      if (length(errors) > 0) {
        return(makeErrorResponse(errors))
      }

      # create study object
      images <- normalizePath(dataset[[params$subjectColumn]], mustWork = TRUE)
      if (!is.null(params$weightsColumn)) {
        weights <- normalizePath(dataset[[params$weightsColumn]], mustWork = TRUE)
      } else {
        weights <- NULL
      }
      if (params$invertedWeights == "1") {
        W <- NULL
        Winv <- weights
      } else {
        W <- weights
        Winv <- NULL
      }
      mask <- normalizePath(params$mask, mustWork = TRUE)
      template <- normalizePath(params$template, mustWork = TRUE)
      study <<- PBJStudy$new(images, ~ 1, NULL, mask, dataset, W, Winv,
                             template, .outdir = statMapRoot)

      vars <- getTemplateVars()
      visualizeTemplate <- getTemplate("visualize.html")
      visualizeHTML <- whisker::whisker.render(visualizeTemplate, data = vars)

      modelTemplate <- getTemplate("model.html")
      modelHTML <- whisker::whisker.render(modelTemplate, data = vars)

      data <- list(visualize = visualizeHTML, model = modelHTML)
      response <- makeJSONResponse(data)
      return(response)
    },

    # handler for GET /studyImage
    studyImage = function(req, query) {
      # parse path
      path <- req$PATH_INFO
      parts <- strsplit(path, "/")[[1]][c(-1, -2)]

      filename <- NULL
      candidate <- NULL
      ext <- NULL
      if (parts[1] == "subject" || parts[1] == "weight") {
        type <- parts[1]
        md <- regexpr("^([0-9]+)(\\.nii(\\.gz)?)$", parts[2], ignore.case = TRUE, perl = TRUE)
        if (md >= 0) {
          # R's regex support is terrible
          index <- as.integer(substr(parts[2], attr(md, 'capture.start')[1], attr(md, 'capture.start')[1] + attr(md, 'capture.length')[1] - 1))
          ext <- substr(parts[2], attr(md, 'capture.start')[2], attr(md, 'capture.start')[2] + attr(md, 'capture.length')[2] - 1)

          # find candidate file
          candidate <- NULL
          if (type == "subject") {
            if (index >= 1 && index <= length(study$images)) {
              candidate <- study$images[index]
            }
          } else if (type == "weight") {
            weights <- study$getWeights()
            if (!is.null(weights) && index >= 1 && index <= length(weights)) {
              candidate <- weights[index]
            }
          }
        }
      } else {
        md <- regexpr("^(template|mask|statMap)(\\.nii(\\.gz)?)$", parts[1], ignore.case = TRUE, perl = TRUE)
        if (md >= 0) {
          type <- substr(parts[1], attr(md, 'capture.start')[1], attr(md, 'capture.start')[1] + attr(md, 'capture.length')[1] - 1)
          ext <- substr(parts[1], attr(md, 'capture.start')[2], attr(md, 'capture.start')[2] + attr(md, 'capture.length')[2] - 1)

          if (type == "template") {
            candidate <- study$template
          } else if (type == "mask") {
            candidate <- study$mask
          } else if (type == "statMap" && !is.null(study$statMap)) {
            candidate <- study$statMap$stat
          }
        }
      }

      # make sure file extension matches
      if (!is.null(candidate) && !is.null(ext)) {
        ext <- paste0(ext, '$')
        if (grepl(ext, candidate, ignore.case = TRUE)) {
          filename <- candidate
        }
      }

      if (!is.null(filename)) {
        return(makeFileResponse(filename))
      } else {
        return(makeTextResponse("Not found", 404L))
      }
    },

    # handler for GET /hist
    plotHist = function(req, query) {
      errors <- list()
      params <- query
      if (!("var" %in% names(params))) {
        # missing var name
        errors$var <- 'is required'
      } else if (!(params$var %in% study$getNumericVarNames())) {
        # invalid var name
        errors$var <- 'is invalid'
      }
      if (length(errors) > 0) {
        return(makeErrorResponse(errors))
      }

      # plot histogram to PNG
      filename <- tempfile(fileext = "png")
      png(filename)
      study$plotHist(params$var)
      dev.off()

      # setup the response
      response <- makeImageResponse(filename)
      return(response)
    },

    # handler for POST /createStatMap
    createStatMap = function(req, query) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      # validate params
      errors <- list()
      params <- result
      if (!("formfull" %in% names(params))) {
        # missing full formula
        errors$formfull <- 'is required'
      } else {
        formfull <- try(as.formula(params$formfull))
        if (inherits(formfull, 'try-error')) {
          errors$formfull <- 'is invalid'
        }
      }
      if ("formred" %in% names(params) && nzchar(params$formred)) {
        formred <- try(as.formula(params$formred))
        if (inherits(formred, 'try-error')) {
          errors$formred <- 'is invalid'
        }
      } else {
        formred <- NULL
      }
      if (length(errors) > 0) {
        return(makeErrorResponse(errors))
      }

      study$form <<- formfull
      study$formred <<- formred

      result <- try(study$startStatMapJob())
      if (inherits(result, 'try-error')) {
        return(makeErrorResponse(list(error = unbox(as.character(result)))))
      }

      response <- makeJSONResponse(list(running = unbox(TRUE)))
      return(response)
    },

    # handler for GET /statMap
    getStatMap = function(req, query) {
      data <- list()
      status <- 200L

      if (study$hasStatMapJob()) {
        # job is running or just finished
        data$log <- unbox(study$getStatMapJobLog())

        if (study$isStatMapJobRunning()) {
          # job is still running
          data$status <- unbox("running")
        } else {
          # job finished successfully or failed
          result <- study$finalizeStatMapJob()
          if (inherits(result, "try-error")) {
            data$status <- unbox("failed")
            status <- 500L
          } else {
            data$status <- unbox("finished")
          }
        }
      }

      if (study$hasStatMap()) {
        # statMap exists, render template
        statMapTemplate <- getTemplate("statMap.html")
        vars <- getTemplateVars()
        data$html <- whisker::whisker.render(statMapTemplate, data = vars)

        if (is.null(data$status)) {
          data$status <- unbox("finished")
        }
      }

      if (length(data) == 0) {
        response <- makeTextResponse('Not found', 404L)
      } else {
        response <- makeJSONResponse(data, status)
      }
      return(response)
    },

    # handler for POST /performSEI
    performSEI = function(req, query) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      # validate params
      errors <- list()
      params <- result
      if (!("cftLower" %in% names(params))) {
        # missing CFT lower bound
        errors$cftLower <- 'is required'
      } else {
        cftLower <- as.numeric(params$cftLower)
        if (is.na(cftLower)) {
          errors$cftLower <- 'is invalid'
        } else if (cftLower < 0.00001) {
          errors$cftLower <- 'is too small'
        } else if (cftLower > 0.99999) {
          errors$cftLower <- 'is too large'
        }
      }
      if (!("cftUpper" %in% names(params))) {
        # missing CFT upper bound
        errors$cftUpper <- 'is required'
      } else {
        cftUpper <- as.numeric(params$cftUpper)
        if (is.na(cftUpper)) {
          errors$cftUpper <- 'is invalid'
        } else if (cftUpper < 0.00001) {
          errors$cftUpper <- 'is too small'
        } else if (cftUpper > 0.99999) {
          errors$cftUpper <- 'is too large'
        }
      }
      if (is.null(errors$cftLower) && is.null(errors$cftUpper) && cftLower > cftUpper) {
        errors$cftLower <- 'must be less than or equal to cftUpper'
      }
      if (!("nboot" %in% names(params))) {
        errors$nboot <- 'is required'
      } else {
        nboot <- as.integer(params$nboot)
        if (is.na(nboot)) {
          errors$nboot <- 'is invalid'
        } else if (nboot < 1) {
          errors$nboot <- 'is too small'
        }
      }

      if (length(errors) > 0) {
        return(makeErrorResponse(errors))
      }

      study$cfts.s <<- c(cftLower, cftUpper)
      study$nboot <<- nboot
      result <- try(study$performSEI())
      if (inherits(result, 'try-error')) {
        print(result)
        return(makeErrorResponse(list(error = as.character(result))))
      }

      seiTemplate <- getTemplate("sei.html")
      vars <- getTemplateVars()
      body <- whisker::whisker.render(seiTemplate, data = vars)
      response <- makeHTMLResponse(body)
      return(response)
    },

    getTemplate = function(templateName) {
      templateFile <- file.path(webRoot, "templates", templateName)
      template <- readChar(templateFile, file.info(templateFile)$size)
      return(template)
    },

    getTemplateVars = function() {
      result <- list(
        token = token,
        painRoot = painRoot
      )

      if (!is.null(study)) {
        result$study <- list(
          form = paste(as.character(study$form), collapse = " "),
          formred = paste(as.character(study$formred), collapse = " "),
          plots = lapply(study$getNumericVarNames(), function(var) {
            paste0("/hist?token=", token, "&var=", var)
          }),
          cftLower = study$cfts.s[1],
          cftUpper = study$cfts.s[2],
          nboot = study$nboot
        )

        # get file extension for template image
        hasTemplate <- !is.null(study$template)
        if (hasTemplate) {
          md <- regexpr(niftiExt, study$template)
          templateExt <- substr(study$template, md, md + attr(md, 'match.length') - 1)
        } else {
          templateExt <- NULL
        }

        # create list of data rows for visualization template
        weights <- study$getWeights()
        hasWeight <- !is.null(weights)
        result$study$dataRows <- lapply(1:length(study$images), function(i) {
          # get file extension for subject image
          md <- regexpr(niftiExt, study$images[i])
          subjectExt <- substr(study$images[1], md, md + attr(md, 'match.length') - 1)

          # get file extension for weight image
          if (hasWeight) {
            md <- regexpr(niftiExt, weights[i])
            weightExt <- substr(weights[i], md, md + attr(md, 'match.length') - 1)
          } else {
            weightExt <- NULL
          }
          list(index = i, selected = (i == 1), hasTemplate = hasTemplate,
               templateExt = templateExt, subjectExt = subjectExt,
               weightExt = weightExt, hasWeight = hasWeight)
        })

        statMap <- NULL
        if (!is.null(study$statMap)) {
          # get file extension for statMap image
          md <- regexpr(niftiExt, study$statMap$stat)
          statMapExt <- substr(study$statMap$stat, md, md + attr(md, 'match.length') - 1)

          statMap <- list(
            hasTemplate = hasTemplate, templateExt = templateExt,
            statMapExt = statMapExt
          )
        }
        result$study$statMap <- statMap

        sPBJ <- NULL
        if (!is.null(study$sPBJ)) {
          sPBJ <- paste(capture.output(print(study$sPBJ)), collapse = "\n")
        }
        result$study$sPBJ <- sPBJ
      }

      return(result)
    },

    makeHTMLResponse = function(body, status = 200L) {
      response <- list(
        status = status, headers = list("Content-Type" = "text/html"),
        body = body
      )
      return(response)
    },

    makeTextResponse = function(body, status = 200L) {
      response <- list(
        status = status, headers = list("Content-Type" = "text/plain"),
        body = body
      )
      return(response)
    },

    makeErrorResponse = function(errors, status = 400L) {
      response <- list(
        status = status, headers = list("Content-Type" = "application/json"),
        body = toJSON(errors)
      )
      class(response) <- c('error')
      return(response)
    },

    makeImageResponse = function(filename, type = "png", status = 200L) {
      contentType <- paste0("image/", type)
      return(makeFileResponse(filename, contentType, status))
    },

    makeFileResponse = function(filename, contentType = "application/octet-stream", status = 200L) {
      response <- list(
        status = status,
        headers = list("Content-Type" = contentType),
        body = c(file = filename)
      )
      return(response)
    },

    makeJSONResponse = function(data, status = 200L) {
      response <- list(
        status = status, headers = list("Content-Type" = "application/json"),
        body = toJSON(data)
      )
      return(response)
    },

    parsePost = function(req) {
      # parse request data as JSON
      result <- try({
        jsonlite::fromJSON(rawToChar(req$rook.input$read()), simplifyVector = FALSE)
      }, silent = TRUE)

      if (inherits(result, "try-error")) {
        print(result)
        response <- makeErrorResponse(list(error = "invalid JSON"))
        return(response)
      }

      return(result)
    },

    parseQuery = function(req) {
      result <- list()

      # parse query in URI
      query <- decodeURIComponent(req$QUERY_STRING)
      if (substr(query, 1, 1) != "?") {
        # invalid/empty query string
        return(result)
      }
      query <- substring(query, 2)

      parts <- strsplit(query, "&", fixed = TRUE)[[1]]
      parts <- strsplit(parts, "=", fixed = TRUE)
      for (part in parts) {
        name <- part[1]
        value <- part[2]
        result[[name]] <- value
      }

      return(result)
    },

    validatePath = function(path, dir = FALSE, pattern = NULL) {
      errors <- NULL
      if (is.null(path)) {
        errors <- "is required"
      } else if (!is.character(path)) {
        errors <- "must be a character vector"
      } else if (length(path) != 1) {
        errors <- "must have only 1 value"
      } else if (!nzchar(path)) {
        errors <- "must not be empty"
      } else if (!file.exists(path)) {
        errors <- "does not exist"
      } else if (file.info(path)$isdir != dir) {
        if (dir) {
          errors <- "must be a directory"
        } else {
          errors <- "must be a regular file"
        }
      } else if (!is.null(pattern) && !grepl(pattern, path, ignore.case = TRUE)) {
        errors <- paste0("must match pattern: ", pattern)
      } else {
        result <- try(normalizePath(path, mustWork = TRUE))
        if (inherits(result, 'try-error')) {
          errors <- "is invalid"
        }
      }
      return(errors)
    }
  )
)

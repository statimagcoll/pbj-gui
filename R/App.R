App <- setRefClass(
  Class = "PBJApp",
  fields = c("webRoot", "painRoot", "statMapRoot", "staticPaths", "routes",
             "token", "study"),
  methods = list(
    initialize = function() {
      webRoot <<- file.path(find.package("pbjGUI"), "inst")
      painRoot <<- file.path(find.package("pain21"), "pain21")
      statMapRoot <<- tempfile()
      dir.create(statMapRoot)

      # setup static paths for httpuv
      staticPaths <<- list(
        "/static"  = httpuv::staticPath(file.path(webRoot, "static"),
                                        indexhtml = TRUE, fallthrough = TRUE),
        "/statMap" = httpuv::staticPath(statMapRoot, fallthrough = TRUE)
      )

      # setup routes
      routes <<- list(
        list(method = "GET", path = "/", handler = .self$getIndex),
        list(method = "POST", path = "/browse", handler = .self$browse),
        list(method = "POST", path = "/checkDataset", handler = .self$checkDataset),
        list(method = "GET", path = "/hist", handler = .self$plotHist),
        list(method = "POST", path = "/createStatMap", handler = .self$createStatMap),
        list(method = "POST", path = "/performSEI", handler = .self$performSEI)
      )

      # generate a random token for this session
      token <<- paste(as.character(openssl::rand_bytes(12)), collapse = "")
      study <<- NULL
    },

    call = function(req) {
      method <- req$REQUEST_METHOD
      path <- req$PATH_INFO
      response <- NULL

      # always check for token
      query <- parseQuery(req)
      if (is.null(query$token) || query$token != token) {
        response <- makeTextResponse('Invalid token', 401L)
        return(response)
      }

      for (route in routes) {
        if (route$method == method && route$path == path) {
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
      path <- try(normalizePath(path, mustWork = TRUE))
      if (inherits(path, 'try-error')) {
        response <- makeErrorResponse(list(path = unbox("is invalid")))
        return(response)
      }

      ext <- ""
      glob <- ""
      if (!is.null(params$type)) {
        if (params$type == "nifti") {
          ext <- ".nii.gz$"
          glob <- "*.nii.gz"
        } else if (params$type == "csv") {
          ext <- ".csv$"
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
      if (is.null(params$path)) {
        errors$path <- "is required"
      } else if (length(params$path) != 1) {
        errors$path <- "must have only 1 value"
      } else if (!nzchar(params$path)) {
        errors$path <- "is required"
      } else if (!file.exists(params$path)) {
        errors$path <- "does not exist"
      } else if (file.info(params$path)$isdir) {
        errors$path <- "must be a regular file"
      } else if (!grepl(".csv$", params$path, ignore.case = TRUE)) {
        errors$path <- "must be a CSV file"
      } else {
        # no errors so far
        path <- normalizePath(params$path, mustWork = TRUE)
        dataset <- try(read.csv(path))
        if (inherits(dataset, "try-error")) {
          errors$path <- "is not a valid CSV file"
        }

        # try to guess what columns contain image path information
        columns <- grep("nii\\.gz", dataset, ignore.case=TRUE)
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

    # handler for POST /statMap
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
      result <- try(study$createStatMap())
      if (inherits(result, 'try-error')) {
        print(result)
        return(makeErrorResponse(list(error = as.character(result))))
      }

      statMapTemplate <- getTemplate("statMap.html")
      vars <- getTemplateVars()
      body <- whisker::whisker.render(statMapTemplate, data = vars)
      response <- makeHTMLResponse(body)
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

    #createSession = function() {
      ## generate a random token for this session
      #token <<- paste(as.character(openssl::rand_bytes(12)), collapse = "")

      ## create study object
      #pain <- pain21()
      #outdir <- file.path(statMapRoot, token)
      #dir.create(outdir)
      #study <- PBJStudy$new(pain$data$images, ~ 1, NULL, pain$mask, pain$data,
                            #Winv = pain$data$varimages,
                            #template = pain$template, .outdir = outdir)

      ## save session
      #sessions[[token]] <<- list(token = token, study = study)
      #return(token)
    #},

    getTemplate = function(templateName) {
      templateFile <- file.path(webRoot, "templates", templateName)
      template <- readChar(templateFile, file.info(templateFile)$size)
      return(template)
    },

    getImageUrl = function(path) {
      result <- sub(paste0("^", painRoot), "/pain21", path)
      result <- sub(paste0("^", statMapRoot), "/statMap", result)
      return(result)
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

        # setup data images
        images <- study$getImages()
        for (name in names(images)) {
          # convert study paths to URLs
          images[[name]] <- getImageUrl(images[[name]])
        }
        images$index <- 1:nrow(images)
        images$selected <- 1:nrow(images) == 1
        result$study$dataRows <- whisker::rowSplit(images)

        # setup statmap images
        statMap <- NULL
        if (!is.null(study$statMap)) {
          statMap <- list(
            stat = getImageUrl(study$statMap$stat),
            template = getImageUrl(study$statMap$template)
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
      response <- list(
        status = status,
        headers = list("Content-Type" = paste0("image/", type)),
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
    }
  )
)

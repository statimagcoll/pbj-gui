App <- setRefClass(
  Class = "PBJApp",
  fields = c("webRoot", "painRoot", "statMapRoot", "sessions", "staticPaths",
             "routes"),
  methods = list(
    initialize = function() {
      webRoot <<- file.path(find.package("pbjGUI"), "inst")
      painRoot <<- file.path(find.package("pain21"), "pain21")
      statMapRoot <<- tempfile()
      dir.create(statMapRoot)
      sessions <<- list()

      # setup static paths for httpuv
      staticPaths <<- list(
        "/static"  = httpuv::staticPath(file.path(webRoot, "static"),
                                        indexhtml = TRUE, fallthrough = TRUE),
        "/pain21"  = httpuv::staticPath(painRoot, fallthrough = TRUE),
        "/statMap" = httpuv::staticPath(statMapRoot, fallthrough = TRUE)
      )

      routes <<- list(
        list(method = "GET", path = "/", handler = .self$getIndex),
        list(method = "GET", path = "/hist", handler = .self$plotHist),
        list(method = "POST", path = "/createStatMap", handler = .self$createStatMap),
        list(method = "POST", path = "/performSEI", handler = .self$performSEI)
      )
    },

    call = function(req) {
      method <- req$REQUEST_METHOD
      path <- req$PATH_INFO
      response <- NULL

      for (route in routes) {
        if (route$method == method && route$path == path) {
          result <- try(route$handler(req))
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
    getIndex = function(req) {
      # create a new session
      token <- createSession()

      # read the study tab template to use as a partial template
      studyTemplate <- getTemplate("study.html")

      # render the main template
      mainTemplate <- getTemplate("index.html")
      vars <- getTemplateVars(token)
      body <- whisker::whisker.render(mainTemplate, data = vars,
                                      partials = list("study" = studyTemplate))

      # setup the response
      response <- makeHTMLResponse(body)
      return(response)
    },

    # handler for GET /hist
    plotHist = function(req) {
      result <- parseGet(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      errors <- list()
      params <- result
      session <- getSession(params$token)
      if (!("var" %in% names(params))) {
        # missing var name
        errors$var <- 'is required'
      } else if (!(params$var %in% session$study$getNumericVarNames())) {
        # invalid var name
        errors$var <- 'is invalid'
      }
      if (length(errors) > 0) {
        return(makeErrorResponse(errors))
      }

      # plot histogram to PNG
      filename <- tempfile(fileext = "png")
      png(filename)
      session$study$plotHist(params$var)
      dev.off()

      # setup the response
      response <- makeImageResponse(filename)
      return(response)
    },

    # handler for POST /statMap
    createStatMap = function(req) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      # validate params
      errors <- list()
      params <- result
      session <- getSession(params$token)
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

      study <- session$study
      study$form <- formfull
      study$formred <- formred
      result <- try(study$createStatMap())
      if (inherits(result, 'try-error')) {
        print(result)
        return(makeErrorResponse(list(error = as.character(result))))
      }

      statMapTemplate <- getTemplate("statMap.html")
      vars <- getTemplateVars(params$token)
      body <- whisker::whisker.render(statMapTemplate, data = vars)
      response <- makeHTMLResponse(body)
      return(response)
    },

    # handler for POST /performSEI
    performSEI = function(req) {
      result <- parsePost(req)
      if (inherits(result, 'error')) {
        # parsePost returned an error response
        return(result)
      }

      # validate params
      errors <- list()
      params <- result
      session <- getSession(params$token)
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

      study <- session$study
      study$cfts.s <- c(cftLower, cftUpper)
      study$nboot <- nboot
      result <- try(study$performSEI())
      if (inherits(result, 'try-error')) {
        print(result)
        return(makeErrorResponse(list(error = as.character(result))))
      }

      seiTemplate <- getTemplate("sei.html")
      vars <- getTemplateVars(params$token)
      body <- whisker::whisker.render(seiTemplate, data = vars)
      response <- makeHTMLResponse(body)
      return(response)
    },

    createSession = function() {
      # generate a random token
      token <- paste(as.character(openssl::rand_bytes(12)), collapse = "")

      # create study object
      pain <- pain21()
      outdir <- file.path(statMapRoot, token)
      dir.create(outdir)
      study <- PBJStudy$new(pain$data$images, ~ 1, NULL, pain$mask, pain$data,
                            Winv = pain$data$varimages,
                            template = pain$template, .outdir = outdir)

      # save session
      sessions[[token]] <<- list(token = token, study = study)
      return(token)
    },

    getSession = function(token) {
      return(sessions[[token]])
    },

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

    getTemplateVars = function(token) {
      session <- getSession(token)
      study <- session$study

      # setup data images
      images <- study$getImages()
      for (name in names(images)) {
        # convert study paths to URLs
        images[[name]] <- getImageUrl(images[[name]])
      }
      images$index <- 1:nrow(images)
      images$selected <- 1:nrow(images) == 1

      # setup statmap images
      statMap <- list()
      if (!is.null(study$statMap)) {
        statMap$stat <- getImageUrl(study$statMap$stat)
        statMap$template <- getImageUrl(study$statMap$template)
      }

      sPBJ <- NULL
      if (!is.null(study$sPBJ)) {
        sPBJ <- paste(capture.output(print(study$sPBJ)), collapse = "\n")
      }

      list(
        token = session$token,
        study = list(
          dataRows = whisker::rowSplit(images),
          form = paste(as.character(study$form), collapse = " "),
          formred = paste(as.character(study$formred), collapse = " "),
          plots = lapply(study$getNumericVarNames(), function(var) {
            paste0("/hist?token=", token, "&var=", var)
          }),
          statMap = statMap,
          cftLower = study$cfts.s[1],
          cftUpper = study$cfts.s[2],
          nboot = study$nboot,
          sPBJ = sPBJ
        )
      )
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

    validateToken = function(params) {
      # check for token in params list
      errors <- list()
      if (!("token" %in% names(params))) {
        errors$token <- "is required"
      } else {
        session <- getSession(params$token)
        if (is.null(session)) {
          errors$token <- "is invalid"
        }
      }
      if (length(errors) > 0) {
        response <- makeErrorResponse(errors)
        return(response)
      }
      return(errors)
    },

    parsePost = function(req) {
      # parse request data as JSON
      params <- try({
        jsonlite::fromJSON(rawToChar(req$rook.input$read()), simplifyVector = FALSE)
      }, silent = TRUE)

      if (inherits(params, "try-error")) {
        print(params)
        response <- makeErrorResponse(list(error = "invalid JSON"))
        return(response)
      }

      # check for token, which is always required
      result <- validateToken(params)
      if (inherits(result, "error")) {
        return(result)
      }

      return(params)
    },

    parseGet = function(req) {
      # parse query in URI
      query <- decodeURIComponent(req$QUERY_STRING)
      if (substr(query, 1, 1) != "?") {
        return(makeErrorResponse(list(error = "invalid query string")))
      }
      query <- substring(query, 2)

      params <- list()
      parts <- strsplit(query, "&", fixed = TRUE)[[1]]
      parts <- strsplit(parts, "=", fixed = TRUE)
      for (part in parts) {
        name <- part[1]
        value <- part[2]
        params[[name]] <- value
      }

      # check for token, which is always required
      result <- validateToken(params)
      if (inherits(result, "error")) {
        return(result)
      }

      return(params)
    }
  )
)

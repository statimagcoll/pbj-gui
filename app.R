library(pain21)
library(pbj)
library(httpuv)
library(whisker)
library(openssl)
library(jsonlite)

PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "form", "formred", "mask", "data", "W", "Winv",
             "template", "formImages", "robust", "sqrtSigma", "transform",
             "outdir", "zeros", "mc.cores", "statMap", "cfts.s", "cfts.p",
             "nboot", "kernel", "rboot", "debug", "sPBJ"),
  methods = list(
    initialize = function(images, form, formred, mask, data = NULL, W = NULL,
                          Winv = NULL, template = NULL, formImages = NULL,
                          robust = TRUE, sqrtSigma = TRUE, transform = TRUE,
                          zeros = FALSE, mc.cores = getOption("mc.cores", 2L),
                          cfts.s = c(0.1, 0.25), cfts.p = NULL, nboot = 5000,
                          kernel = "box", rboot = stats::rnorm, debug = FALSE,
                          outdir = NULL) {

      images <<- images
      form <<- form
      formred <<- formred
      mask <<- mask
      data <<- data
      W <<- W
      Winv <<- Winv
      template <<- template
      formImages <<- formImages
      robust <<- robust
      sqrtSigma <<- sqrtSigma
      transform <<- transform
      zeros <<- zeros
      mc.cores <<- mc.cores
      cfts.s <<- cfts.s
      cfts.p <<- cfts.p
      nboot <<- nboot
      kernel <<- kernel
      rboot <<- rboot
      debug <<- debug

      if (is.null(outdir)) {
        # create temporary directory for output
        outdir <<- tempfile()
        dir.create(outdir)
      }
      outdir <<- outdir

      # set computed fields to NULL
      statMap <<- NULL
      sPBJ <<- NULL
    },

    createStatMap = function() {
      statMap <<- lmPBJ(images, form, formred, mask, data, W, Winv, template,
                        formImages, robust, sqrtSigma, transform, outdir,
                        zeros, mc.cores)
    },

    performSEI = function() {
      if (is.null(statMap)) {
        stop("run createStatMap() first")
      }
      sPBJ <<- pbjSEI(statMap, cfts.s, cfts.p, nboot, kernel, rboot, debug)
    },

    getImages = function() {
      result <- data.frame(image = images, template = template)

      if (!is.null(W)) {
        result$weight <- W
      } else if (!is.null(Winv)) {
        result$weight <- Winv
      } else {
        result$weight <- NA
      }

      return(result)
    },

    getNumericVarNames = function() {
      Filter(function(i) length(intersect(class(data[[i]]), c("integer", "numeric"))) > 0, names(data))
    },

    plotHist = function(name) {
      hist(data[[name]], main = name, xlab = "")
    }
  )
)

# create App class for httpuv
App <- setRefClass(
  Class = "PBJApp",
  fields = c("root", "painRoot", "statMapRoot", "sessions", "staticPaths",
             "routes"),
  methods = list(
    initialize = function() {
      root <<- getwd()
      painRoot <<- file.path(find.package("pain21"), "pain21")
      statMapRoot <<- tempfile()
      dir.create(statMapRoot)
      sessions <<- list()

      # setup static paths for httpuv
      staticPaths <<- list(
        "/static" = staticPath(file.path(root, "static"), indexhtml = TRUE,
                               fallthrough = TRUE),
        "/pain21" = staticPath(painRoot, fallthrough = TRUE),
        "/statMap" = staticPath(statMapRoot, fallthrough = TRUE)
      )

      routes <<- list(
        list(method = "GET", path = "/", handler = .self$getIndex),
        list(method = "GET", path = "/hist", handler = .self$plotHist),
        list(method = "POST", path = "/createStatMap", handler = .self$createStatMap)
      )
    },

    call = function(req) {
      method <- req$REQUEST_METHOD
      path <- req$PATH_INFO
      response <- NULL

      for (route in routes) {
        if (route$method == method && route$path == path) {
          response <- route$handler(req)
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

      # read the study data tab template to use as a partial template
      dataTemplate <- getTemplate("data.html")

      # read the study model tab template to use as a partial template
      modelTemplate <- getTemplate("model.html")

      # render the main template
      mainTemplate <- getTemplate("index.html")
      vars <- getTemplateVars(token)
      body <- whisker.render(mainTemplate, data = vars,
                             partials = list("data" = dataTemplate,
                                             "model" = modelTemplate))

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
        return(makeErrorResponse(list(error = as.character(result))))
      }

      statMapTemplate <- getTemplate("statMap.html")
      vars <- getTemplateVars(params$token)
      body <- whisker.render(statMapTemplate, data = vars)
      response <- makeHTMLResponse(body)
      return(response)
    },

    createSession = function() {
      # generate a random token
      token <- paste(as.character(rand_bytes(12)), collapse = "")

      # create study object
      pain <- pain21()
      outdir <- file.path(statMapRoot, token)
      dir.create(outdir)
      study <- PBJStudy$new(pain$data$images, ~ 1, NULL, pain$mask, pain$data,
                            Winv = pain$data$varimages,
                            template = pain$template, outdir = outdir)

      # save session
      sessions[[token]] <<- list(token = token, study = study)
      return(token)
    },

    getSession = function(token) {
      return(sessions[[token]])
    },

    getTemplate = function(templateName) {
      templateFile <- file.path(root, "templates", templateName)
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

      list(
        token = session$token,
        study = list(
          dataRows = rowSplit(images),
          form = paste(as.character(study$form), collapse = " "),
          formred = paste(as.character(study$formred), collapse = " "),
          plots = lapply(study$getNumericVarNames(), function(var) {
            paste0("/hist?token=", token, "&var=", var)
          }),
          statMap = statMap
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
        fromJSON(rawToChar(req$rook.input$read()), simplifyVector = FALSE)
      }, silent = TRUE)

      if (inherits(params, "try-error")) {
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

app <- App$new()
server <- startServer("127.0.0.1", 37212, app)
if (interactive()) {
  browseURL("http://localhost:37212")
} else {
  cat("Running on http://localhost:37212\n", file = stderr())
  while(TRUE) {
    service()
  }
  server$stop()
}

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
                          kernel = "box", rboot = stats::rnorm, debug = FALSE) {

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

      # create temporary directory for output
      outdir <<- tempfile()
      dir.create(outdir)

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
    }
  )
)

# create App class for httpuv
App <- setRefClass(
  Class = "PBJApp",
  fields = c("root", "painRoot", "sessions", "staticPaths", "routes"),
  methods = list(
    initialize = function() {
      root <<- getwd()
      painRoot <<- file.path(find.package("pain21"), "pain21")
      sessions <<- list()

      # setup static paths for httpuv
      staticPaths <<- list(
        "/static" = staticPath(file.path(root, "static"), indexhtml = TRUE,
                               fallthrough = TRUE),
        "/pain21" = staticPath(painRoot, fallthrough = TRUE)
      )

      routes <<- list(
        list(method = "GET", path = "/", handler = .self$getIndex)
        #list(method = "POST", path = "/statMap", handler = .self$createStatMap)
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
        response <- list(
           status = 404L, headers = list('Content-Type' = 'text/plain'),
           body = "Not found"
        )
      }

      return(response)
    },

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
      response <- list(
        status = 200L, headers = list("Content-Type" = "text/html"),
        body = body
      )
      return(response)
    },

    #createStatMap = function(req) {
      ## parse request data as JSON
      #params <- try({
        #fromJSON(rawToChar(req$rook.input$read()), simplifyVector = FALSE)
      #}, silent = TRUE)

      #if (inherits(params, "try-error")) {
        #response <- list(
          #status = 400L, headers = list("Content-Type" = "application/json"),
          #body = toJSON(list(error = "invalid JSON"))
        #)
        #return(response)
      #}

      ## validate the request data
      #errors <- list()
      #session <- NULL
      #if (!("token" %in% names(params))) {
        #errors$token <- "is required"
      #} else {
        #session <- getSession(params$token)
        #if (is.null(session)) {
          #errors$token <- "is invalid"
        #}
      #}
    #},

    createSession = function() {
      # generate a random token
      token <- paste(as.character(rand_bytes(12)), collapse = "")

      # create study object
      pain <- pain21()
      study <- PBJStudy$new(pain$data$images, ~ 1, NULL, pain$mask, pain$data,
                            Winv = pain$data$varimages,
                            template = pain$template)

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

    getTemplateVars = function(token) {
      session <- getSession(token)
      study <- session$study

      images <- study$getImages()

      # convert study paths to URLs
      for (name in names(images)) {
        images[[name]] <- sub(paste0("^", painRoot), "/pain21", images[[name]])
      }

      images$index <- 1:nrow(images)
      images$selected <- 1:nrow(images) == 1

      list(
        token = session$token,
        study = list(
          dataRows = rowSplit(images),
          form = paste(as.character(study$form), collapse = " "),
          formred = paste(as.character(study$formred), collapse = " ")
        )
      )
    }
  )
)

app <- App$new()
server <- startServer("127.0.0.1", 37212, app)
if (interactive()) {
  browseURL("http://localhost:37212")
} else {
  while(TRUE) {
    service()
  }
  server$stop()
}

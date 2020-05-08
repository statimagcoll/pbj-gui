library(pain21)
library(pbj)
library(httpuv)
library(whisker)
library(openssl)

PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "form", "formred", "mask", "data", "W", "Winv",
             "template", "formImages", "robust", "sqrtSigma", "transform",
             "outdir", "zeros", "mc.cores", "statMap", "cfts.s", "cfts.p",
             "nboot", "kernel", "rboot", "debug", "sPBJ", "index"),
  methods = list(
    initialize = function(images, form, formred, mask, data = NULL, W = NULL,
                          Winv = NULL, template = NULL, formImages = NULL,
                          robust = TRUE, sqrtSigma = TRUE, transform = TRUE,
                          zeros = FALSE, mc.cores = getOption("mc.cores", 2L),
                          cfts.s = c(0.1, 0.25), cfts.p = NULL, nboot = 5000,
                          kernel = "box", rboot = stats::rnorm, debug = FALSE,
                          index = 1) {

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
      index <<- index

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

    currentImages = function() {
      c(template, images[index], data$varimages[index])
    }
  )
)

# create App class for httpuv
App <- setRefClass(
  Class = "PBJApp",
  fields = c("root", "painRoot", "sessions", "staticPaths"),
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
    },

    call = function(req) {
      path <- req$PATH_INFO
      response <- NULL
      if (path == "/") {
        # create a new session
        token <- createSession()

        # read the study data tab template to use as a partial template
        dataTemplate <- getTemplate("data.html")

        # render the main template
        mainTemplate <- getTemplate("index.html")
        vars <- getTemplateVars(token)
        body <- whisker.render(mainTemplate, data = vars,
                               partials = list("data" = dataTemplate))

        # setup the response
        response <- list(
          status = 200L, headers = list("Content-Type" = "text/html"),
          body = body
        )
      } else {
        # path didn't match, return 404
        response <- list(
           status = 404L, headers = list('Content-Type' = 'text/plain'),
           body = "Not found"
        )
      }

      return(response)
    },

    createSession = function() {
      # generate a random token
      token <- paste(as.character(rand_bytes(12)), collapse = "")

      # create study object
      pain <- pain21()
      study <- PBJStudy$new(pain$data$images, ~ 1, NULL, pain$mask, pain$data,
                            Winv = pain$data$varimages)

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

      # convert study paths to URLs
      images <- sub(paste0("^", painRoot), "/pain21", study$currentImages())

      list(
        token = session$token,
        study = list(images = images)
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

library(pain21)
library(pbj)
library(httpuv)

PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "form", "formred", "mask", "data", "W", "Winv",
             "template", "formImages", "robust", "sqrtSigma", "transform",
             "outdir", "zeros", "mc.cores", "statMap", "cfts.s",
             "cfts.p", "nboot", "kernel", "rboot", "debug", "sPBJ"),
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
    }
  )
)

#pain <- pain21()
#study <- PBJStudy$new(pain$data$images, ~ 1, NULL, pain$mask, pain$data,
                      #Winv = pain$data$varimages)

root <- getwd()
app <- list(
  call = function(req) {
    list(status = 404L,
         headers = list('Content-Type' = 'text/plain'),
         body = "Not found")
  },
  staticPaths = list(
    "/" = staticPath(file.path(root, "static"), indexhtml = TRUE,
                     fallthrough = TRUE)
  )
)

server <- startServer("127.0.0.1", 37212, app)
if (interactive()) {
  browseURL("http://localhost:37212")
} else {
  while(TRUE) {
    service()
  }
  server$stop()
}

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
                          cfts.s = c(0.1, 0.25), cfts.p = NULL, nboot = 200,
                          kernel = "box", rboot = stats::rnorm, debug = FALSE,
                          .outdir = NULL) {

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

      if (is.null(.outdir)) {
        # create temporary directory for output
        outdir <<- tempfile()
        dir.create(outdir)
      } else {
        outdir <<- .outdir
      }

      # set computed fields to NULL
      statMap <<- NULL
      sPBJ <<- NULL
    },

    createStatMap = function() {
      statMap <<- pbj::lmPBJ(images, form, formred, mask, data, W, Winv,
                             template, formImages, robust, sqrtSigma,
                             transform, outdir, zeros, mc.cores)
    },

    performSEI = function() {
      if (is.null(statMap)) {
        stop("run createStatMap() first")
      }
      sPBJ <<- pbj::pbjSEI(statMap, cfts.s, cfts.p, nboot, kernel, rboot, debug)
    },

    getNumericVarNames = function() {
      Filter(function(i) length(intersect(class(data[[i]]), c("integer", "numeric"))) > 0, names(data))
    },

    getWeights = function() {
      if (!is.null(W)) {
        return(W)
      } else {
        return(Winv)
      }
    },

    plotHist = function(name) {
      hist(data[[name]], main = name, xlab = "")
    }
  )
)

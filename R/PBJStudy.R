PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "form", "formred", "mask", "data", "W", "Winv",
             "template", "formImages", "robust", "sqrtSigma", "transform",
             "outdir", "zeros", "mc.cores", "statMap", "cfts.s", "cfts.p",
             "nboot", "kernel", "rboot", "debug", "sei", "statMapJob",
             "seiJob"),
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
      statMapJob <<- NULL
      sei <<- NULL
      seiJob <<- NULL
    },

    hasStatMapJob = function() {
      return(!is.null(statMapJob))
    },

    startStatMapJob = function() {
      if (hasStatMapJob()) {
        stop("statMapJob already exists!")
      }
      statMap <<- NULL
      sei <<- NULL

      # run lmPBJ in a separate R process
      f <- function(images, form, formred, mask, data, W, Winv, template,
                    formImages, robust, sqrtSigma, transform, outdir, zeros,
                    mc.cores) {
        pbj::lmPBJ(images, form, formred, mask, data, W, Winv, template,
                   formImages, robust, sqrtSigma, transform, outdir, zeros,
                   mc.cores)
      }
      args <- list(
        "images"     = .self$images,
        "form"       = .self$form,
        "formred"    = .self$formred,
        "mask"       = .self$mask,
        "data"       = .self$data,
        "W"          = .self$W,
        "Winv"       = .self$Winv,
        "template"   = .self$template,
        "formImages" = .self$formImages,
        "robust"     = .self$robust,
        "sqrtSigma"  = .self$sqrtSigma,
        "transform"  = .self$transform,
        "outdir"     = .self$outdir,
        "zeros"      = .self$zeros,
        "mc.cores"   = .self$mc.cores
      )
      statMapJob <<- Job$new(f, args, "stderr")
      return(TRUE)
    },

    hasStatMap = function() {
      return(!is.null(statMap))
    },

    hasSEIJob = function() {
      return(!is.null(seiJob))
    },

    startSEIJob = function() {
      if (!hasStatMap()) {
        stop("run createStatMap() first")
      }
      if (hasSEIJob()) {
        stop("seiJob already exists!")
      }

      # run pbjSEI in a separate R process
      f <- function(statMap, cfts.s, cfts.p, nboot, kernel, rboot, debug) {
        pbj::pbjSEI(statMap, cfts.s, cfts.p, nboot, kernel, rboot, debug)
      }
      args <- list(
        "statMap" = statMap,
        "cfts.s"  = cfts.s,
        "cfts.p"  = cfts.p,
        "nboot"   = nboot,
        "kernel"  = kernel,
        "rboot"   = rboot,
        "debug"   = debug
      )
      seiJob <<- Job$new(f, args, "stdout")
      return(TRUE)
    },

    hasSEI = function() {
      return(!is.null(sei))
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

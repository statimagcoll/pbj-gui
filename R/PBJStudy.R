PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "form", "formred", "mask", "data", "W", "Winv",
             "template", "formImages", "robust", "sqrtSigma", "transform",
             "outdir", "zeros", "mc.cores", "statMap", "cfts.s", "cfts.p",
             "nboot", "kernel", "rboot", "debug", "sPBJ", "statMapJob"),
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
      sPBJ <<- NULL
    },

    hasStatMapJob = function() {
      return(!is.null(statMapJob))
    },

    startStatMapJob = function() {
      if (hasStatMapJob()) {
        stop("statMapJob is already running!")
      }
      statMap <<- NULL
      # TODO: clear pbjSEI result too

      # run lmPBJ in a separate R process
      f <- function(images, form, formred, mask, data, W, Winv, template,
                    formImages, robust, sqrtSigma, transform, outdir, zeros,
                    mc.cores) {
        pbj::lmPBJ(images, form, formred, mask, data, W, Winv, template,
                   formImages, robust, sqrtSigma, transform, outdir, zeros,
                   mc.cores)
      }
      logFile <- tempfile() # for stderr
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
      rx <- callr::r_bg(f, args = args, stderr = logFile, user_profile = FALSE)
      if (!rx$is_alive()) {
        log <- readChar(logFile, file.info(logFile)$size)
        unlink(logFile)
        stop(log)
      }
      statMapJob <<- list(stderr = logFile, rx = rx)
      return(TRUE)
    },

    isStatMapJobRunning = function() {
      return(hasStatMapJob() && statMapJob$rx$is_alive())
    },

    getStatMapJobLog = function() {
      if (!hasStatMapJob()) {
        return(NULL)
      }
      fn <- statMapJob$stderr
      return(readChar(fn, file.info(fn)$size))
    },

    finalizeStatMapJob = function() {
      if (!hasStatMapJob()) {
        stop("statMapJob doesn't exist!")
      }

      result <- try(statMapJob$rx$get_result())
      if (!inherits(result, "try-error")) {
        statMap <<- result
      }
      unlink(statMapJob$logFile)
      statMapJob <<- NULL

      return(result)
    },

    hasStatMap = function() {
      return(!is.null(statMap))
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

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
        cacheFile <- file.path(outdir, "statMap.rds")
        if (file.exists(cacheFile)) {
          result <- readRDS(cacheFile)
        } else {
          result <- pbj::lmPBJ(images, form, formred, mask, data, W, Winv, template,
                               formImages, robust, sqrtSigma, transform, outdir, zeros,
                               mc.cores)
          saveRDS(result, cacheFile)
        }
        return(result)
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

    isStatMapJobRunning = function() {
      if (hasStatMapJob()) {
        return(statMapJob$isRunning())
      }
      return(FALSE)
    },

    readStatMapJobLog = function() {
      if (hasStatMapJob()) {
        return(statMapJob$readLog())
      }
      stop("statMapJob doesn't exist!")
    },

    finalizeStatMapJob = function() {
      if (!hasStatMapJob()) {
        stop("statMapJob doesn't exist!")
      }
      result <- statMapJob$finalize()
      statMapJob <<- NULL
      if (inherits(result, "try-error")) {
        return(result)
      }

      statMap <<- result
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
      f <- function(statMap, cfts.s, cfts.p, nboot, kernel, rboot, debug, outdir) {
        cacheFile <- file.path(outdir, "sei.rds")
        if (file.exists(cacheFile)) {
          result <- readRDS(cacheFile)
        } else {
          result <- pbj::pbjSEI(statMap, cfts.s, cfts.p, nboot, kernel, rboot, debug)
          saveRDS(result, cacheFile)
        }
        return(result)
      }
      args <- list(
        "statMap" = statMap,
        "cfts.s"  = cfts.s,
        "cfts.p"  = cfts.p,
        "nboot"   = nboot,
        "kernel"  = kernel,
        "rboot"   = rboot,
        "debug"   = debug,
        "outdir"  = outdir
      )
      seiJob <<- Job$new(f, args, "stdout")
      return(TRUE)
    },

    readSEIJobLog = function() {
      if (hasSEIJob()) {
        return(seiJob$readLog())
      }
      stop("seiJob doesn't exist!")
    },

    isSEIJobRunning = function() {
      if (hasSEIJob()) {
        return(seiJob$isRunning())
      }
      return(FALSE)
    },

    finalizeSEIJob = function() {
      if (!hasSEIJob()) {
        stop("seiJob doesn't exist!")
      }
      result <- seiJob$finalize()
      seiJob <<- NULL
      if (inherits(result, "try-error")) {
        return(result)
      }

      sei <<- result

      # write out image files (which PBJ doesn't do yet)
      cftLower <- sei[[5]]
      cftLowerName <- names(sei)[5]
      sei[[5]]$clustermapfile <<- file.path(outdir, paste0('sei-', cftLowerName, '-clustermap.nii.gz'))
      RNifti::writeNifti(cftLower$clustermap, sei[[5]]$clustermapfile)

      cftUpper <- sei[[6]]
      cftUpperName <- names(sei)[6]
      sei[[6]]$clustermapfile <<- file.path(outdir, paste0('sei-', cftUpperName, '-clustermap.nii.gz'))
      RNifti::writeNifti(cftUpper$clustermap, sei[[6]]$clustermapfile)

      return(TRUE)
    },

    hasSEI = function() {
      return(!is.null(sei))
    },

    getVarInfo = function() {
      lapply(names(data), function(name) {
        col <- data[[name]]
        num <- is.numeric(col)
        list(
          id = gsub("[^a-zA-Z0-9_]", "_", name),
          name = name,
          type = class(col),
          num = num,
          mean = if (num) mean(col) else NULL,
          median = if (num) median(col) else NULL
        )
      })
    },

    isVarNumeric = function(name) {
      is.numeric(data[[name]])
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

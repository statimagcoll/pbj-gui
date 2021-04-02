PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "form", "formred", "mask", "data", "weightsColumn",
             "invertedWeights", "template", "formImages", "robust",
             "transform", "outdir", "zeros", "HC3", "mc.cores", "statMap",
             "cftType", "cfts","nboot", "kernel", "rboot", "method", "sei",
             "statMapJob", "seiJob", "seiProgressFile", "datasetPath"),
  methods = list(
    initialize =
      function(images, form, formred, mask, data = NULL,
               weightsColumn = NULL, invertedWeights = FALSE,
               template = NULL, formImages = NULL, robust = TRUE,
               transform = c('none', 't', 'edgeworth'), zeros = FALSE,
               HC3 = TRUE, mc.cores = getOption("mc.cores", 2L),
               cftType = c("s", "p"), cfts = c(0.1, 0.25), nboot = 200,
               kernel = "box",
               rboot = function(n) { (2*stats::rbinom(n, size=1, prob=0.5)-1) },
               method = c('t', 'permutation', 'conditional', 'nonparametric'),
               .outdir = NULL, datasetPath = NULL) {

      images <<- images
      form <<- form
      formred <<- formred
      mask <<- mask
      data <<- data
      weightsColumn <<- weightsColumn
      invertedWeights <<- invertedWeights
      template <<- template
      formImages <<- formImages
      robust <<- robust
      transform <<- match.arg(transform)
      zeros <<- zeros
      HC3 <<- HC3
      mc.cores <<- mc.cores
      cftType <<- match.arg(cftType)
      cfts <<- cfts
      nboot <<- nboot
      kernel <<- kernel
      rboot <<- rboot
      method <<- match.arg(method)
      datasetPath <<- datasetPath

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
                    formImages, robust, transform, outdir, zeros, HC3,
                    mc.cores) {

        result <- pbj::lmPBJ(images, form, formred, mask, data, W, Winv,
                             template, formImages, robust, transform, outdir,
                             zeros, HC3, mc.cores)
        return(result)
      }

      W <- NULL
      Winv <- NULL
      if (!is.null(weightsColumn)) {
        if (invertedWeights) {
          Winv <- data[[weightsColumn]]
        } else {
          W <- data[[weightsColumn]]
        }
      }
      args <- list(
        "images"     = images,
        "form"       = form,
        "formred"    = formred,
        "mask"       = mask,
        "data"       = data,
        "W"          = W,
        "Winv"       = Winv,
        "template"   = template,
        "formImages" = formImages,
        "robust"     = robust,
        "transform"  = transform,
        "outdir"     = outdir,
        "zeros"      = zeros,
        "HC3"        = HC3,
        "mc.cores"   = mc.cores
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
      seiProgressFile <<- tempfile("sei-progress", fileext = ".json")

      # run pbjSEI in a separate R process
      f <- function(statMap, cfts.s, cfts.p, nboot, kernel, rboot, method,
                    outdir, progress.file) {

        result <- pbj::pbjSEI(statMap, cfts.s, cfts.p, nboot, kernel, rboot,
                              method, "json", progress.file)

        return(result)
      }

      cfts.s <- NULL
      cfts.p <- NULL
      if (cftType == "s") {
        cfts.s <- cfts
      } else if (cftType == "p") {
        cfts.p <- cfts
      }
      args <- list(
        "statMap"       = statMap,
        "cfts.s"        = cfts.s,
        "cfts.p"        = cfts.p,
        "nboot"         = nboot,
        "kernel"        = kernel,
        "rboot"         = rboot,
        "method"        = method,
        "outdir"        = outdir,
        "progress.file" = seiProgressFile
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

    getSEIJobProgress = function() {
      if (!hasSEIJob()) {
        stop("seiJob doesn't exist!")
      }
      jsonlite::fromJSON(seiProgressFile)
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
      unlink(seiProgressFile)
      if (inherits(result, "try-error")) {
        return(result)
      }

      sei <<- result

      # write out image files (which PBJ doesn't do yet)
      for (i in 5:length(sei)) {
        cft <- sei[[i]]
        cftName <- names(sei)[i]
        sei[[i]]$clustermapfile <<- file.path(outdir, paste0('sei-', cftName, '-clustermap.nii.gz'))
        suppressWarnings({
          RNifti::writeNifti(sei[[i]]$clustermap, sei[[i]]$clustermapfile)
        })
        sei[[i]]$pmapfile <<- file.path(outdir, paste0('sei-', cftName, '-pmap.nii.gz'))
        suppressWarnings({
          RNifti::writeNifti(sei[[i]]$pmap, sei[[i]]$pmapfile)
        })
      }

      return(TRUE)
    },

    hasSEI = function() {
      return(!is.null(sei))
    },

    getVarInfo = function() {
      lapply(names(data), function(name) {
        col <- data[[name]]
        num <- is.numeric(col)
        na <- sum(is.na(col))
        naPct <- round(na / length(col) * 100)
        list(
          id = gsub("[^a-zA-Z0-9_]", "_", name),
          name = name,
          type = class(col),
          num = num,
          mean = if (num) round(mean(col, na.rm = TRUE), 3) else NULL,
          median = if (num) round(median(col, na.rm = TRUE), 3) else NULL,
          na = if (num) sum(is.na(col)) else NULL,
          naPct = naPct,
          naWarning = (naPct >= 33 && naPct < 66),
          naError = (naPct >= 66),
          isWeightsColumn = (weightsColumn == name)
        )
      })
    },

    getTransformOptions = function() {
      lapply(c("none", "t", "edgeworth"), function(opt) {
        list(value = opt, selected = (transform == opt))
      })
    },

    isVarNumeric = function(name) {
      is.numeric(data[[name]])
    },

    plotHist = function(name) {
      hist(data[[name]], main = name, xlab = "")
    },

    getCftTypeOptions = function() {
      list(
        "s" = (cftType == "s"),
        "p" = (cftType == "p")
      )
    },

    getCftValues = function() {
      lapply(1:length(cfts), function(i) {
        list(index = i, value = cfts[i])
      })
    },

    getMethodOptions = function() {
      lapply(c('t', 'permutation', 'conditional', 'nonparametric'), function(opt) {
        list(value = opt, selected = (method == opt))
      })
    },

    save = function() {
      dir <- tempfile("dir")
      dir.create(dir)
      path <- file.path(dir, paste0("pbj-", Sys.Date(), ".rds"))
      saveRDS(.self, path)
      return(path)
    }
  )
)

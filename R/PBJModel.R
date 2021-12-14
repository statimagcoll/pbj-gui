PBJModel <- setRefClass(
  Class = "PBJModel",
  fields = c("images", "formfull", "formred", "mask", "data", "weightsColumn",
             "invertedWeights", "template", "formImages", "robust",
             "transform", "outdir", "zeros", "HC3", "mc.cores", "job"),
  methods = list(
    initialize =
      function(images, formfull, formred, mask, data = NULL,
               weightsColumn = NULL, invertedWeights = FALSE,
               template = NULL, formImages = NULL, robust = TRUE,
               transform = c('none', 't', 'edgeworth'), outdir = NULL,
               zeros = FALSE, HC3 = TRUE,
               mc.cores = getOption("mc.cores", 2L)) {

      images <<- images
      formfull <<- formfull
      formred <<- formred
      mask <<- mask
      data <<- data
      weightsColumn <<- weightsColumn
      invertedWeights <<- invertedWeights
      template <<- template
      formImages <<- formImages
      robust <<- robust
      transform <<- match.arg(transform)
      outdir <<- outdir
      zeros <<- zeros
      HC3 <<- HC3
      mc.cores <<- mc.cores
      job <<- NULL
    },

    hasJob = function() {
      return(!is.null(job))
    },

    startJob = function() {
      if (hasJob()) {
        stop("job already exists!")
      }

      # run lmPBJ in a separate R process
      f <- function(images, formfull, formred, mask, data, W, Winv, template,
                    formImages, robust, transform, outdir, zeros, HC3,
                    mc.cores) {

        result <- pbj::lmPBJ(images = images,
                             form = formfull,
                             formred = formred,
                             mask = mask,
                             data = data,
                             W = W,
                             Winv = Winv,
                             template = template,
                             formImages = formImages,
                             robust = robust,
                             transform = transform,
                             outdir = outdir,
                             zeros = zeros,
                             HC3 = HC3,
                             mc.cores = mc.cores)
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
        "formfull"   = formfull,
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
      job <<- Job$new(f, args, "stderr")
      return(TRUE)
    },

    isJobRunning = function() {
      if (hasJob()) {
        return(job$isRunning())
      }
      return(FALSE)
    },

    readJobLog = function() {
      if (hasJob()) {
        return(job$readLog())
      }
      stop("job doesn't exist!")
    },

    finalizeJob = function() {
      if (!hasJob()) {
        stop("job doesn't exist!")
      }
      result <- job$finalize()
      job <<- NULL
      return(result)
    }
  )
)

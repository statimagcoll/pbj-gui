PBJInference <- setRefClass(
  Class = "PBJInference",
  fields = c("statMap", "progressFile", "job"),
  methods = list(
    hasJob = function() {
      return(!is.null(job))
    },

    startJob = function() {
      if (hasJob()) {
        stop("job already exists!")
      }
      progressFile <<- tempfile("inference-progress", fileext = ".json")

      # run pbjInference in a separate R process
      f <- function(statMap, cfts.s, cfts.p, nboot, kernel, rboot, method,
                    outdir, progress.file) {

        result <- pbj::pbjInference(statMap, cfts.s, cfts.p, nboot, kernel, rboot,
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
        "progress.file" = inferenceProgressFile
      )
      job <<- Job$new(f, args, "stdout")
      return(TRUE)
    },

    readJobLog = function() {
      if (hasJob()) {
        return(job$readLog())
      }
      stop("job doesn't exist!")
    },

    getJobProgress = function() {
      if (!hasJob()) {
        stop("job doesn't exist!")
      }
      jsonlite::fromJSON(progressFile)
    },

    isJobRunning = function() {
      if (hasJob()) {
        return(job$isRunning())
      }
      return(FALSE)
    },

    finalizeJob = function() {
      if (!hasJob()) {
        stop("job doesn't exist!")
      }
      result <- job$finalize()
      job <<- NULL
      unlink(progressFile)
      return(result)
    }
  )
)

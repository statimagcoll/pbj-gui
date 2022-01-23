PBJResample <- setRefClass(
  Class = "PBJResample",
  fields = c("statMap", "nboot", "method", "max", "CMI", "CEI", "job"),
  methods = list(
    initialize = function(statMap, nboot = 5000,
                          method = c('wild', 'permutation', 'nonparametric'),
                          max = FALSE, CMI = FALSE, CEI = TRUE) {
      statMap <<- statMap
      nboot <<- nboot
      method <<- match.arg(method)
      max <<- max
      CMI <<- CMI
      CEI <<- CEI

      job <<- NULL
    },

    hasJob = function() {
      return(!is.null(job))
    },

    startJob = function() {
      if (hasJob()) {
        stop("job already exists!")
      }

      # run pbjInference in a separate R process
      f <- function(statMap, nboot, method, thr, max, CMI, CEI) {

        # The following arguments to pbjInference are not specified and
        # therefore use pbjInference's default values: statistic, rboot.
        # Additionally, runMode is set explicitly to 'cdf'.
        #
        # pbjInference accepts additional arguments that get passed to mmeStat
        # (the default function for 'statistic'). The 'rois' mmeStat argument is
        # not specified, so it uses mmeStat's default argument value (FALSE).
        # The 'mask' mmeStat argument is explicitly set to statMap$mask, and
        # the 'thr' mmeStat argument is explicitly set to:
        #
        #   qchisq(c(0.01, 0.001), df = statMap$sqrtSigma$df, lower.tail = FALSE)

        result <- pbj::pbjInference(statMap = statMap,
                                    nboot = nboot,
                                    method = method,
                                    runMode = 'cdf',
                                    # mmeStat args
                                    mask = statMap$mask,
                                    thr = thr,
                                    max = max,
                                    CMI = CMI,
                                    CEI = CEI)
        return(result)
      }

      sqrtSigma <- if (is.character(statMap$sqrtSigma)) {
        readRDS(statMap$sqrtSigma)
      } else {
        statMap$sqrtSigma
      }
      thr <- qchisq(c(0.01, 0.001), df = sqrtSigma$df, lower.tail = FALSE)

      args <- list(
        "statMap" = statMap,
        "nboot"   = nboot,
        "method"  = method,
        "thr"     = thr,
        "max"     = max,
        "CMI"     = CMI,
        "CEI"     = CEI
      )
      job <<- Job$new(f, args, "stdout")
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
    },

    toList = function() {
      list(
        nboot = nboot,
        method = method,
        max = max,
        CMI = CMI,
        CEI = CEI
      )
    }
  )
)

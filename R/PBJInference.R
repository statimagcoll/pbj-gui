PBJInference <- setRefClass(
  Class = 'PBJInference',
  fields = c('statMap', 'statisticType', 'nboot', 'rboot', 'method', 'runMode',
             'job', 'mask', 'thr'),
  methods = list(
    initialize = function(statMap,
                          statisticType = c('maximaAndCEI', 'maximaAndCMI',
                                            'CEIandCMI', 'maximaCEIandCMI'),
                          nboot = 5000, rboot = NULL,
                          method=c('wild', 'permutation', 'nonparametric'),
                          runMode=c('bootstrap', 'cdf'),
                          mask) {
      statMap <<- statMap
      statisticType <<- match.arg(statisticType)
      nboot <<- nboot
      if (is.null(rboot)) {
        rboot <<- function(n){ (2*stats::rbinom(n, size=1, prob=0.5)-1) }
      } else {
        rboot <<- rboot
      }
      method <<- match.arg(method)
      runMode <<- match.arg(runMode)
      mask <<- mask
      thr <<- qchisq(0.01, df = statMap$sqrtSigma$df, lower.tail = FALSE)

      job <<- NULL
    },

    hasJob = function() {
      return(!is.null(job))
    },

    startJob = function() {
      if (hasJob()) {
        stop('job already exists!')
      }

      # run pbjInference in a separate R process
      f <- function(statMap, statistic, nboot, rboot, method, runMode, mask, thr) {
        result <- pbj::pbjInference(
          statMap = statMap,
          statistic = statistic,
          nboot = nboot,
          rboot = rboot,
          method = method,
          runMode = runMode,
          mask = mask,
          thr = thr
        )

        return(result)
      }

      statistic <- NULL
      if (statisticType == 'maximaAndCEI') {
        statistic <- function(stat, rois=FALSE, mask, thr) {
          c(maxima=list(maxima(stat, rois=rois)), CEI=cluster(stat, mask=mask, thr=thr, rois=rois))
        }
      } else if (statisticType == 'maximaAndCMI') {
        statistic <- function(stat, rois=FALSE, mask, thr) {
          c(maxima=list(maxima(stat, rois=rois)), CMI=cluster(stat, mask=mask, thr=thr, rois=rois, method='mass'))
        }
      } else if (statisticType == 'CEIandCMI') {
        statistic <- function(stat, rois=FALSE, mask, thr) {
          c(CEI=cluster(stat, mask=mask, thr=thr, rois=rois, method='extent'), CMI=cluster(stat, mask=mask, thr=thr, rois=rois, method='mass'))
        }
      } else if (statisticType == 'maximaCEIandCMI') {
        statistic <- function(stat, rois=FALSE, mask, thr) {
          c(maxima=list(maxima(stat, rois=rois)), CEI=cluster(stat, mask=mask, thr=thr, rois=rois, method='extent'), CMI=cluster(stat, mask=mask, thr=thr, rois=rois, method='mass'))
        }
      }

      args <- list(
        'statMap'   = statMap,
        'statistic' = statistic,
        'nboot'     = nboot,
        'rboot'     = rboot,
        'method'    = method,
        'runMode'   = runMode,
        'mask'      = mask,
        'thr'       = thr
      )
      job <<- Job$new(f, args, 'stdout')
      return(TRUE)
    },

    readJobLog = function() {
      if (hasJob()) {
        return(job$readLog())
      }
      stop("job doesn't exist!")
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
      return(result)
    }
  )
)

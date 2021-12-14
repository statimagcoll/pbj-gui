testPBJInferenceStartJobWithMaximaAndCEI <- function() {
  obj <- PBJInference$new(
    statMap = "foo",
    statisticType = "maximaAndCEI",
    nboot = "bar",
    rboot = NULL,
    method = "wild",
    runMode = "bootstrap"
  )

  inferenceCall <- NULL
  with_mock(
    `pbj::pbjInference` = function(...) {
      inferenceCall <<- list(...)
    },
    `callr::r_bg` = function(f, args, ...) {
      do.call(f, args)
      return(list())
    },
    obj$startJob()
  )

  expected <- list(
    statMap = "foo",
    statistic = function(stat, rois=FALSE, mask, thr) {
      c(maxima=list(maxima(stat, rois=rois)), CEI=cluster(stat, mask=mask, thr=thr, rois=rois) )
    },
    nboot = "bar",
    rboot = function(n){ (2*stats::rbinom(n, size=1, prob=0.5)-1) },
    method = "wild",
    runMode = "bootstrap"
  )
  checkEquals(expected$statMap, inferenceCall$statMap)
  checkEquals(deparse(expected$statMap), deparse(inferenceCall$statMap))
  checkEquals(expected$nboot, inferenceCall$nboot)
  checkEquals(deparse(expected$rboot), deparse(inferenceCall$rboot))
  checkEquals(expected$method, inferenceCall$method)
  checkEquals(expected$runMode, inferenceCall$runMode)
}

testPBJInferenceStartJobWithMaximaAndCMI <- function() {
  obj <- PBJInference$new(
    statMap = "foo",
    statisticType = "maximaAndCMI",
    nboot = "bar",
    rboot = NULL,
    method = "wild",
    runMode = "bootstrap"
  )

  inferenceCall <- NULL
  with_mock(
    `pbj::pbjInference` = function(...) {
      inferenceCall <<- list(...)
    },
    `callr::r_bg` = function(f, args, ...) {
      do.call(f, args)
      return(list())
    },
    obj$startJob()
  )

  expected <- list(
    statMap = "foo",
    statistic = function(stat, rois=FALSE, mask, thr){
      c(maxima=list(maxima(stat, rois=rois)), CMI=cluster(stat, mask=mask, thr=thr, rois=rois, method='mass') )
    },
    nboot = "bar",
    rboot = function(n){ (2*stats::rbinom(n, size=1, prob=0.5)-1) },
    method = "wild",
    runMode = "bootstrap"
  )
  checkEquals(expected$statMap, inferenceCall$statMap)
  checkEquals(deparse(expected$statMap), deparse(inferenceCall$statMap))
  checkEquals(expected$nboot, inferenceCall$nboot)
  checkEquals(deparse(expected$rboot), deparse(inferenceCall$rboot))
  checkEquals(expected$method, inferenceCall$method)
  checkEquals(expected$runMode, inferenceCall$runMode)
}

testPBJModelStartJobWithoutWeights <- function() {
  model <- PBJModel$new(
    images = "foo",
    formfull = "bar",
    formred = "baz",
    mask = "qux",
    data = list(quuz = "quux"),
    weightsColumn = NULL,
    invertedWeights = FALSE,
    template = "grault",
    formImages = "garply",
    robust = "waldo",
    transform = "none",
    outdir = "fred",
    zeros = "plugh",
    HC3 = "xyzzy",
    mc.cores = "thud"
  )

  # mock callr::r_bg, since it's impossible to mock Job$new without too many
  # painful workarounds
  lmPBJCall <- NULL
  with_mock(
    `pbj::lmPBJ` = function(...) {
      lmPBJCall <<- list(...)
    },
    `callr::r_bg` = function(f, args, ...) {
      do.call(f, args)
      return(list())
    },
    model$startJob()
  )

  # check call to lmPBJ
  expected <- list(
    images = "foo",
    form = "bar",
    formred = "baz",
    mask = "qux",
    data = list(quuz = "quux"),
    W = NULL,
    Winv = NULL,
    template = "grault",
    formImages = "garply",
    robust = "waldo",
    transform = "none",
    outdir = "fred",
    zeros = "plugh",
    HC3 = "xyzzy",
    mc.cores = "thud"
  )
  checkEquals(expected, lmPBJCall)
}

testPBJModelStartJobWithNormalWeights <- function() {
  model <- PBJModel$new(
    images = "foo",
    formfull = "bar",
    formred = "baz",
    mask = "qux",
    data = list(quuz = "quux"),
    weightsColumn = "quuz",
    invertedWeights = FALSE,
    template = "grault",
    formImages = "garply",
    robust = "waldo",
    transform = "none",
    outdir = "fred",
    zeros = "plugh",
    HC3 = "xyzzy",
    mc.cores = "thud"
  )

  # mock callr::r_bg, since it's impossible to mock Job$new without too many
  # painful workarounds
  lmPBJCall <- NULL
  with_mock(
    `pbj::lmPBJ` = function(...) {
      lmPBJCall <<- list(...)
    },
    `callr::r_bg` = function(f, args, ...) {
      do.call(f, args)
      return(list())
    },
    model$startJob()
  )

  # check call to lmPBJ
  expected <- list(
    images = "foo",
    form = "bar",
    formred = "baz",
    mask = "qux",
    data = list(quuz = "quux"),
    W = "quux",
    Winv = NULL,
    template = "grault",
    formImages = "garply",
    robust = "waldo",
    transform = "none",
    outdir = "fred",
    zeros = "plugh",
    HC3 = "xyzzy",
    mc.cores = "thud"
  )
  checkEquals(expected, lmPBJCall)
}

testPBJModelStartJobWithInvertedWeights <- function() {
  model <- PBJModel$new(
    images = "foo",
    formfull = "bar",
    formred = "baz",
    mask = "qux",
    data = list(quuz = "quux"),
    weightsColumn = "quuz",
    invertedWeights = TRUE,
    template = "grault",
    formImages = "garply",
    robust = "waldo",
    transform = "none",
    outdir = "fred",
    zeros = "plugh",
    HC3 = "xyzzy",
    mc.cores = "thud"
  )

  # mock callr::r_bg, since it's impossible to mock Job$new without too many
  # painful workarounds
  lmPBJCall <- NULL
  with_mock(
    `pbj::lmPBJ` = function(...) {
      lmPBJCall <<- list(...)
    },
    `callr::r_bg` = function(f, args, ...) {
      do.call(f, args)
      return(list())
    },
    model$startJob()
  )

  # check call to lmPBJ
  expected <- list(
    images = "foo",
    form = "bar",
    formred = "baz",
    mask = "qux",
    data = list(quuz = "quux"),
    W = NULL,
    Winv = "quux",
    template = "grault",
    formImages = "garply",
    robust = "waldo",
    transform = "none",
    outdir = "fred",
    zeros = "plugh",
    HC3 = "xyzzy",
    mc.cores = "thud"
  )
  checkEquals(expected, lmPBJCall)
}

testJobWithStderrLog <- function() {
  x <- function(foo) {
    cat("foo\n", file=stderr())
    foo + 1
  }
  job <- Job$new(x, list(foo = 123))
  while (job$isRunning()) {
    Sys.sleep(0.1)
  }
  log <- job$readLog()
  checkEquals("foo\n", log, paste0('expected "foo\\n" but got ', log))
  checkEquals(124, job$finalize())
}

testJobWithStdoutLog <- function() {
  x <- function(foo) {
    cat("foo\n")
    foo + 1
  }
  job <- Job$new(x, list(foo = 123), "stdout")
  while (job$isRunning()) {
    Sys.sleep(0.1)
  }
  log <- job$readLog()
  checkEquals("foo\n", log, paste0('expected "foo\\n" but got ', log))
  checkEquals(124, job$finalize())
}

testJobWithError <- function() {
  x <- function(foo) {
    stop('foo')
  }
  job <- Job$new(x, list(foo = 123))
  while (job$isRunning()) {
    Sys.sleep(0.1)
  }
  result <- job$finalize()
  checkTrue(inherits(result, "try-error"))
}

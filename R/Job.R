Job <- setRefClass(
  Class = "Job",
  fields = c("rx", "logFile"),
  methods = list(
    initialize = function(f, args) {
      logFile <<- tempfile("logFile", fileext = ".txt")
      rx <<- callr::r_bg(f, args = args, stderr = logFile, user_profile = FALSE)
    },
    isRunning = function() {
      return(rx$is_alive())
    },
    readLog = function() {
      return(readChar(logFile, file.info(logFile)$size))
    },
    finalize = function() {
      result <- try(rx$get_result())
      unlink(logFile)
      return(result)
    }
  )
)

Job <- setRefClass(
  Class = "Job",
  fields = c("rx", "logFile"),
  methods = list(
    initialize = function(f, args, logType = c("stderr", "stdout")) {
      logType <- match.arg(logType)
      logFile <<- tempfile("logFile", fileext = ".txt")
      if (logType == "stderr") {
        stderrLog <- logFile
        stdoutLog <- NULL
      } else {
        stderrLog <- NULL
        stdoutLog <- logFile
      }
      rx <<- callr::r_bg(f, args = args, stdout = stdoutLog,
                         stderr = stderrLog, user_profile = FALSE)
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

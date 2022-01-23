PBJInference <- setRefClass(
  Class = "PBJInference",
  fields = c("inference"),
  methods = list(
    initialize = function(inference) {
      inference <<- inference
    },

    toList = function() {
      list(
        output = paste(capture.output(print(inference)), collapse = "\n")
      )
    }
  )
)

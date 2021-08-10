PBJStudy <- setRefClass(
  Class = "PBJStudy",
  fields = c("images", "mask", "data", "template", "outdir", "model",
             "statMap", "inference", "datasetPath"),
  methods = list(
    initialize =
      function(images, mask, data = NULL, template = NULL, outdir = NULL,
               datasetPath = NULL) {

      images <<- images
      mask <<- mask
      data <<- data
      template <<- template
      outdir <<- outdir
      datasetPath <<- datasetPath

      model <<- NULL
      statMap <<- NULL
      inference <<- NULL
    },

    hasModel = function() {
      return(!is.null(model))
    },

    hasStatMap = function() {
      return(!is.null(statMap))
    },

    hasInference = function() {
      return(!is.null(inference))
    },

    describeData = function() {
      lapply(names(data), function(name) {
        col <- data[[name]]
        num <- is.numeric(col)
        na <- sum(is.na(col))
        naPct <- round(na / length(col) * 100)
        list(
          id = gsub("[^a-zA-Z0-9_]", "_", name),
          name = name,
          type = class(col),
          num = num,
          mean = if (num) round(mean(col, na.rm = TRUE), 3) else NULL,
          median = if (num) round(median(col, na.rm = TRUE), 3) else NULL,
          na = if (num) sum(is.na(col)) else NULL,
          naPct = naPct,
          naWarning = (naPct >= 33 && naPct < 66),
          naError = (naPct >= 66),
          isWeightsColumn = (weightsColumn == name)
        )
      })
    },

    isVarNumeric = function(name) {
      is.numeric(data[[name]])
    },

    plotHist = function(name) {
      hist(data[[name]], main = name, xlab = "")
    },

    save = function() {
      dir <- tempfile("dir")
      dir.create(dir)
      path <- file.path(dir, paste0("pbj-", Sys.Date(), ".rds"))
      saveRDS(.self, path)
      return(path)
    },

    toList = function() {
      niftiPattern <- "\\.nii(\\.gz)?$"
      list(
        template = template,
        datasetPath = datasetPath,
        images = images,
        mask = mask,
        varInfo = describeData()
      )
    }
  )
)

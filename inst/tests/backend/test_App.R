testAppInitializationCreatesToken <- function() {
  app <- App$new()
  checkTrue(grepl("^[0-9a-f]{24}$", app$token), paste(app$token, "is not a valid token"))
}

testAppIndex <- function() {
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "",
    QUERY_STRING = paste0("?token=", app$token)
  )
  result <- app$call(req)
  checkEquals(200L, result$status)
  checkEquals(list(
    "Content-Type" = "text/html",
    "Content-Disposition" = "inline"
  ), result$header)
  checkEquals("index.html", basename(result$body["file"]))
}

testAppIndexDoesNotRequireToken <- function() {
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "",
    QUERY_STRING = ""
  )
  result <- app$call(req)
  checkEquals(200L, result$status)
}

testAppJSDoesNotRequireToken <- function() {
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "pbj-2.js",
    QUERY_STRING = ""
  )
  result <- app$call(req)
  checkEquals(200L, result$status)
}

testAppGetFileRoot <- function() {
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "/api/fileRoot",
    QUERY_STRING = paste0("?token=", app$token)
  )
  result <- app$call(req)
  checkEquals(200L, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals(toJSON(list(fileRoot = unbox(getwd()))), result$body, paste0("Result was: ", result$body))
}

testAppGetStudyWhenNull <- function() {
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "/api/study",
    QUERY_STRING = paste0("?token=", app$token)
  )
  result <- app$call(req)
  checkEquals(404L, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals(structure("null", class = "json"), result$body, paste0("Result was: ", result$body))
}

testAppGetStudy <- function() {
  app <- App$new()
  app$study <- list(toList = function() list(foo = "foo", bar = 1:10))
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "/api/study",
    QUERY_STRING = paste0("?token=", app$token)
  )
  result <- app$call(req)
  checkEquals(200L, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals(toJSON(list(foo = "foo", bar = 1:10), auto_unbox = TRUE), result$body, paste0("Result was: ", result$body))
}

testAppSaveStudy <- function() {
  app <- App$new()
  app$study <- list(save = function() "/tmp/foo.rds")
  req <- list(
    REQUEST_METHOD = "GET",
    PATH_INFO = "/api/saveStudy",
    QUERY_STRING = paste0("?token=", app$token)
  )
  result <- app$call(req)
  checkEquals(200L, result$status)
  checkEquals(list(
    "Content-Type" = "application/octet-stream",
    "Content-Disposition" = 'attachment; filename="foo.rds"'
  ), result$headers)
  checkEquals(c(file = "/tmp/foo.rds"), result$body)
}

testBrowseWithDirType <- function() {
  dir <- tempfile('dir')
  fs::dir_create(dir)
  fs::file_create(file.path(dir, 'foo.nii.gz'))
  fs::file_create(file.path(dir, 'baz.csv'))
  fs::file_create(file.path(dir, 'qux.rds'))
  fs::file_create(file.path(dir, 'grault.txt'))
  fs::dir_create(file.path(dir, 'bar'))
  on.exit(unlink(dir, recursive = TRUE))
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/browse",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(list(path = dir, type = "dir"), auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(200, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)

  body <- fromJSON(result$body)
  checkEquals(dir, body$path)
  checkEquals(tempdir(), body$parent)
  checkEquals("", body$glob)
  checkEquals(1, nrow(body$files))
  checkEquals(file.path(dir, 'bar'), body$files[1, 'path'])
}

testBrowseWithNiftiType <- function() {
  dir <- tempfile('dir')
  fs::dir_create(dir)
  fs::file_create(file.path(dir, 'foo.nii.gz'))
  fs::file_create(file.path(dir, 'baz.csv'))
  fs::file_create(file.path(dir, 'qux.rds'))
  fs::file_create(file.path(dir, 'grault.txt'))
  fs::dir_create(file.path(dir, 'bar'))
  on.exit(unlink(dir, recursive = TRUE))
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/browse",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(list(path = dir, type = "nifti"), auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(200, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)

  body <- fromJSON(result$body)
  checkEquals(dir, body$path)
  checkEquals(tempdir(), body$parent)
  checkEquals("*.nii, *.nii.gz", body$glob)
  checkEquals(2, nrow(body$files))
  checkEquals(file.path(dir, 'bar'), body$files[1, 'path'])
  checkEquals(file.path(dir, 'foo.nii.gz'), body$files[2, 'path'])
}

testBrowseWithCsvType <- function() {
  dir <- tempfile('dir')
  fs::dir_create(dir)
  fs::file_create(file.path(dir, 'foo.nii.gz'))
  fs::file_create(file.path(dir, 'baz.csv'))
  fs::file_create(file.path(dir, 'qux.rds'))
  fs::file_create(file.path(dir, 'grault.txt'))
  fs::dir_create(file.path(dir, 'bar'))
  on.exit(unlink(dir, recursive = TRUE))
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/browse",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(list(path = dir, type = "csv"), auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(200, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)

  body <- fromJSON(result$body)
  checkEquals(dir, body$path)
  checkEquals(tempdir(), body$parent)
  checkEquals("*.csv, *.rds", body$glob)
  checkEquals(3, nrow(body$files))
  checkEquals(file.path(dir, 'bar'), body$files[1, 'path'])
  checkEquals(file.path(dir, 'baz.csv'), body$files[2, 'path'])
  checkEquals(file.path(dir, 'qux.rds'), body$files[3, 'path'])
}

testCreateFolder <- function() {
  dir <- tempfile('dir')
  fs::dir_create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  app <- App$new()
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createFolder",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(list(path = dir, name = "foo"), auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(200, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"success":true}', as.character(result$body))
  checkTrue(dir.exists(file.path(dir, "foo")))
}

testCheckDatasetRequiresExistingFile <- function() {
  app <- App$new()
  params <- list(path = "/foo/bar.csv")
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/checkDataset",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"path":["does not exist"]}', as.character(result$body))
}

testCheckDatasetRequiresValidFiletype <- function() {
  path <- tempfile(fileext = ".txt")
  fs::file_create(path)
  app <- App$new()
  params <- list(path = path)
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/checkDataset",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  expectedBody <- '{"path":["must match pattern: \\\\.(csv|rds)$"]}'
  checkEquals(expectedBody, as.character(result$body), paste("Expected:", expectedBody, "Got:", result$body))
}

testCheckDatasetRequiresColumnWithImages <- function() {
  path <- tempfile(fileext = ".csv")
  write.csv(mtcars, path)
  on.exit(unlink(path))

  app <- App$new()
  params <- list(path = path)
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/checkDataset",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  expectedBody <- '{"path":["does not contain file paths to NIFTI images"]}'
  checkEquals(expectedBody, as.character(result$body), paste("Expected:", expectedBody, "Got:", result$body))
}

testCheckDataset <- function() {
  path <- tempfile(fileext = ".csv")
  df <- mtcars
  df$foo <- "/foo/bar/baz.nii.gz"
  write.csv(df, path)
  on.exit(unlink(path))

  app <- App$new()
  params <- list(path = path)
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/checkDataset",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(200, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  expectedBody <- toJSON(list(
    path = path,
    columns = list(
      list(name = "foo", values = df$foo)
    )
  ), auto_unbox = TRUE)
  checkEquals(expectedBody, result$body, paste("Expected:", expectedBody, "Got:", result$body))
}

testCreateStudyRequiresDataset <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  params <- list(
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"dataset":["is required"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresOutcomeColumn <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    #outcomeColumn = "images",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"outcomeColumn":["is required"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresExistingOutcomeColumn <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "foo",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"outcomeColumn":["is not present in dataset"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresStringOutcomeColumn <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "n",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"outcomeColumn":["must contain a character vector"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresNiftiOutcomeColumn <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "study",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"outcomeColumn":["must only contain NIFTI file names"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresOutcomeColumnWithExistingFiles <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  dataset$images[1] <- "foo.nii.gz"
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "images",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"outcomeColumn":["contains missing files: foo.nii.gz"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresMask <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "images",
    #mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"mask":["is required"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresTemplate <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "images",
    mask = file.path(pain21, 'mask.nii.gz'),
    #template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"template":["is required"]}', as.character(result$body), result$body)
}

testCreateStudyRequiresOutdir <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "images",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz')
    #outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(400, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"outdir":["is required"]}', as.character(result$body), result$body)
}

testCreateStudy <- function() {
  app <- App$new()
  pain21 <- file.path(find.package('pain21'), 'pain21')
  dataset <- pain21::pain21()$data
  path <- tempfile(fileext = '.rds')
  saveRDS(dataset, path)
  params <- list(
    dataset = path,
    outcomeColumn = "images",
    mask = file.path(pain21, 'mask.nii.gz'),
    template = file.path(pain21, 'MNI152_T1_2mm_brain.nii.gz'),
    outdir = tempdir()
  )
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/createStudy",
    QUERY_STRING = paste0("?token=", app$token),
    rook.input = list(
      read = function() {
        charToRaw(toJSON(params, auto_unbox = TRUE))
      }
    )
  )
  result <- app$call(req)
  checkEquals(200, result$status)
  checkEquals(list("Content-Type" = "application/json"), result$headers)
  checkEquals('{"success":true}', as.character(result$body), result$body)

  study <- app$study
  checkEquals(dataset$images, study$images)
  checkIdentical(dataset, study$data)
  checkEquals(params$mask, study$mask)
  checkEquals(params$template, study$template)
  checkEquals(params$outdir, study$outdir)
  checkEquals(path, study$datasetPath)
}

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

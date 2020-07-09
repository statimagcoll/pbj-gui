runPBJ <- function(root) {
  app <- App$new()
  server <- httpuv::startServer("127.0.0.1", 37212, app)
  if (interactive()) {
    browseURL("http://localhost:37212")
  } else {
    cat("Running on http://localhost:37212\n", file = stderr())
    while(TRUE) {
      httpuv::service()
    }
    server$stop()
  }
}

# Our package. Used for the test suite name
pkgname <- "pbjGUI"
require(pkgname, quietly = TRUE, character.only = TRUE) || stop("package '", pkgname, "' not found")

# How to determine which files to load (have to start with test_ and end with .R)
pattern <- "^test_.*\\.R$"

# Which functions to run. Have to start with 'test.'
testFunctionRegexp <- "^test.+"

# Path to the unit tests folder in the package
dir <- system.file(file.path("tests/backend"), package = pkgname)

# Define RUnit test suite
suite <- defineTestSuite(name = paste(pkgname, "RUnit Tests"),
                         dirs = dir,
                         testFileRegexp = pattern,
                         testFuncRegexp = testFunctionRegexp,
                         rngKind = "default",
                         rngNormalKind = "default")

# Run tests
result <- runTestSuite(suite)

# Display result tests on the console
printTextProtocol(result)

# Write results in JUnit-like xml format
#printJUnitProtocol(result, fileName="junit.xml")

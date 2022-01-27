PBJ GUI
=======

This R package implements a web-based graphical user interface (GUI) for the
[PBJ R package](https://github.com/simonvandekar/pbj) by Simon Vandekar.


Overall Design
--------------

The PBJ GUI application is not based on Shiny, but on the underlying web server
technology provided by [httpuv](https://cran.r-project.org/package=httpuv). As
such, the PBJ GUI application is setup like a traditional web application, where
there are two parts: the server code (in R) and the browser code (in HTML and
JavaScript).

### Server Design

The httpuv web server accepts an R object with a `call` function. This object
can be a list with a named `call` element that is a function, or it can be a
reference class object. The PBJ GUI application uses reference classes (more
detail later).

The `call` function for a httpuv application accepts a 'request' argument, which
contains all of the information about the web request coming in from a client.
This web request information includes things like URL, browser software
information, and other details. After using the 'request' object to decide what
do to, the `call` function must return a 'response' object, which is an R list
with three elements: 'status', 'headers', and 'body'. The 'status' element
should contain an integer that represents the success or failure of the response.
For a successful response, the status is 200. The 'headers' element is another
list, the names of which are HTTP header names (such as 'Content-Type'). The
'body' element is the actual content of the response, which could be an HTML
page, JavaScript code, CSS document, or JSON data. For more information about
how httpuv applications work, see the [httpuv
documentation](https://github.com/rstudio/httpuv#readme).

The core of the PBJ GUI web application can be found in the `App` reference
class. In order to run the PBJ GUI web application, a user can call the
`runPBJ` R function, which creates an instance of the `App` reference class and
starts the httpuv web server. Creating an `App` object also generates a
security token, which must be used to access the web application. A user would
then visit a URL that looks something like this:
`http://localhost:37212/?token=abcdef1234567890abcdef12`.

#### App

The `App` reference class is responsible for handling HTTP requests and
returning responses (see the `ReferenceClasses` help page in R or read [this
primer](http://adv-r.had.co.nz/R5.html)). The main workhorse is the `call`
method. The `call` method decides what response to generate based on the URL of
the request.

The first requests received when a user starts using the application will be the
static content, including the main HTML page, the JavaScript code, the CSS
document for styling the HTML elements, and any static images (like the PBJ
logo). Static content is located in the `inst/webroot` folder of the PBJ GUI
package. This folder contains all of the frontend application code and static
images.

After the static content is loaded, further requests will be made to the
web application from the user's web browser, such as setting up a PBJ study,
model, statmap, and inference. Each of these requests is handled by an R method
inside the `App` reference class. When one of these requests comes in, the
`call` method decides which other method to call by matching the request URL to
a series of routes. Each route is a list of three elements: 'method', 'path',
and 'handler'. The 'method' element refers to the HTTP request method, which
primarily will be 'GET' or 'POST'. A 'GET' request is typically used for
responses that don't require complicated user input to perform. A 'POST' request
is typically used when the user needs to send information to the server that is
needed to perform an action. The 'path' element of a route is a pattern that is
matched against the portion of the URL after the host name. For example, in
'https://localhost:37212/foo/bar', the path is '/foo/bar'. The 'handler' element
is a function that is called if the route is a match.

Here is a list of routes used by the PBJ GUI application:

```r
routes <<- list(
  list(method = "GET", path = "^/api/fileRoot$", handler = .self$getFileRoot),
  list(method = "GET", path = "^/api/study$", handler = .self$getStudy),
  list(method = "GET", path = "^/api/saveStudy$", handler = .self$saveStudy),
  list(method = "POST", path = "^/api/browse$", handler = .self$browse),
  list(method = "POST", path = "^/api/createFolder", handler = .self$createFolder),
  list(method = "POST", path = "^/api/checkDataset$", handler = .self$checkDataset),
  list(method = "POST", path = "^/api/createStudy$", handler = .self$createStudy),
  list(method = "GET", path = "^/api/studyImage/", handler = .self$getStudyImage),
  list(method = "GET", path = "^/api/hist$", handler = .self$plotHist),
  list(method = "POST", path = "^/api/createStatMap$", handler = .self$createStatMap),
  list(method = "GET", path = "^/api/statMap$", handler = .self$getStatMap),
  list(method = "POST", path = "^/api/createInference$", handler = .self$createInference),
  list(method = "GET", path = "^/api/inference$", handler = .self$getInference)
)
```

Each of these handler functions returns a valid httpuv response list by using
the following helpers: `makeJSONResponse`, `makeFileResponse`,
`makeAttachmentResponse`, `makeImageResponse`, `makeErrorResponse`,
`makeTextResponse`, and `makeHTMLResponse`.

Apart from the request handlers and the response helpers, there are additional
methods in the `App` reference class for performing various tasks.

#### PBJStudy

Apart from the `App` reference class, there are a few other reference classes
that represent the current state of the PBJ GUI. The first one is `PBJStudy`.
This reference class is designed to be logically separate from any HTTP
requests encapsulated in `App`. The methods in `PBJStudy` are only related to
the PBJ study setup as a whole.

#### PBJModel

Similarly the `PBJModel` reference class is designed to encapsulate the
interaction between the PBJ GUI and the PBJ function `lmPBJ`.

#### PBJStatMap

The `PBJStatMap` reference class is designed to wrap the statmap object created
from `lmPBJ` and provide helper functions.

#### PBJResample

The `PBJResample` reference class is designed to encapsulate the interaction
between the PBJ GUI and the PBJ function `pbjInference`.

#### PBJInference

The `PBJInference` reference class is designed to wrap the inference object
created from `pbjInference` and provide helper functions.

#### Job

The `Job` reference class is designed to run a function asynchronously by using
the [callr](https://cran.r-project.org/package=callr) package.

### Frontend Design

The frontend is designed to interact with the backend/server via JSON requests.
This design is known as a [Single-page
application](https://en.wikipedia.org/wiki/Single-page_application). The
frontend interface is split into two main parts: `index.html` and `pbj.js`. All
of the static markup is located in `index.html`, and all of the dynamic
interactions are setup in `pbj.js`. Both of these files are located in the
`inst/webroot` directory. The main layout depends on [Bootstrap
v4.6](https://getbootstrap.com/docs/4.6/getting-started/introduction/). All of
the PBJ GUI JavaScript components communicate with each other using JavaScript
events via the [EventTarget
interface](https://developer.mozilla.org/en-US/docs/Web/API/EventTarget).

#### Startup

When a user visits the PBJ GUI page, the following code runs:

```js
let windowUrl = new URL(window.location.href);
let token = windowUrl.searchParams.get("token");

let api = new pbj.API(token);
let app = new pbj.AppComponent(document.querySelector('#app'), api);
```

This extracts the security token from the URL for further requests, and then
creates the two top-level objects: `API` and `AppComponent`.

#### AppComponent

The top level JavaScript object for the frontend is `AppComponent`, which
manages two child objects: `WelcomeComponent` and `MainComponent`. On startup,
`AppComponent` makes the API `getStudy` call to find out if the PBJ study has
been created yet. If so, `MainComponent` is shown. If not, `WelcomeComponent` is
shown.

#### WelcomeComponent

The job of `WelcomeComponent` is to help the user setup a PBJ study. The user
has to specify a dataset (CSV or RDS file), a mask (NIFTI file), a template
(NIFTI file), and an output directory. `WelcomeComponent` has some
sub-components in order to help do this: `BrowseComponent` and
`CheckDatasetComponent`.

The `BrowseComponent` is a file browser/picker dialog to let the user choose
files/directories. It uses the API call `browse` for this purpose. Users can
also create new folders. Folder creation happens via an emitted event and the
`createFolder` API call.

The `CheckDatasetComponent` is a dialog for picking a dataset column that has
NIFTI files. It uses the `checkDataset` API call and emits an event when
completed.

When the user has setup the study, the `WelcomeComponent` makes the
`createStudy` API call and emits a `studyCreated` event to notify
`AppComponent`, which will then hide `WelcomeComponent` and show
`MainComponent`.

#### MainComponent

This component contains the primary functionality of the frontend interface. It
sets up the following children components: `StudyComponent`,
`StudyVisualizeComponent`, `ModelComponent`, `ModelVisualizeComponent`,
`StatMapComponent`, `StatMapVisualizeComponent`, `InferenceComponent`, and
`InferenceVisualizeComponent`. There is a tab-based display for study, model,
statmap, and inference, and analagous 'visualize' component for each tab.

#### StudyComponent

This component and its sister component `StudyVisualizeComponent` are
responsible for displaying study data from the NIFTI files specified in the
dataset during the study setup phase. The Papaya library is used to display
NIFTI images via the web browser. Papaya doesn't seem to be under active
development anymore, but there's a fork of it in the [statimagcoll
organization](https://github.com/statimagcoll/Papaya) on GitHub that fixes a
couple of bugs.

#### ModelComponent

This component is responsible for helping the user setup a `lmPBJ` function
call. It includes a form for specifying formulae and other options that
ultimately get passed to `lmPBJ` by the backend server. The sister component
`ModelVisualizeComponent` has a way to explore data that could be used in
formulae. There are some rudimentary features there that could be heavily
expanded on.

When the model form is completed and submitted, `ModelComponent` makes a
`createStatMap` API call, which starts a separate R job to run `lmPBJ`. Every
three seconds, the component makes a `getStatMap` API call to check on the job
progress. When the job is finished, it emits a `statMapCreated` event that gets
handled by `MainComponent`, which will then enable the `StatMapComponent`.

#### StatMapComponent

This component and its sister component `StatMapVisualizeComponent` are
responsible for exploring the results of `lmPBJ`. Additionally,
`StatMapComponent` includes a form for specifying arguments that ultimately get
passed to `pbjInference` on the backend server.

When the inference form is completed and submitted, `StatMapComponent` makes a
`createInference` API call to start a separate R job to run `pbjInference`.
Every three seconds, the component makes a `getInference` API call to check the
status of the job. Once the job is complete, the component emits a
`inferenceCreated` event that gets handled by `MainComponent`, which will then
enable `InferenceComponent`.

#### InferenceComponent

This component and its sister component `InferenceVisualizeComponent` will be
responsible for visualizing the results of `pbjInference`. Currently these are
just placeholders until the visualizations are developed by the statimagcoll
team.

Tests
-----

There are some unit tests for both the backend and frontend parts of the
application. These tests are incomplete and somewhat out of date, but the
framework is in place to add more tests and fix existing tests. The backend
tests use RUnit, and the frontend tests use in-browser testing with Mocha. Tests
are located in the `inst/tests` folder.

Known Bugs
----------

* Variables listed in formulae are not validated to make sure they exist in
  dataset. This can result in failed statmap creation.
* Factor-based variables are not displayed in the ModelVisualizeComponent

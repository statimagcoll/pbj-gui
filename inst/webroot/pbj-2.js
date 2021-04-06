class API {
  constructor(token) {
    this.token = token;
  }

  getStudy(success, failure) {
    this.request('GET', 'study', null, success, failure);
  }

  createStudy(data, success, failure) {
    this.request('POST', 'createStudy', data, success, failure);
  }

  browse(type, path, success, failure) {
    let data = { type: type, path: path };
    this.request('POST', 'browse', data, success, failure);
  }

  request(method, action, data, success, failure) {
    let windowUrl = new URL(window.location.href);
    let url = new URL(`/api/${action}`, windowUrl);
    url.searchParams.append('token', this.token);

    let xhr = new XMLHttpRequest();
    if (success) {
      xhr.addEventListener('load', (event) => {
        let result = xhr.responseText;
        if (xhr.getResponseHeader('Content-Type') == 'application/json') {
          result = JSON.parse(result);
        }
        success(result);
      });
    }
    xhr.addEventListener('error', (event) => {
      console.error(xhr, event);
      if (failure) {
        failure(event);
      }
    });
    xhr.open(method, url.toString());

    if (data) {
      xhr.send(JSON.stringify(data));
    } else {
      xhr.send();
    }
  }
}

class Component {
  constructor(root) {
    this.root = root;
  }

  show() {
    $(this.root).removeClass('d-none');
  }

  hide() {
    $(this.root).addClass('d-none');
  }
}

class BrowseComponent extends Component {
}

class WelcomeComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.browseComponent = new BrowseComponent(this.root.querySelector('#browse-modal'));
    this.setup();
  }

  setup() {
    let welcomeForm = this.root.querySelector('#welcome-form');
    let browseButton = welcomeForm.querySelector('button.browse');
    browseButton.addEventListener('click', event => {
      event.preventDefault();
      this.browse(browseButton.dataset.name, browseButton.dataset.type);
    });

    welcomeForm.addEventListener('submit', event => {
      event.preventDefault();

      let data = {};
      welcomeForm.querySelectorAll('input').forEach(elt => {
        data[elt.getAttribute('name')] = elt.value;
      });

      this.api.createStudy(data, (result) => {
        console.log('createStudy result:', result);
        /*
        $('#study').html(data.study);
        $('#model').html(data.model);
        $('#welcome').fadeOut('fast', function() {
          $('#main').fadeIn('fast', initMain);
        });
        //$('#visualize-content').html(data.visualize);
        //$('#model-content').html(data.model);
        //$('#visualize-link').removeClass('disabled').tab('show');
        //$('#model-link').removeClass('disabled');
        */
      });
    });
  }

  setBrowsePath(path) {
    this.browsePath = path;
  }

  browse(name, type) {
    if (typeof(this.browsePath) !== 'string') {
      throw new Error('browsePath has not been set!');
    }

    let path = this.browsePath;
    this.api.browse(type, path,
      // success
      (data) => {
        console.log('browse result:', data);
        /*
        modal.find('.modal-title').text('Select ' + name);
        modal.find('.modal-footer .text').text('File pattern: ' + data.glob);

        // Replace the content
        modal.find('.modal-body').html(data.html);

        let table = modal.find('table.browse');
        table.find('tbody tr.file td').click(function(event) {
          let obj = $(event.target).parent();
          obj.siblings('.selected').removeClass('selected');
          obj.toggleClass('selected');
          selectButton.prop('disabled', table.find('tr.selected').length == 0);
        });
        table.find('tbody tr.folder td').dblclick(function(event) {
          let obj = $(event.target).parent();
          obj.addClass('focused');
          browse(name, type, obj.data('path'));
        });
        selectButton.prop('disabled', table.find('tr.selected').length == 0);

        // Select file if user clicks on select button
        selectButton.on('click', function(event) {
          event.preventDefault();
          let selectedPath = table.find('tr.selected').data('path');
          if (name == 'dataset') {
            checkDataset(selectedPath);
          } else {
            setFile(name, selectedPath);
            modal.modal('hide');
          }
        });

        // Select file if user double clicks on a file row
        table.find('tbody tr.file td').dblclick(function(event) {
          let obj = $(event.target).parent();
          let selectedPath = obj.data('path');
          if (name == 'dataset') {
            checkDataset(selectedPath);
          } else {
            setFile(name, selectedPath);
            modal.modal('hide');
          }
        });

        modal.find('button[name="parent"]').click(function(event) {
          event.preventDefault();
          let path = $(this).data('path');
          browse(name, type, path);
        });

        modal.find('form').submit(function(event) {
          event.preventDefault();
          let obj = $(event.target);
          let newPath = obj.find('input[name="path"]').val();
          browse(name, type, newPath);
        });

        modal.modal('show')
        */
      },
      // failure
      () => {
        /*
        $('#modal').find('form').append('<i class="fa fa-exclamation-triangle text-danger"></i>');
        */
      }
    );
  }
}

class StudyComponent extends Component {
}

class MainComponent extends Component {
  constructor(root, token) {
    super(root);
    this.token = token;
  }

  setup() {
    // add url with token parameter to saveStudy button
    let windowUrl = new URL(window.location.href);
    let saveButton = this.root.querySelector('#save-button');
    let url = new URL('/api/saveStudy', windowUrl);
    url.searchParams.append('token', this.token);
    saveButton.setAttribute('href', url.toString());
  }
}

class AppComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.welcomeComponent = new WelcomeComponent(root.querySelector('#welcome'), api);
    this.mainComponent = new MainComponent(root.querySelector('#main'), api);
    this.setup();
  }

  setup() {
    this.api.getStudy(
      // success
      data => {
        if (data.study === null) {
          this.welcomeComponent.setBrowsePath(data.fileRoot);
          this.welcomeComponent.show();
        } else {
          //initStudy(token, data.study);
        }
      },
      // failure
      () => {
      }
    );
  }
}

$(function() {
  let windowUrl = new URL(window.location.href);
  let token = windowUrl.searchParams.get("token");

  let api = new API(token);
  let app = new AppComponent(document.querySelector('#app'), api);
});

// TODO:
//
// - load study data
// - get browse path
// - show/hide welcome tab
// - show/hide main tab
// - enable/disable statmap tab (#statmap-tab disabled class)
// - enable/disable sei tab (#sei-tab disabled class)

// TODO study tab:
//
// #study-dataset-path: datasetPath
// #study-data-row option template
// study papaya

// TODO model tab:
//
// #model-formfull: formfull
// #model-formred: formred
// #model-transform: transform
// #model-weights-column: weightsColumn
// #model-inverted-weights: invertedWeights
// #model-robust: robust
// #model-zeros: zeros
// #model-HC3: HC3

// TODO statmap tab:
//
// #cft-type-s: cftType
// #cft-type-p: cftType
// #sei-cft-groups template (input value)
// #sei-method: method
// #sei-nboot: nboot
// statmap papaya

// TODO sei tab:
//
// #sei-cft
// sei papaya

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

  checkDataset(path, success, failure) {
    let data = { path: path };
    this.request('POST', 'checkDataset', data, success, failure);
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

class Dialog extends Component {
  show() {
    $(this.root).modal('show');
  }

  hide() {
    $(this.root).modal('hide');
  }
}

class BrowseComponent extends Dialog {
  constructor(root, api) {
    super(root);
    this.api = api;

    // setup parent button event
    let parentButton = root.querySelector('#browse-parent');
    parentButton.addEventListener('click', event => {
      event.preventDefault();
      this.browseParent();
    });

    // set up cancel button
    let cancelButton = root.querySelector('#browse-cancel-button');
    cancelButton.addEventListener('click', event => {
      event.preventDefault();
      this.hide();
    });

    // set up select button
    this.selectButton = root.querySelector('#browse-select-button');
    this.selectButton.addEventListener('click', event => {
      event.preventDefault();
      let selectedRow = this.root.querySelector('tr.selected');
      this.chooseRow(selectedRow);
    });
  }

  setName(name) {
    this.name = name;

    // set title
    let title = this.root.querySelector('.modal-title');
    title.textContent = `Select ${name}`;
  }

  setParent(parent) {
    this.parent = parent;
  }

  setGlob(glob) {
    // set footer
    let footer = this.root.querySelector('.modal-footer .text');
    footer.textContent = `File pattern: ${glob}`;
  }

  setType(type) {
    this.type = type;
  }

  setPath(path) {
    this.path = path;
    this.root.querySelector('#browse-input').value = path;
  }

  setFiles(files) {
    let emptyElt = this.root.querySelector('#browse-empty');
    let filesElt = this.root.querySelector('#browse-files');
    let tbodyElt = filesElt.querySelector('table tbody');

    // clear any existing rows
    tbodyElt.innerHTML = '';

    if (files.length == 0) {
      $(emptyElt).removeClass('d-none');
      $(filesElt).addClass('d-none');
    } else {
      $(emptyElt).addClass('d-none');

      let template = this.root.querySelector('template#browse-file-row');
      for (let file of files) {
        let frag = template.content.cloneNode(true);
        let row = frag.querySelector('tr');
        row.dataset.type = file.isdir ? 'folder' : 'file';
        row.dataset.path = file.path;

        let cells = frag.querySelectorAll('td');
        cells[0].querySelector('i').setAttribute('class', `fa fa-${row.dataset.type}`);
        cells[1].textContent = file.name;
        cells[2].textContent = file.isdir ? file.size : '';
        cells[3].textContent = file.mtime;
        cells.forEach(cell => {
          cell.addEventListener('click', event => {
            event.preventDefault();
            this.selectRow(row);
          });
          cell.addEventListener('dblclick', event => {
            event.preventDefault();
            this.chooseRow(row);
          });
        })
        tbodyElt.append(frag);
      }

      $(filesElt).removeClass('d-none');
    }
  }

  setCallback(callback) {
    this.callback = callback;
  }

  selectRow(row) {
    let selectedRow = row.parentNode.querySelector('tr.selected');
    $(selectedRow).removeClass('selected');
    if (selectedRow != row) {
      $(row).addClass('selected');
      this.selectButton.removeAttribute('disabled');
    } else {
      this.selectButton.setAttribute('disabled', '');
    }
  }

  chooseRow(row) {
    if (row.dataset.type == 'folder') {
      this.browse(row.dataset.path);
    } else if (typeof(callback) === 'function') {
      this.callback(row.dataset.path, this.path);
      this.hide();
    }
  }

  browseParent() {
    if (typeof(this.parent) !== 'string') {
      throw new Error('parent is not set!');
    }
    this.browse(this.parent);
  }

  browse(path) {
    let warning = this.root.querySelector('form i.fa-exclamation-triangle');
    if (warning) {
      warning.remove();
    }

    this.api.browse(this.type, path,
      // success
      data => {
        this.setGlob(data.glob);
        this.setParent(data.parent);
        this.setPath(data.path);
        this.setFiles(data.files);
        this.show();
        this.selectButton.setAttribute('disabled', '');
      },
      // failure
      () => {
        let form = this.root.querySelector('form');
        form.insertAdjacentHTML('beforeend', '<i class="fa fa-exclamation-triangle text-danger"></i>');
      }
    );
  }
}

class CheckDatasetComponent extends Dialog {
  constructor(root, api) {
    super(root);
    this.api = api;

    // set up select button
    this.selectButton = this.root.querySelector('#check-dataset-select-button');
    this.selectButton.addEventListener('click', event => {
    });
  }

  setPath(path) {
    this.path = path;
    this.root.querySelector('#check-dataset-path').textContent = path;
  }

  setColumns(columns) {
    let formElt = this.root.querySelector('form');
    formElt.innerHTML = '';

    let template = this.root.querySelector('template#check-dataset-column');
    for (let column of columns) {
      let frag = template.content.cloneNode(true);

      let input = frag.querySelector('input');
      let inputId = `check-dataset-column-${column.name}`;
      input.setAttribute('id', inputId);
      input.value = column.name

      let label = frag.querySelector('label');
      label.setAttribute('for', inputId);

      let span = frag.querySelector('span.column-name');
      span.textContent = column.name;
    }
  }

  checkDataset(path) {
    this.selectButton.setAttribute('disabled', '');

    this.api.checkDataset(path,
      // success
      data => {
        this.setPath(data.path);
        this.setColumns(data.columns);

        // Replace the content
        modal.find('.modal-body').html(html);
        modal.modal('show');

        modal.find('form input').change(function(event) {
          let set = modal.find('form input:checked');
          selectButton.prop('disabled', set.length != 1);
        });

        selectButton.click(function(event) {
          event.preventDefault();
          setFile('dataset', modal.find('form').data('path'));
          modal.find('input:checked').each(function(index) {
            let obj = $(this);
            let name = obj.attr('name');
            let value = obj.val();
            $('#study-dataset-' + name).val(value);
          });
          $('#study-dataset-columns').collapse('show');
          modal.modal('hide');
        });
      },
      // failure
      () => {
        /*
        let content = '<pre>' + xhr.responseText + '</pre>';
        modal.find('#browse-error').html(content).removeClass('d-none');
        */
      }
    );
  }
}

class WelcomeComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.browseComponent = new BrowseComponent(
      this.root.querySelector('#browse-modal'), api);
    this.checkDatasetComponent = new CheckDatasetComponent(
      this.root.querySelector('#check-dataset-modal'), api);
    this.setup();
  }

  setup() {
    let welcomeForm = this.root.querySelector('#welcome-form');
    let browseButtons = welcomeForm.querySelectorAll('button.browse');
    browseButtons.forEach(button => {
      button.addEventListener('click', event => {
        event.preventDefault();
        this.browse(button.dataset.name, button.dataset.type);
      });
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
    let callback;
    switch (button.dataset.name) {
      case 'dataset':
        callback = this.checkDataset;
        break;
      case 'mask':
        callback = this.setMaskPath;
        break;
      case 'template':
        callback = this.setTemplatePath;
        break;
    }

    let modal = this.browseComponent;

    modal.setName(name);
    modal.setType(type);
    modal.setCallback(callback);
    modal.browse(this.browsePath);
  }

  checkDataset(path, parentPath) {
    this.setBrowsePath(parentPath);

    let modal = this.checkDatasetComponent;
    modal.checkDataset(path);
  }

  setDatasetPath(path, parentPath) {
  }

  setMaskPath(path, parentPath) {
    this.setBrowsePath(parentPath);
  }

  setTemplatePath(path, parentPath) {
    this.setBrowsePath(parentPath);
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

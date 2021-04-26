class API {
  constructor(token) {
    this.token = token;
  }

  getFileRoot(complete, failure) {
    this.request('GET', 'fileRoot', null, complete, failure);
  }

  getStudy(complete, failure) {
    this.request('GET', 'study', null, complete, failure);
  }

  createStudy(data, complete, failure) {
    this.request('POST', 'createStudy', data, complete, failure);
  }

  browse(type, path, complete, failure) {
    let data = { type: type, path: path };
    this.request('POST', 'browse', data, complete, failure);
  }

  checkDataset(path, complete, failure) {
    let data = { path: path };
    this.request('POST', 'checkDataset', data, complete, failure);
  }

  request(method, action, data, complete, failure) {
    let windowUrl = new URL(window.location.href);
    let url = new URL(`/api/${action}`, windowUrl);
    url.searchParams.append('token', this.token);

    let xhr = new XMLHttpRequest();
    if (complete) {
      xhr.addEventListener('load', (event) => {
        let result = xhr.responseText;
        if (xhr.getResponseHeader('Content-Type') == 'application/json') {
          result = JSON.parse(result);
        }
        complete(result, xhr.status);
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

class Component extends EventTarget {
  constructor(root) {
    super();
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
            if (event.detail == 1) {
              this.selectRow(row);
            } else if (event.detail == 2) {
              this.chooseRow(row);
            }
          });
        })
        tbodyElt.append(frag);
      }

      $(filesElt).removeClass('d-none');
    }
  }

  selectRow(row) {
    console.log('select row:', row);
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
    console.log('choose row:', row);
    if (row.dataset.type == 'folder') {
      this.browse(row.dataset.path);
    } else {
      let event = new CustomEvent('chooseFile', {
        detail: { path: row.dataset.path, parent: this.path }
      });
      this.dispatchEvent(event);
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
      // request completed
      data => {
        this.setGlob(data.glob);
        this.setParent(data.parent);
        this.setPath(data.path);
        this.setFiles(data.files);
        this.show();
        this.selectButton.setAttribute('disabled', '');
      },
      // request failed
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

    this.form = this.root.querySelector('form');

    // set up select button
    this.selectButton = this.root.querySelector('#check-dataset-select-button');
    this.selectButton.addEventListener('click', clickEvent => {
      clickEvent.preventDefault();

      let fd = new FormData(this.form);
      let event = new CustomEvent('datasetChecked', {
        detail: {
          path: this.path,
          outcomeColumn: fd.get('outcome')
        }
      });
      this.dispatchEvent(event);
      this.hide();
    });
  }

  setPath(path) {
    this.path = path;
    this.root.querySelector('#check-dataset-path').textContent = path;
  }

  setColumns(columns) {
    this.form.innerHTML = '';

    let template = this.root.querySelector('template#check-dataset-column');
    for (let column of columns) {
      let frag = template.content.cloneNode(true);

      let input = frag.querySelector('input');
      let inputId = `check-dataset-column-${column.name}`;
      input.setAttribute('id', inputId);
      input.value = column.name
      input.addEventListener('change', event => {
        this.selectButton.removeAttribute('disabled');
      });

      let label = frag.querySelector('label');
      label.setAttribute('for', inputId);

      let span = frag.querySelector('span.column-name');
      span.textContent = column.name;

      let link = frag.querySelector('a');
      let dataEltId = `check-dataset-column-${column.name}-data`;
      link.setAttribute('href', '#' + dataEltId);
      link.addEventListener('click', event => {
        event.preventDefault();
        let div = this.root.querySelector(event.target.getAttribute('href'));
        $(div).toggleClass('d-none');
      });

      let div = frag.querySelector('div.column-data');
      div.setAttribute('id', dataEltId);

      let ul = div.querySelector('ul');
      for (let value of column.values) {
        let li = document.createElement('li');
        li.textContent = value;
        ul.appendChild(li);
      }

      this.form.appendChild(frag);
    }
  }

  checkDataset(path) {
    this.selectButton.setAttribute('disabled', '');

    this.api.checkDataset(path,
      // request completed
      data => {
        this.setPath(data.path);
        this.setColumns(data.columns);
        this.show();
      },
      // request failed
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

    this.welcomeForm = this.root.querySelector('#welcome-form');
    this.submitButton = this.welcomeForm.querySelector('#study-submit');

    this.setup();
  }

  setup() {
    let browseButtons = this.welcomeForm.querySelectorAll('button.browse');
    browseButtons.forEach(button => {
      button.addEventListener('click', event => {
        event.preventDefault();
        this.browse(button.dataset.name, button.dataset.type);
      });
    });

    this.welcomeForm.addEventListener('submit', event => {
      event.preventDefault();

      let data = {};
      let fd = new FormData(this.welcomeForm);
      for (let pair of fd) {
        data[pair[0]] = pair[1];
      }

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
    switch (name) {
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

    // remove old listener
    if (this.chooseFileListener !== undefined) {
      modal.removeEventListener('chooseFile', this.chooseFileListener);
    }

    this.chooseFileListener = (event) => {
      callback.call(this, event.detail.path, event.detail.parent);
      this.checkForm();
    };
    modal.addEventListener('chooseFile', this.chooseFileListener);

    modal.browse(this.browsePath);
  }

  checkDataset(path, parentPath) {
    this.setBrowsePath(parentPath);

    let modal = this.checkDatasetComponent;
    modal.addEventListener('datasetChecked', event => {
      this.setDataset(event.detail.path, event.detail.outcomeColumn);
    }, { once: true });
    modal.checkDataset(path);
  }

  setDataset(path, outcomeColumn) {
    this.root.querySelector('#study-dataset').value = path;
    this.root.querySelector('#study-dataset-outcome').value = outcomeColumn;
    $(this.root.querySelector('#study-dataset-columns')).removeClass('d-none');
  }

  setMaskPath(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.root.querySelector('#study-mask').value = path;
  }

  setTemplatePath(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.root.querySelector('#study-template').value = path;
  }

  checkForm() {
    if (this.welcomeForm.checkValidity()) {
      this.submitButton.removeAttribute('disabled');
    } else {
      this.submitButton.setAttribute('disabled', '');
    }
  }
}

class ModelComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;
  }

  setStudy(study) {
  }
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
      // request completed
      (data, status) => {
        if (status == 200) {
          //initStudy(token, data.study);
        } else {
          this.welcomeComponent.show();
          this.api.getFileRoot(data => {
            this.welcomeComponent.setBrowsePath(data.fileRoot);
          });
        }
      },
      // request failed
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

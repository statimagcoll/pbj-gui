let utils = {
  addClass: function(elt, className) {
    $(elt).addClass(className);
  },

  removeClass: function(elt, className) {
    $(elt).removeClass(className);
  },

  toggleClass: function(elt, className) {
    $(elt).toggleClass(className);
  },

  showModal: function(elt) {
    $(elt).modal('show');
  },

  hideModal: function(elt) {
    $(elt).modal('hide');
  },

  showTab: function(elt) {
    $(elt).tab('show');
  },

  formatDateTime: function(date) {
    let year = date.getFullYear();
    let month = date.getMonth() + 1;
    if (month < 10) {
      month = `0${month}`;
    }
    let day = date.getDate();
    if (day < 10) {
      day = `0${day}`;
    }
    let hours = date.getHours();
    if (hours < 10) {
      hours = `0${hours}`;
    }
    let minutes = date.getMinutes();
    if (minutes < 10) {
      minutes = `0${minutes}`;
    }
    let seconds = date.getSeconds();
    if (seconds < 10) {
      seconds = `0${seconds}`;
    };
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  },

  basename: function(filename) {
    let parts;
    if (filename.match(/^[a-zA-Z]:\\/)) {
      // windows filename
      parts = filename.split('\\');
    } else {
      parts = filename.split('/');
    }
    return parts[parts.length-1];
  }
};

let pbj = {};

pbj.API = class {
  constructor(token) {
    this.token = token;
  }

  makeURL(action) {
    let windowUrl = new URL(window.location.href);
    if (Array.isArray(action)) {
      action = action.join("/");
    }

    let url = new URL(`/api/${action}`, windowUrl);
    url.searchParams.append('token', this.token);
    return url;
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

  createFolder(path, name, complete, failure) {
    let data = { path: path, name: name };
    this.request('POST', 'createFolder', data, complete, failure);
  }

  checkDataset(path, complete, failure) {
    let data = { path: path };
    this.request('POST', 'checkDataset', data, complete, failure);
  }

  createStatMap(data, complete, failure) {
    this.request('POST', 'createStatMap', data, complete, failure);
  }

  getStatMap(complete, failure) {
    this.request('GET', 'statMap', null, complete, failure);
  }

  request(method, action, data, complete, failure) {
    let url = this.makeURL(action);

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
};

pbj.Component = class extends EventTarget {
  constructor(root) {
    super();
    if (root === null || root === undefined) {
      throw new Error('root is required');
    }
    this.root = root;
  }

  show() {
    utils.removeClass(this.root, 'd-none');
  }

  hide() {
    utils.addClass(this.root, 'd-none');
  }

  find(selector) {
    return this.root.querySelector(selector);
  }

  findAll(selector) {
    return this.root.querySelectorAll(selector);
  }
};

pbj.PapayaComponent = class extends pbj.Component {

  getPapayaIndex(parentName) {
    if (typeof(this.papayaName) !== 'string') {
      throw new Error('this.papayaName is not set!');
    }

    for (let i = 0; i < papayaContainers.length; i++) {
      if (papayaContainers[i].containerHtml.parent().is(`#${this.papayaName}`)) {
        return i;
      }
    }
    return -1;
  }
};

pbj.Dialog = class extends pbj.Component {
  show() {
    utils.showModal(this.root);
  }

  hide() {
    utils.hideModal(this.root);
  }
};

pbj.BrowseComponent = class extends pbj.Dialog {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.emptyElt = this.find('#browse-empty');
    this.filesElt = this.find('#browse-files');
    this.sizeElt = this.filesElt.querySelector('table thead th.size');
    this.tbodyElt = this.filesElt.querySelector('table tbody');
    this.template = this.find('template#browse-file-row');

    // setup parent button event
    let parentButton = this.find('#browse-parent');
    parentButton.addEventListener('click', event => {
      event.preventDefault();
      this.browseParent();
    });


    // setup new folder button
    this.folderButton = this.find('#browse-folder-button');
    this.folderButton.addEventListener('click', event => {
      event.preventDefault();
      this.folderButton.setAttribute('disabled', '');
      this.addNewFolderPlaceholder();
    });

    // set up cancel button
    let cancelButton = this.find('#browse-cancel-button');
    cancelButton.addEventListener('click', event => {
      event.preventDefault();
      this.hide();
    });

    // set up select button
    this.selectButton = this.find('#browse-select-button');
    this.selectButton.addEventListener('click', event => {
      event.preventDefault();
      let selectedRow = this.find('tr.selected');
      this.chooseRow(selectedRow);
    });
  }

  setName(name, label) {
    this.name = name;

    if (label === undefined) {
      label = name;
    }

    // set title
    let title = this.find('.modal-title');
    title.textContent = `Select ${label}`;
  }

  setParent(parent) {
    this.parent = parent;
  }

  setGlob(glob) {
    // set footer
    let footer = this.find('.modal-footer .text');
    if (typeof(glob) === 'string' && glob.length > 0) {
      footer.textContent = `File pattern: ${glob}`;
    } else {
      footer.textContent = '';
    }
  }

  setType(type) {
    this.type = type;

    if (type == 'dir') {
      utils.removeClass(this.folderButton, 'd-none');
      utils.addClass(this.sizeElt, 'd-none');
    } else {
      utils.addClass(this.folderButton, 'd-none');
      utils.removeClass(this.sizeElt, 'd-none');
    }
  }

  setPath(path) {
    this.path = path;
    this.find('#browse-input').value = path;
  }

  setFiles(files) {
    // clear any existing rows
    this.tbodyElt.innerHTML = '';

    if (files.length == 0) {
      utils.removeClass(this.emptyElt, 'd-none');
      utils.addClass(this.filesElt, 'd-none');
    } else {
      utils.addClass(this.emptyElt, 'd-none');
      utils.removeClass(this.filesElt, 'd-none');

      for (let file of files) {
        let frag = this.template.content.cloneNode(true);
        let row = frag.querySelector('tr');
        row.dataset.type = file.isdir ? 'folder' : 'file';
        row.dataset.path = file.path;

        let cells = frag.querySelectorAll('td');
        cells[0].querySelector('i').setAttribute('class', `fa fa-${row.dataset.type}`);
        cells[1].textContent = file.name;
        if (this.type === 'dir') {
          utils.addClass(cells[2], 'd-none');
        } else {
          cells[2].textContent = file.isdir ? '' : file.size;
        }
        cells[3].textContent = file.mtime;
        cells.forEach(cell => {
          cell.addEventListener('click', event => {
            event.preventDefault();
            if (event.detail == 1) {
              this.selectRow(row);
            } else if (event.detail == 2) {
              this.chooseRow(row, true);
            }
          });
        })
        this.tbodyElt.append(frag);
      }

      utils.removeClass(this.filesElt, 'd-none');
    }
  }

  selectRow(row) {
    let selectedRow = row.parentNode.querySelector('tr.selected');
    utils.removeClass(selectedRow, 'selected');
    if (selectedRow != row) {
      utils.addClass(row, 'selected');
      this.selectButton.removeAttribute('disabled');
    } else {
      this.selectButton.setAttribute('disabled', '');
    }
  }

  chooseRow(row, dblclick) {
    if (dblclick === undefined) {
      dblclick = false;
    }

    if (row.dataset.type == 'folder') {
      if (this.type != 'dir' || dblclick) {
        this.browse(row.dataset.path);
        return;
      }
    }

    let event = new CustomEvent('chooseFile', {
      detail: { path: row.dataset.path, parent: this.path }
    });
    this.dispatchEvent(event);
    this.hide();
  }

  browseParent() {
    if (typeof(this.parent) !== 'string') {
      throw new Error('parent is not set!');
    }
    this.browse(this.parent);
  }

  browse(path) {
    if (path === undefined) {
      if (this.path !== undefined) {
        path = this.path;
      } else {
        throw new Error('path is missing');
      }
    }
    let warning = this.find('form i.fa-exclamation-triangle');
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
        this.folderButton.removeAttribute('disabled');
      },
      // request failed
      () => {
        let form = this.find('form');
        form.insertAdjacentHTML('beforeend', '<i class="fa fa-exclamation-triangle text-danger"></i>');
      }
    );
  }

  addNewFolderPlaceholder() {
    utils.addClass(this.emptyElt, 'd-none');
    utils.removeClass(this.filesElt, 'd-none');

    let frag = this.template.content.cloneNode(true);
    let row = frag.querySelector('tr');
    let cells = row.querySelectorAll('td');
    let input = document.createElement('input');
    input.setAttribute('type', 'text');
    input.setAttribute('class', 'border');
    input.value = 'New folder';

    let mtime = utils.formatDateTime(new Date());

    cells[0].querySelector('i').setAttribute('class', `fa fa-folder`);
    cells[1].innerHTML = '';
    cells[1].appendChild(input);
    if (this.type === 'dir') {
      utils.addClass(cells[2], 'd-none');
    } else {
      cells[2].textContent = '';
    }
    cells[3].textContent = mtime;
    this.tbodyElt.insertAdjacentElement('afterbegin', row);

    input.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        event.stopPropagation();
        row.remove();
        this.folderButton.removeAttribute('disabled');
      } else if (event.key == 'Enter') {
        event.stopPropagation();
        let value = event.target.value;
        if (value.length > 0) {
          let customEvent = new CustomEvent('createFolder', {
            detail: {
              path: this.path,
              name: value
            }
          });
          this.dispatchEvent(customEvent);
        }
      }
    });
    input.focus();
  }
};

pbj.CheckDatasetComponent = class extends pbj.Dialog {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.form = this.find('form');

    // set up select button
    this.selectButton = this.find('#check-dataset-select-button');
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
    this.find('#check-dataset-path').textContent = path;
  }

  setColumns(columns) {
    this.form.innerHTML = '';

    let template = this.find('template#check-dataset-column');
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
        let div = this.find(event.target.getAttribute('href'));
        utils.toggleClass(div, 'd-none');
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
        modal.find('#browse-error').html(content).utils.removeClass('d-none');
        */
      }
    );
  }
};

pbj.WelcomeComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.browseComponent = new pbj.BrowseComponent(this.find('#browse-modal'), api);
    this.checkDatasetComponent = new pbj.CheckDatasetComponent(
      this.find('#check-dataset-modal'), api);

    this.welcomeForm = this.find('#welcome-form');
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

    this.browseComponent.addEventListener('createFolder', event => {
      this.createFolder(event);
    });

    this.welcomeForm.addEventListener('submit', event => {
      this.submitForm(event);
    });

    this.checkForm();
  }

  setBrowsePath(path) {
    this.browsePath = path;
  }

  browse(name, type) {
    if (typeof(this.browsePath) !== 'string') {
      throw new Error('browsePath has not been set!');
    }
    let callback, label;
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
      case 'outdir':
        callback = this.setOutdir;
        label = "output directory"
        break;
    }

    let modal = this.browseComponent;
    modal.setName(name, label);
    modal.setType(type);

    // remove old listener
    if (this.chooseFileListener !== undefined) {
      modal.removeEventListener('chooseFile', this.chooseFileListener);
    }

    this.chooseFileListener = (event) => {
      callback.call(this, event.detail.path, event.detail.parent);
    };
    modal.addEventListener('chooseFile', this.chooseFileListener);

    modal.browse(this.browsePath);
  }

  createFolder(event) {
    this.api.createFolder(event.detail.path, event.detail.name,
      // complete
      (result, status) => {
        if (status == 200) {
          this.browseComponent.browse();
        }
      },
      // failure
      () => {
      }
    );
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
    this.find('#study-dataset').value = path;
    this.find('#study-dataset-outcome').value = outcomeColumn;
    utils.removeClass(this.find('#study-dataset-columns'), 'd-none');
    this.checkForm();
  }

  setMaskPath(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.find('#study-mask').value = path;
    this.checkForm();
  }

  setTemplatePath(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.find('#study-template').value = path;
    this.checkForm();
  }

  setOutdir(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.find('#study-outdir').value = path;
    this.checkForm();
  }

  checkForm() {
    // check manually because readonly inputs aren't validated properly natively
    let fd = new FormData(this.welcomeForm);
    let ok = true;
    for (let key of ['dataset', 'outcomeColumn', 'mask', 'template', 'outdir']) {
      let value = fd.get(key);
      if (value === null || value === '') {
        ok = false;
        break;
      }
    }
    if (ok) {
      this.submitButton.removeAttribute('disabled');
    } else {
      this.submitButton.setAttribute('disabled', '');
    }
  }

  submitForm(event) {
    event.preventDefault();

    let data = {};
    let fd = new FormData(this.welcomeForm);
    for (let pair of fd) {
      data[pair[0]] = pair[1];
    }

    this.api.createStudy(data,
      // complete
      (result, status) => {
        if (status !== 200) {
          console.error(result, status);
          return;
        }

        let event = new CustomEvent('studyCreated', { detail: result });
        this.dispatchEvent(event);

        /*
        $('#study').html(data.study);
        $('#model').html(data.model);
        $('#welcome').fadeOut('fast', function() {
          $('#main').fadeIn('fast', initMain);
        });
        //$('#visualize-content').html(data.visualize);
        //$('#model-content').html(data.model);
        //$('#visualize-link').utils.removeClass('disabled').tab('show');
        //$('#model-link').utils.removeClass('disabled');
        */
      },
      // failed
      () => {
      }
    );
  }
};

pbj.StudyComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.select = this.find('#study-image');

    this.setup();
  }

  setup() {
    this.select.addEventListener('input', event => {
      this.emitImageChange();
    });
  }

  getImage() {
    let option = this.select.selectedOptions[0];
    let result = {
      template: option.dataset.template,
      outcome: option.dataset.outcome
    };
    return result;
  }

  emitImageChange() {
    let data = this.getImage();
    let event = new CustomEvent('imageChange', { detail: data });
    this.dispatchEvent(event);
  }

  setStudy(study) {
    this.study = study;

    // show dataset path
    this.find('#study-dataset-path').textContent = study.datasetPath;

    // setup image options
    let template;
    if (study.template) {
      template = utils.basename(study.template);
    }

    let select = this.find('#study-image');
    select.innerHTML = '';
    this.study.images.forEach((image, index) => {
      let option = document.createElement('option');
      let basename = utils.basename(image);
      option.dataset.outcome = this.api.makeURL(['studyImage', 'outcome', index+1, basename]).toString();
      if (this.study.template) {
        option.dataset.template = this.api.makeURL(['studyImage', 'template', template]).toString();
      }

      option.textContent = basename;
      select.appendChild(option);
    });

    this.emitImageChange();
  }
};

pbj.StudyVisualizeComponent = class extends pbj.PapayaComponent {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.papayaName = 'visualize-study-papaya';

    this.setup();
  }

  setup() {
    papaya.Container.addViewer(this.papayaName);
  }

  showImage(data) {
    let params = [];
    params["noNewFiles"] = true;
    params["images"] = [];
    if (data.template) {
      params["images"].push(data.template);
    }
    params["images"].push(data.outcome);

    let cIndex = this.getPapayaIndex();
    papaya.Container.resetViewer(cIndex, params);
  }
};

pbj.ModelComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.form = this.find('form');
    this.submitButton = this.find('#model-submit');
    this.setup();
  }

  setup() {
    this.form.addEventListener('submit', event => {
      event.preventDefault();
      this.submit();
    });
  }

  setStudy(study) {
    // populate weights columns
    let select = this.find('#model-weights-column');
    select.innerHTML = '<option></option>';

    let option;
    for (let varInfo of study.varInfo) {
      if (!varInfo.num) {
        continue;
      }

      option = document.createElement('option');
      option.textContent = varInfo.name;
      select.appendChild(option);
    }

    // populate model form
    let model = study.model;
    if (!model) {
      return;
    }

    this.form.querySelectorAll('input, select').forEach(elt => {
      if (!(elt.name in model)) {
        return;
      }
      if (elt.tagName === 'INPUT') {
        switch (elt.type) {
          case 'text':
            elt.value = model[elt.name];
            break;
          case 'checkbox':
            elt.checked = model[elt.name];
            break;
        }
      } else if (elt.tagName === 'SELECT') {
        for (let i = 0; i < elt.options.length; i++) {
          let option = elt.options[i];
          if (option.value == model[elt.name]) {
            option.setAttribute('selected', '');
            break;
          }
        }
      }
    });
  }

  addVarToFullFormula(varInfo) {
    this.addVarToFormula('formfull', varInfo);
  }

  addVarToReducedFormula(varInfo) {
    this.addVarToFormula('formred', varInfo);
  }

  addVarToFormula(which, varInfo) {
    let input = this.find(`form input[name="${which}"]`);
    let formula = input.value;
    if (formula === "~ 1" || formula === "") {
      formula = `~ ${varInfo.name}`
    } else {
      formula += ` + ${varInfo.name}`
    }
    input.value = formula;
  }

  submit() {
    let fd = new FormData(this.form);
    let data = {
      'formfull': fd.get('formfull'),
      'formred':  fd.get('formred'),
      'weightsColumn': fd.get('weightsColumn'),
      'invertedWeights': fd.has('invertedWeights'),
      'robust': fd.has('robust'),
      'transform': fd.get('transform'),
      'zeros': fd.has('zeros'),
      'HC3': fd.has('HC3')
    };

    this.submitButton.setAttribute('disabled', '');
    utils.removeClass(this.submitButton, 'active');
    utils.addClass(this.submitButton, 'running');

    this.api.createStatMap(data,
      // complete
      (result, status) => {
        if (status === 200) {
          // check for statMap completion in 3 seconds
          setTimeout(() => { this.checkStatMap() }, 3000);
        }
      },
      // failure
      () => {
      }
    );
  }

  checkStatMap() {
    this.api.getStatMap(
      // complete
      (result, status) => {
        if (status === 200) {
          if (result.status === 'running') {
            // wait another 3 seconds
            setTimeout(() => { this.checkStatMap() }, 3000);
          } else {
            this.submitButton.removeAttribute('disabled');
            utils.removeClass(this.submitButton, 'running');
            utils.addClass(this.submitButton, 'active');

            if (result.status === 'finished') {
              let event = new CustomEvent('statMapCreated', { detail: result.statMap });
              this.dispatchEvent(event);
            } else {
              // statMap creation failed
              // FIXME
              window.alert('statMap failed!');
            }
          }
        }
      },
      // failure
      () => {
      }
    );
  }
};

pbj.ModelVisualizeComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.setup();
  }

  setup() {
    let link = this.find('#visualize-model-var a.back');
    link.addEventListener('click', event => {
      event.preventDefault();
      this.showVars();
    });

    let fullBtn = this.find('#visualize-model-add-full');
    fullBtn.addEventListener('click', event => {
      event.preventDefault();
      this.dispatchEvent(new CustomEvent('addVarToFullFormula', {
        detail: this.currentVarInfo
      }));
    });

    let reducedBtn = this.find('#visualize-model-add-reduced');
    reducedBtn.addEventListener('click', event => {
      event.preventDefault();
      this.dispatchEvent(new CustomEvent('addVarToReducedFormula', {
        detail: this.currentVarInfo
      }));
    });
  }

  setStudy(study) {
    // add model var info rows
    let template = this.find('template#visualize-model-var-row');
    let tbody = this.find('#visualize-model-vars table tbody');
    for (let varInfo of study.varInfo) {
      if (!varInfo.num) {
        continue;
      }

      let frag = template.content.cloneNode(true);
      let row = frag.querySelector('tr');
      let cells = frag.querySelectorAll('td');
      cells.forEach(cell => {
        let type = cell.dataset.type;
        if (type === null) {
          return;
        }

        let value = varInfo[type];
        if (value !== null && value !== undefined) {
          cell.insertAdjacentHTML('afterbegin', value.toString());
        }
      });
      row.querySelector('a').addEventListener('click', event => {
        event.preventDefault();
        this.showVar(varInfo);
      });
      tbody.append(frag);
    }
  }

  showVars() {
    utils.addClass(this.find('#visualize-model-var'), 'd-none')
    utils.removeClass(this.find('#visualize-model-vars'), 'd-none')
  }

  showVar(varInfo) {
    this.currentVarInfo = varInfo;

    let div = this.find('#visualize-model-var');
    div.querySelectorAll('span').forEach(elt => {
      elt.textContent = varInfo[elt.dataset.type];
    });
    let histUrl = this.api.makeURL('hist');
    histUrl.searchParams.append('var', varInfo.name);
    div.querySelector('img').setAttribute('src', histUrl.toString());

    utils.addClass(this.find('#visualize-model-vars'), 'd-none')
    utils.removeClass(div, 'd-none')
  }
};

pbj.StatMapComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.setup();
  }

  setup() {
    /*
    $('#statmap-image').change(function(e) {
      let index = getPapayaIndex('statmap');
      if (index > -1) {
        let params = getStatMapPapayaParams();
        if (params === undefined) {
          console.error('statMap params is undefined!');
          return;
        }
        papaya.Container.resetViewer(index, params);
      }
    });

    $('#sei-form').submit(function(event) {
      event.preventDefault();

      let form = $(this);
      let data = {
        'token': token,
        'cftType': form.find('input[name="cftType"]:checked').val(),
        'cfts': form.find('input[name="cfts[]"]').map(function(i) { return $(this).val() }).get(),
        'method': form.find('select[name="method"]').val(),
        'nboot': form.find('input[name="nboot"]').val()
      };

      $('#sei-submit').prop('disabled', true).
        removeClass('active').addClass('running');

      $.ajax({
        type: 'POST',
        url: `/createSEI?token=${token}`,
        data: JSON.stringify(data),
        contentType: 'application/json',
        success: function(result) {
          setTimeout(checkSEI, 3000);
        },
        error: function(xhr) {
          console.log('unknown error:', xhr);
        }
      });
    });

    $('#sei-form #sei-cft-add').click(function(event) {
      event.preventDefault();

      // copy existing cft group
      let elt = $('#sei-form .sei-cft-group:last-child').clone().appendTo('#sei-cft-groups');
      elt.find('.sei-cft-trash').click(deleteSeiCft);
    });

    $('#sei-form .sei-cft-trash').click(deleteSeiCft);

    //// initialize papaya if statMap tab is active
    //if ($('#statmap-tab').hasClass('active')) {
      //setTimeout(initStatMapPapaya, 500);
    //}

    // init popovers in statmap tab
    $('#statmap [data-toggle="popover"]').popover({ 'html': true });
    */
  }

  setStudy(study) {
  }

  setStatMap(statMap) {
  }
};

pbj.StatMapVisualizeComponent = class extends pbj.PapayaComponent {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.papayaName = 'visualize-statmap-papaya';
  }

  setStatMap(statMap) {
    //papaya.Container.addViewer(this.papayaName);
  }
};

pbj.MainComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.studyComponent = new pbj.StudyComponent(this.find('#study'), api);

    this.studyVisComponent = new pbj.StudyVisualizeComponent(
      this.find('#visualize-study'), api);
    this.studyComponent.addEventListener('imageChange', event => {
      this.studyVisComponent.showImage(event.detail);
    });

    this.modelComponent = new pbj.ModelComponent(this.find('#model'), api);
    this.modelComponent.addEventListener('statMapCreated', event => {
      this.setStatMap(event.detail);
      this.showTab(this.find('#statmap-tab'));
    });

    this.modelVisComponent = new pbj.ModelVisualizeComponent(
      this.find('#visualize-model'), api);
    this.modelVisComponent.addEventListener('addVarToFullFormula', event => {
      this.modelComponent.addVarToFullFormula(event.detail);
    });
    this.modelVisComponent.addEventListener('addVarToReducedFormula', event => {
      this.modelComponent.addVarToReducedFormula(event.detail);
    });

    this.statMapComponent = new pbj.StatMapComponent(this.find('#statmap'), api);

    this.statMapVisComponent = new pbj.StatMapVisualizeComponent(
      this.find('#visualize-statmap'), api
    );

    this.nav = this.find('#pbj-nav');

    this.setup();
  }

  setup() {
    // add url with token parameter to saveStudy button
    let saveButton = this.find('#save-button');
    let url = this.api.makeURL('saveStudy');
    saveButton.setAttribute('href', url.toString());

    // hook up tab nav
    this.nav.querySelectorAll('a.nav-link').forEach(link => {
      link.addEventListener('click', event => {
        event.preventDefault();
        this.showTab(link);
      });
    });

    this.showTab(this.find('#study-tab'));
  }

  setStudy(study) {
    this.studyComponent.setStudy(study);
    this.modelComponent.setStudy(study);
    this.modelVisComponent.setStudy(study);
    this.statMapComponent.setStudy(study);
  }

  setStatMap(statMap) {
    utils.removeClass(this.find('#statmap-tab'), 'disabled');
    this.statMapVisComponent.setStatMap(statMap);
  }

  showTab(link) {
    utils.showTab(link);

    let vis;
    switch (link.dataset.vis) {
      case "#visualize-study":
        vis = this.studyVisComponent;
        break;
      case "#visualize-model":
        vis = this.modelVisComponent;
        break;
      case '#visualize-statmap':
        vis = this.statMapVisComponent;
        break;
    }

    if (this.currentVisComponent) {
      this.currentVisComponent.hide();
    }
    this.currentVisComponent = vis;
    vis.show();
  }
};

pbj.AppComponent = class extends pbj.Component {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.welcomeComponent = new pbj.WelcomeComponent(this.find('#welcome'), api);
    this.mainComponent = new pbj.MainComponent(this.find('#main'), api);

    this.welcomeComponent.addEventListener('studyCreated', event => {
      this.getStudy();
    });

    this.getStudy();
  }

  getStudy() {
    this.api.getStudy(
      // request completed
      (data, status) => {
        if (status == 200) {
          this.setStudy(data);
        } else {
          this.welcomeComponent.show();
          this.api.getFileRoot(data => {
            this.welcomeComponent.setBrowsePath(data.fileRoot);
          });
        }
      }
    );
  }

  setStudy(study) {
    this.mainComponent.setStudy(study);
    this.welcomeComponent.hide();
    this.mainComponent.show();
  }
};

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

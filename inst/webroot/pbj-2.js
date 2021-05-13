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
  }
};

class API {
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

  checkDataset(path, complete, failure) {
    let data = { path: path };
    this.request('POST', 'checkDataset', data, complete, failure);
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
}

class Component extends EventTarget {
  constructor(root) {
    super();
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
}

class VisualizeComponent extends Component {

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
}

class Dialog extends Component {
  show() {
    utils.showModal(this.root);
  }

  hide() {
    utils.hideModal(this.root);
  }
}

class BrowseComponent extends Dialog {
  constructor(root, api) {
    super(root);
    this.api = api;

    // setup parent button event
    let parentButton = this.find('#browse-parent');
    parentButton.addEventListener('click', event => {
      event.preventDefault();
      this.browseParent();
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

  setName(name) {
    this.name = name;

    // set title
    let title = this.find('.modal-title');
    title.textContent = `Select ${name}`;
  }

  setParent(parent) {
    this.parent = parent;
  }

  setGlob(glob) {
    // set footer
    let footer = this.find('.modal-footer .text');
    footer.textContent = `File pattern: ${glob}`;
  }

  setType(type) {
    this.type = type;
  }

  setPath(path) {
    this.path = path;
    this.find('#browse-input').value = path;
  }

  setFiles(files) {
    let emptyElt = this.find('#browse-empty');
    let filesElt = this.find('#browse-files');
    let tbodyElt = filesElt.querySelector('table tbody');

    // clear any existing rows
    tbodyElt.innerHTML = '';

    if (files.length == 0) {
      utils.removeClass(emptyElt, 'd-none');
      utils.addClass(filesElt, 'd-none');
    } else {
      utils.addClass(emptyElt, 'd-none');

      let template = this.find('template#browse-file-row');
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

      utils.removeClass(filesElt, 'd-none');
    }
  }

  selectRow(row) {
    console.log('select row:', row);
    let selectedRow = row.parentNode.querySelector('tr.selected');
    utils.removeClass(selectedRow, 'selected');
    if (selectedRow != row) {
      utils.addClass(row, 'selected');
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
      },
      // request failed
      () => {
        let form = this.find('form');
        form.insertAdjacentHTML('beforeend', '<i class="fa fa-exclamation-triangle text-danger"></i>');
      }
    );
  }
}

class CheckDatasetComponent extends Dialog {
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
}

class WelcomeComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.browseComponent = new BrowseComponent(this.find('#browse-modal'), api);
    this.checkDatasetComponent = new CheckDatasetComponent(
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

    this.welcomeForm.addEventListener('submit', event => {
      event.preventDefault();

      let data = {};
      let fd = new FormData(this.welcomeForm);
      for (let pair of fd) {
        data[pair[0]] = pair[1];
      }

      this.api.createStudy(data, (result, status) => {
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
    this.find('#study-dataset').value = path;
    this.find('#study-dataset-outcome').value = outcomeColumn;
    utils.removeClass(this.find('#study-dataset-columns'), 'd-none');
  }

  setMaskPath(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.find('#study-mask').value = path;
  }

  setTemplatePath(path, parentPath) {
    this.setBrowsePath(parentPath);
    this.find('#study-template').value = path;
  }

  checkForm() {
    // check manually because readonly inputs aren't validated properly natively
    let fd = new FormData(this.welcomeForm);
    let ok = true;
    for (let key of ['dataset', 'outcomeColumn', 'mask', 'template']) {
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
}

class StudyComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.select = this.find('#study-data-row');

    this.setup();
  }

  setup() {
    this.select.addEventListener('input', event => {
      this.emitDataRowChange();
    });
  }

  getDataRow() {
    let option = this.select.selectedOptions[0];
    let result = {
      template: option.dataset.template,
      outcome: option.dataset.outcome
    };
    return result;
  }

  emitDataRowChange() {
    let data = this.getDataRow();
    let event = new CustomEvent('dataRowChange', { detail: data });
    this.dispatchEvent(event);
  }

  setStudy(study) {
    // show dataset path
    this.find('#study-dataset-path').textContent = study.datasetPath;

    // setup data row options
    let select = this.find('#study-data-row');
    select.innerHTML = '';
    for (let dataRow of study.dataRows) {
      let option = document.createElement('option');
      option.setAttribute('value', dataRow.index);
      if (dataRow.selected) {
        option.setAttribute('selected', '');
      }

      option.dataset.outcome = this.api.makeURL(['studyImage', 'outcome', `${dataRow.index}${dataRow.outcomeExt}`]).toString();
      if (dataRow.hasTemplate) {
        option.dataset.template = this.api.makeURL(['studyImage', `template${dataRow.templateExt}`]).toString();
      }

      option.textContent = dataRow.outcomeBase;
      select.appendChild(option);
    }

    this.emitDataRowChange();
  }
}

class StudyVisualizeComponent extends VisualizeComponent {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.papayaName = 'visualize-study-papaya';

    this.setup();
  }

  setup() {
    papaya.Container.addViewer(this.papayaName);
  }

  showDataRow(dataRow) {
    let params = [];
    params["noNewFiles"] = true;
    params["images"] = [];
    if (dataRow.template) {
      params["images"].push(dataRow.template);
    }
    params["images"].push(dataRow.outcome);

    let cIndex = this.getPapayaIndex();
    papaya.Container.resetViewer(cIndex, params);
  }
}

class ModelComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.form = this.find('form');
  }

  setStudy(study) {
    // configure model form
    this.form.querySelectorAll('input, select').forEach(elt => {
      if (!(elt.name in study)) {
        return;
      }
      if (elt.tagName === 'INPUT') {
        switch (elt.type) {
          case 'text':
            elt.value = study[elt.name];
            break;
          case 'checkbox':
            elt.checked = study[elt.name];
            break;
        }
      } else if (elt.tagName === 'SELECT') {
        for (let i = 0; i < elt.options.length; i++) {
          let option = elt.options[i];
          if (option.value == study[elt.name]) {
            option.setAttribute('selected', '');
            break;
          }
        }
      }
    });
  }

  addVarToFullFormula(varInfo) {
    this.addVarToFormula('form', varInfo);
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
}

class ModelVisualizeComponent extends VisualizeComponent {
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
}

class MainComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;

    this.studyComponent = new StudyComponent(this.find('#study'), api);

    this.studyVisComponent = new StudyVisualizeComponent(
      this.find('#visualize-study'), api);
    this.studyComponent.addEventListener('dataRowChange', event => {
      this.studyVisComponent.showDataRow(event.detail);
    });

    this.modelComponent = new ModelComponent(this.find('#model'), api);

    this.modelVisComponent = new ModelVisualizeComponent(
      this.find('#visualize-model'), api);
    this.modelVisComponent.addEventListener('addVarToFullFormula', event => {
      this.modelComponent.addVarToFullFormula(event.detail);
    });
    this.modelVisComponent.addEventListener('addVarToReducedFormula', event => {
      this.modelComponent.addVarToReducedFormula(event.detail);
    });

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
    }

    if (this.currentVisComponent) {
      this.currentVisComponent.hide();
    }
    this.currentVisComponent = vis;
    vis.show();
  }
}

class AppComponent extends Component {
  constructor(root, api) {
    super(root);
    this.api = api;
    this.welcomeComponent = new WelcomeComponent(this.find('#welcome'), api);
    this.mainComponent = new MainComponent(this.find('#main'), api);

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

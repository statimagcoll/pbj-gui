suite("WelcomeComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div id="welcome">
        <form id="welcome-form">
          <input id="study-dataset" class="form-control" name="dataset" type="text"
            readonly required placeholder="No file selected." />
          <input id="study-dataset-outcome" class="form-control" name="outcomeColumn"
            type="text" readonly required placeholder="None" />

          <button class="browse btn btn-secondary mt-2" data-name="dataset"
            data-type="csv" type="button">Select</button>

          <input id="study-mask" class="form-control" name="mask" type="text"
            readonly required placeholder="No file selected." />
          <button class="browse btn btn-secondary mt-2" data-name="mask" data-type="nifti"
            type="button">Select</button>

          <input id="study-template" class="form-control" name="template" type="text"
            readonly required placeholder="No file selected." />
          <button class="browse btn btn-secondary mt-2" data-name="template"
            data-type="nifti" type="button">Select</button>

          <input id="study-outdir" class="form-control" name="outdir" type="text"
            readonly required placeholder="No directory selected." />
          <button class="browse btn btn-secondary mt-2" data-name="outdir" data-type="dir"
            type="button">Select</button>

          <button id="study-submit" type="submit" class="btn btn-primary" disabled>Continue</button>
        </form>
      </div>
    `;
    this.api = {
      createFolder: sinon.stub(),
      createStudy: sinon.stub()
    };
    this.browseComponent = sinon.createStubInstance(pbj.BrowseComponent);
    let browseComponentClass = sinon.stub(pbj, 'BrowseComponent');
    browseComponentClass.returns(this.browseComponent);

    this.checkDatasetComponent = sinon.createStubInstance(pbj.CheckDatasetComponent);
    let checkDatasetComponentClass = sinon.stub(pbj, 'CheckDatasetComponent');
    checkDatasetComponentClass.returns(this.checkDatasetComponent);
  });

  teardown(function() {
    sinon.restore();
  });

  test('clicking dataset browse button opens browse dialog', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');
    let button = this.root.querySelector('button[data-name="dataset"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.setName.calledWith('dataset', undefined));
    assert(this.browseComponent.setType.calledWith('csv'));
    assert(this.browseComponent.browse.calledWith('/foo'));
  });

  test('checks dataset after dataset browse dialog returns', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');

    this.browseComponent.addEventListener.resetHistory();
    let button = this.root.querySelector('button[data-name="dataset"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.addEventListener.calledOnce);
    let call = this.browseComponent.addEventListener.getCall(0);
    assert.equal('chooseFile', call.args[0]);
    assert.isFunction(call.args[1]);

    call.args[1]({ detail: { path: '/bar/baz.csv', parent: '/bar' } });
    assert.equal('/bar', welcomeComponent.browsePath);
    assert(this.checkDatasetComponent.checkDataset.calledWith('/bar/baz.csv'));
  });

  test('sets dataset path and outcome column after check dataset dialog returns', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');

    this.browseComponent.addEventListener.resetHistory();
    let button = this.root.querySelector('button[data-name="dataset"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    let call = this.browseComponent.addEventListener.getCall(0);
    call.args[1]({ detail: { path: '/bar/baz.csv', parent: '/bar' } });

    assert(this.checkDatasetComponent.addEventListener.calledOnce);
    call = this.checkDatasetComponent.addEventListener.getCall(0);
    assert.equal('datasetChecked', call.args[0]);
    assert.isFunction(call.args[1]);
    call.args[1]({ detail: { path: '/bar/baz.csv', outcomeColumn: 'qux' } });

    assert.equal('/bar/baz.csv', this.root.querySelector('#study-dataset').value);
    assert.equal('qux', this.root.querySelector('#study-dataset-outcome').value);
  });

  test('clicking mask browse button opens browse dialog', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');
    let button = this.root.querySelector('button[data-name="mask"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.setName.calledWith('mask', undefined));
    assert(this.browseComponent.setType.calledWith('nifti'));
    assert(this.browseComponent.browse.calledWith('/foo'));
  });

  test('sets mask path after browse dialog returns', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');

    this.browseComponent.addEventListener.resetHistory();
    let button = this.root.querySelector('button[data-name="mask"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.addEventListener.calledOnce);
    let call = this.browseComponent.addEventListener.getCall(0);
    assert.equal('chooseFile', call.args[0]);
    assert.isFunction(call.args[1]);

    call.args[1]({ detail: { path: '/bar/baz.nii.gz', parent: '/bar' } });
    assert.equal('/bar', welcomeComponent.browsePath);
    assert.equal('/bar/baz.nii.gz', this.root.querySelector('#study-mask').value);
  });

  test('clicking template browse button opens browse dialog', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');
    let button = this.root.querySelector('button[data-name="template"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.setName.calledWith('template', undefined));
    assert(this.browseComponent.setType.calledWith('nifti'));
    assert(this.browseComponent.browse.calledWith('/foo'));
  });

  test('sets template path after browse dialog returns', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');

    this.browseComponent.addEventListener.resetHistory();
    let button = this.root.querySelector('button[data-name="template"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.addEventListener.calledOnce);
    let call = this.browseComponent.addEventListener.getCall(0);
    assert.equal('chooseFile', call.args[0]);
    assert.isFunction(call.args[1]);

    call.args[1]({ detail: { path: '/bar/baz.nii.gz', parent: '/bar' } });
    assert.equal('/bar', welcomeComponent.browsePath);
    assert.equal('/bar/baz.nii.gz', this.root.querySelector('#study-template').value);
  });

  test('clicking outdir browse button opens browse dialog', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');
    let button = this.root.querySelector('button[data-name="outdir"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.setName.calledWith('outdir', 'output directory'));
    assert(this.browseComponent.setType.calledWith('dir'));
    assert(this.browseComponent.browse.calledWith('/foo'));
  });

  test('sets outdir path after browse dialog returns', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');

    this.browseComponent.addEventListener.resetHistory();
    let button = this.root.querySelector('button[data-name="outdir"]');
    let event = new MouseEvent('click');
    button.dispatchEvent(event);

    assert(this.browseComponent.addEventListener.calledOnce);
    let call = this.browseComponent.addEventListener.getCall(0);
    assert.equal('chooseFile', call.args[0]);
    assert.isFunction(call.args[1]);

    call.args[1]({ detail: { path: '/bar/baz', parent: '/bar' } });
    assert.equal('/bar', welcomeComponent.browsePath);
    assert.equal('/bar/baz', this.root.querySelector('#study-outdir').value);
  });

  test('creates folder when browsing', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    assert(this.browseComponent.addEventListener.calledOnce);

    let call = this.browseComponent.addEventListener.getCall(0);
    assert.equal('createFolder', call.args[0]);
    assert.isFunction(call.args[1]);
    call.args[1]({ detail: { path: '/foo/bar', name: 'baz' } });

    assert(this.api.createFolder.calledOnce);
    call = this.api.createFolder.getCall(0);
    assert.equal('/foo/bar', call.args[0]);
    assert.equal('baz', call.args[1]);
    assert.isFunction(call.args[2]);
    assert.isFunction(call.args[3]);

    call.args[2]({ success: true }, 200);
    assert(this.browseComponent.browse.calledOnce);
  });

  test('submitting form calls api and dispatches event', function() {
    let welcomeComponent = new pbj.WelcomeComponent(this.root, this.api);
    welcomeComponent.setBrowsePath('/foo');

    let submitButton = this.root.querySelector('#study-submit');
    assert(submitButton.hasAttribute('disabled'));

    let button, event, call;
    // set dataset path and outcome column
    button = this.root.querySelector('button[data-name="dataset"]');
    event = new MouseEvent('click');
    button.dispatchEvent(event);

    call = this.browseComponent.addEventListener.getCall(-1);
    call.args[1]({ detail: { path: '/bar/baz.csv', parent: '/bar' } });

    call = this.checkDatasetComponent.addEventListener.getCall(-1);
    call.args[1]({ detail: { path: '/bar/baz.csv', outcomeColumn: 'qux' } });

    // set mask path
    button = this.root.querySelector('button[data-name="mask"]');
    event = new MouseEvent('click');
    button.dispatchEvent(event);

    call = this.browseComponent.addEventListener.getCall(-1);
    call.args[1]({ detail: { path: '/bar/baz.nii.gz', parent: '/bar' } });

    // set template path
    button = this.root.querySelector('button[data-name="template"]');
    event = new MouseEvent('click');
    button.dispatchEvent(event);

    call = this.browseComponent.addEventListener.getCall(-1);
    call.args[1]({ detail: { path: '/bar/qux.nii.gz', parent: '/bar' } });

    // set outdir path
    button = this.root.querySelector('button[data-name="outdir"]');
    event = new MouseEvent('click');
    button.dispatchEvent(event);

    call = this.browseComponent.addEventListener.getCall(-1);
    call.args[1]({ detail: { path: '/bar/baz', parent: '/bar' } });

    assert.isFalse(submitButton.hasAttribute('disabled'));

    let form = this.root.querySelector('#welcome-form');
    event = new SubmitEvent('submit');
    form.dispatchEvent(event);

    let expected = {
      'dataset': '/bar/baz.csv', 'outcomeColumn': 'qux',
      'mask': '/bar/baz.nii.gz', 'template': '/bar/qux.nii.gz',
      'outdir': '/bar/baz'
    }
    assert(this.api.createStudy.calledWith(expected, sinon.match.func, sinon.match.func));

    let listener = sinon.stub();
    welcomeComponent.addEventListener('studyCreated', listener);
    call = this.api.createStudy.getCall(0);
    let result = { foo: 'bar' };
    call.args[1](result, 200);

    assert(listener.calledOnce);
    assert.equal(result, listener.getCall(0).args[0].detail);
  });
});

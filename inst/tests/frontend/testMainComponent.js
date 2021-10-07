suite("MainComponent", function() {
  setup(function() {
    sinon.stub(utils, 'showTab');

    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div id="main">
        <!--
        <div id="study"></div>
        <div id="visualize-study"></div>
        <div id="model"></div>
        <div id="visualize-model"></div>
        <div id="statmap"></div>
        <div id="visualize-statmap"></div>
        -->
        <button id="save-button"></button>
        <div id="pbj-nav">
          <a id="study-tab" data-vis="#visualize-study" class="nav-link"></a>
          <a id="model-tab" data-vis="#visualize-model" class="nav-link"></a>
          <a id="statmap-tab" data-vis="#visualize-statmap" class="nav-link disabled"></a>
        </div>
      </div>
    `;

    this.api = sinon.createStubInstance(pbj.API);
    this.url = new URL("https://example.com/foo");
    this.api.makeURL.returns(this.url);

    this.studyComponent = sinon.createStubInstance(pbj.StudyComponent);
    let studyComponentClass = sinon.stub(pbj, 'StudyComponent');
    studyComponentClass.returns(this.studyComponent);

    this.studyVisComponent = sinon.createStubInstance(pbj.StudyVisualizeComponent);
    let studyVisComponentClass = sinon.stub(pbj, 'StudyVisualizeComponent');
    studyVisComponentClass.returns(this.studyVisComponent);

    this.modelComponent = sinon.createStubInstance(pbj.ModelComponent);
    let modelComponentClass = sinon.stub(pbj, 'ModelComponent');
    modelComponentClass.returns(this.modelComponent);

    this.modelVisComponent = sinon.createStubInstance(pbj.ModelVisualizeComponent);
    let modelVisComponentClass = sinon.stub(pbj, 'ModelVisualizeComponent');
    modelVisComponentClass.returns(this.modelVisComponent);

    this.statMapComponent = sinon.createStubInstance(pbj.StatMapComponent);
    let statMapComponentClass = sinon.stub(pbj, 'StatMapComponent');
    statMapComponentClass.returns(this.statMapComponent);

    this.statMapVisComponent = sinon.createStubInstance(pbj.StatMapVisualizeComponent);
    let statMapVisComponentClass = sinon.stub(pbj, 'StatMapVisualizeComponent');
    statMapVisComponentClass.returns(this.statMapVisComponent);
  });

  teardown(function() {
    sinon.restore();
  });

  test("sets up save button", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);
    assert(this.api.makeURL.calledWith('saveStudy'));
    let saveButton = this.root.querySelector('#save-button');
    assert.equal('https://example.com/foo', saveButton.getAttribute('href'));
  });

  test("sets up study navigation link", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    this.studyVisComponent.show.reset();
    let link = this.root.querySelector('#study-tab');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);
    assert(this.studyVisComponent.show.called);
    assert(utils.showTab.calledWith(link));
  });

  test("sets up model navigation link", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    let link = this.root.querySelector('#model-tab');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);
    assert(this.modelVisComponent.show.called);
    assert(utils.showTab.calledWith(link));
  });

  test("sets up statmap navigation link", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    let link = this.root.querySelector('#statmap-tab');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);
    assert(this.statMapVisComponent.show.called);
    assert(utils.showTab.calledWith(link));
  });

  test("setStudy calls setStudy on child components", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    let study = { foo: 'bar' };
    mainComponent.setStudy(study);

    assert(this.studyComponent.setStudy.calledWith(study));
    assert(this.modelComponent.setStudy.calledWith(study));
    assert(this.modelVisComponent.setStudy.calledWith(study));
    assert(this.statMapComponent.setStudy.calledWith(study));
  });

  test("reacts to imageChange event from StudyComponent", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    assert(this.studyComponent.addEventListener.calledWith('imageChange', sinon.match.func));

    let callback = this.studyComponent.addEventListener.getCall(0).args[1];
    callback({ detail: 'foo' });
    assert(this.studyVisComponent.showImage.calledWith('foo'));
  });

  test("reacts to statMapCreated event from ModelComponent", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    assert(this.modelComponent.addEventListener.calledWith('statMapCreated', sinon.match.func));

    let callback = this.modelComponent.addEventListener.getCall(0).args[1];
    callback({ detail: 'foo' });
    let link = this.root.querySelector('#statmap-tab');
    assert.notInclude(link.getAttribute('class'), 'disabled');
    assert(this.statMapVisComponent.setStatMap.calledWith('foo'));
    assert(utils.showTab.calledWith(link));
  });

  test("reacts to addVarToFullFormula event from ModelVisualizationComponent", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    assert(this.modelVisComponent.addEventListener.calledWith('addVarToFullFormula', sinon.match.func));

    for (let call of this.modelVisComponent.addEventListener.getCalls()) {
      if (call.args[0] != 'addVarToFullFormula') continue;

      let callback = call.args[1];
      callback({ detail: 'foo' });
      assert(this.modelComponent.addVarToFullFormula.calledWith('foo'));
      break;
    }
  });

  test("reacts to addVarToReducedFormula event from ModelVisualizationComponent", function() {
    let mainComponent = new pbj.MainComponent(this.root, this.api);

    assert(this.modelVisComponent.addEventListener.calledWith('addVarToReducedFormula', sinon.match.func));

    for (let call of this.modelVisComponent.addEventListener.getCalls()) {
      if (call.args[0] != 'addVarToReducedFormula') continue;

      let callback = call.args[1];
      callback({ detail: 'foo' });
      assert(this.modelComponent.addVarToReducedFormula.calledWith('foo'));
      break;
    }
  });
});

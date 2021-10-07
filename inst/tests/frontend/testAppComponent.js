suite("AppComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div id="app">
      </div>
    `;
    this.api = {
      getStudy: sinon.stub(),
      getFileRoot: sinon.stub()
    };
    this.welcomeComponent = sinon.createStubInstance(pbj.WelcomeComponent);
    let welcomeComponentClass = sinon.stub(pbj, 'WelcomeComponent');
    welcomeComponentClass.returns(this.welcomeComponent);

    this.mainComponent = sinon.createStubInstance(pbj.MainComponent);
    let mainComponentClass = sinon.stub(pbj, 'MainComponent');
    mainComponentClass.returns(this.mainComponent);
  });

  teardown(function() {
    sinon.restore();
  });

  test('shows welcome and gets file root if study is null', function() {
    this.api.getStudy.callsArgWith(0, null, 404);
    this.api.getFileRoot.callsArgWith(0, { fileRoot: '/foo' }, 200);
    let app = new pbj.AppComponent(this.root, this.api);
    assert(this.welcomeComponent.show.calledOnce);
    assert(this.mainComponent.show.notCalled);
    assert(this.welcomeComponent.setBrowsePath.calledWith('/foo'));
  });

  test('shows main if study is not null', function() {
    let study = { foo: 'bar' };
    this.api.getStudy.callsArgWith(0, study, 200);
    let app = new pbj.AppComponent(this.root, this.api);
    assert(this.welcomeComponent.hide.calledOnce);
    assert(this.mainComponent.show.calledOnce);
    assert(this.mainComponent.setStudy.calledWith(study));
  });

  test('shows main after welcome component triggers study creation', function() {
    this.api.getStudy.callsArgWith(0, null, 404);
    this.api.getFileRoot.callsArgWith(0, { fileRoot: '/foo' }, 200);
    let app = new pbj.AppComponent(this.root, this.api);

    assert(this.welcomeComponent.addEventListener.calledOnce);
    let call = this.welcomeComponent.addEventListener.getCall(0);
    assert.equal('studyCreated', call.args[0]);
    let callback = call.args[1];
    assert.isFunction(callback);

    let study = { foo: 'bar' };
    this.api.getStudy.callsArgWith(0, study, 200);
    callback({ details: 'foo' });

    assert(this.welcomeComponent.hide.calledOnce);
    assert(this.mainComponent.show.calledOnce);
    assert(this.mainComponent.setStudy.calledWith(study));
  });
});

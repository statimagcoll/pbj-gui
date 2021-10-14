suite("StudyComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div id="study">
        <p id="study-dataset-path"></p>
        <select id="study-image" class="form-control">
        </select>
      </div>
    `;

    this.api = sinon.createStubInstance(pbj.API);
    this.api.makeURL.returns(new URL("https://example.com/foo"));
  });

  teardown(function() {
    sinon.restore();
  });

  test("setStudy changes dataset path content", function() {
    let studyComponent = new pbj.StudyComponent(this.root, this.api);

    let study = { datasetPath: '/foo/bar.csv', images: ['/blah.nii.gz'] };
    studyComponent.setStudy(study);
    assert.equal('/foo/bar.csv', this.root.querySelector('#study-dataset-path').textContent);
  });

  test("setStudy adds image options", function() {
    let studyComponent = new pbj.StudyComponent(this.root, this.api);

    let study = {
      datasetPath: '/foo/bar.csv', template: '/foo/bar.nii.gz',
      images: ['/foo/baz.nii.gz', '/foo/qux.nii.gz']
    };
    this.api.makeURL.
      withArgs(['studyImage', 'outcome', 1, 'baz.nii.gz']).
      returns('https://example.com/studyImage/outcome/1/baz.nii.gz');
    this.api.makeURL.
      withArgs(['studyImage', 'outcome', 2, 'qux.nii.gz']).
      returns('https://example.com/studyImage/outcome/2/qux.nii.gz');
    this.api.makeURL.
      withArgs(['studyImage', 'template', 'bar.nii.gz']).
      returns('https://example.com/studyImage/template/bar.nii.gz');
    studyComponent.setStudy(study);

    let options = this.root.querySelectorAll('#study-image option');
    assert.equal(2, options.length);
    assert.equal('baz.nii.gz', options[0].textContent);
    assert.equal('https://example.com/studyImage/outcome/1/baz.nii.gz', options[0].dataset.outcome);
    assert.equal('https://example.com/studyImage/template/bar.nii.gz', options[0].dataset.template);
    assert.equal('qux.nii.gz', options[1].textContent);
    assert.equal('https://example.com/studyImage/outcome/2/qux.nii.gz', options[1].dataset.outcome);
    assert.equal('https://example.com/studyImage/template/bar.nii.gz', options[1].dataset.template);
  });

  test("setStudy emits image change event", function() {
    let studyComponent = new pbj.StudyComponent(this.root, this.api);

    let callback = sinon.stub();
    studyComponent.addEventListener('imageChange', callback);

    let study = {
      datasetPath: '/foo/bar.csv', template: '/foo/bar.nii.gz',
      images: ['/foo/baz.nii.gz', '/foo/qux.nii.gz']
    };
    this.api.makeURL.
      withArgs(['studyImage', 'outcome', 1, 'baz.nii.gz']).
      returns('https://example.com/studyImage/outcome/1/baz.nii.gz');
    this.api.makeURL.
      withArgs(['studyImage', 'outcome', 2, 'qux.nii.gz']).
      returns('https://example.com/studyImage/outcome/2/qux.nii.gz');
    this.api.makeURL.
      withArgs(['studyImage', 'template', 'bar.nii.gz']).
      returns('https://example.com/studyImage/template/bar.nii.gz');
    studyComponent.setStudy(study);

    assert(callback.called);

    assert.equal('https://example.com/studyImage/outcome/1/baz.nii.gz', callback.getCall(0).args[0].detail.outcome)
    assert.equal('https://example.com/studyImage/template/bar.nii.gz', callback.getCall(0).args[0].detail.template)
  });

  test("selecting study image emits image change event", function() {
    let studyComponent = new pbj.StudyComponent(this.root, this.api);

    let study = {
      datasetPath: '/foo/bar.csv', template: '/foo/bar.nii.gz',
      images: ['/foo/baz.nii.gz', '/foo/qux.nii.gz']
    };
    this.api.makeURL.
      withArgs(['studyImage', 'outcome', 1, 'baz.nii.gz']).
      returns('https://example.com/studyImage/outcome/1/baz.nii.gz');
    this.api.makeURL.
      withArgs(['studyImage', 'outcome', 2, 'qux.nii.gz']).
      returns('https://example.com/studyImage/outcome/2/qux.nii.gz');
    this.api.makeURL.
      withArgs(['studyImage', 'template', 'bar.nii.gz']).
      returns('https://example.com/studyImage/template/bar.nii.gz');
    studyComponent.setStudy(study);

    let callback = sinon.stub();
    studyComponent.addEventListener('imageChange', callback);

    this.root.querySelector('#study-image').dispatchEvent(new Event('change'));

    assert(callback.called);

    assert.equal('https://example.com/studyImage/outcome/1/baz.nii.gz', callback.getCall(0).args[0].detail.outcome)
    assert.equal('https://example.com/studyImage/template/bar.nii.gz', callback.getCall(0).args[0].detail.template)
  });
});

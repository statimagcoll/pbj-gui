suite("StudyVisualizeComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div id="visualize-study" class="papaya-container">
        <div id="visualize-study-papaya"></div>
      </div>
    `;

    this.addViewer = sinon.stub(papaya.Container, 'addViewer');
    this.resetViewer = sinon.stub(papaya.Container, 'resetViewer');
  });

  teardown(function() {
    window.papayaContainers = [];
    sinon.restore();
  });

  test("constructor initializes papaya viewer", function() {
    let comp = new pbj.StudyVisualizeComponent(this.root);
    assert(this.addViewer.calledWith('visualize-study-papaya'));
  });

  test("showImage resets papaya viewer", function() {
    let comp = new pbj.StudyVisualizeComponent(this.root);

    window.papayaContainers.push({
      containerHtml: {
        parent: sinon.stub().returns({
          is: sinon.stub().returns(true)
        })
      }
    });

    let template = "https://example.com/foo/bar.nii.gz";
    let outcome = "https://example.com/foo/baz.nii.gz";
    comp.showImage({ template: template, outcome: outcome });
    assert(papaya.Container.resetViewer.calledWith(0, sinon.match.array));

    let arr = papaya.Container.resetViewer.getCall(0).args[1];
    assert.propertyVal(arr, 'noNewFiles', true);
    assert.sameOrderedMembers([template, outcome], arr.images);
  });
});

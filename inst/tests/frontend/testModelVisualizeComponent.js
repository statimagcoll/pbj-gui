suite("ModelVisualizeComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div id="visualize-model-vars">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Mean</th>
              <th>Median</th>
              <th>NAs</th>
              <th>NA%</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
          </tbody>
        </table>
        <template id="visualize-model-var-row">
          <tr>
            <td data-type="name"></td>
            <td data-type="mean"></td>
            <td data-type="median"></td>
            <td data-type="na"></td>
            <td data-type="naPct"></td>
            <td>
              <a href="#"><i class="fas fa-arrow-circle-right"></i></a>
            </td>
          </tr>
        </template>
        <div id="visualize-model-var" class="d-none">
          <span data-type="name"></span>
          <span data-type="mean"></span>
          <span data-type="median"></span>
          <span data-type="na"></span>
          <span data-type="naPct"></span>
          <img />
          <button id="visualize-model-add-full">Add to full formula</button>
          <button id="visualize-model-add-reduced">Add to reduced formula</button>
          <a href="#" class="back">&lt; Back</a>
        </div>
      </div>
    `;

    this.api = sinon.createStubInstance(pbj.API);
    this.histUrl = new URL('https://example.com/foo');
    this.api.makeURL.withArgs('hist').returns(this.histUrl);

    this.study = {
      varInfo: [
        {name: 'foo', num: true, mean: 123, median: 124, na: 125, naPct: 20},
        {name: 'bar', num: false},
        {name: 'baz', num: true, mean: 789, median: 790, na: 0, naPct: 0}
      ]
    };
  });

  teardown(function() {
    sinon.restore();
  });

  test("setStudy adds table rows", function() {
    let comp = new pbj.ModelVisualizeComponent(this.root, this.api);
    comp.setStudy(this.study);

    let trs = this.root.querySelectorAll('table tbody tr');
    assert.lengthOf(trs, 2);

    let tds = trs[0].querySelectorAll('td');
    assert.equal('foo', tds[0].textContent);
    assert.equal('123', tds[1].textContent);
    assert.equal('124', tds[2].textContent);
    assert.equal('125', tds[3].textContent);
    assert.equal('20', tds[4].textContent);

    tds = trs[1].querySelectorAll('td');
    assert.equal('baz', tds[0].textContent);
    assert.equal('789', tds[1].textContent);
    assert.equal('790', tds[2].textContent);
    assert.equal('0', tds[3].textContent);
    assert.equal('0', tds[4].textContent);
  });

  test('setStudy enables row links', function() {
    let comp = new pbj.ModelVisualizeComponent(this.root, this.api);
    comp.setStudy(this.study);

    let link = this.root.querySelector('table tbody tr:first-child td:last-child a');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);

    let mainDiv = this.root.querySelector('#visualize-model-vars');
    assert.equal('d-none', mainDiv.getAttribute('class'));

    let varDiv = this.root.querySelector('#visualize-model-var');
    assert.equal('', varDiv.getAttribute('class'));
    assert.equal('foo', varDiv.querySelector('span[data-type="name"]').textContent);
    assert.equal('123', varDiv.querySelector('span[data-type="mean"]').textContent);
    assert.equal('124', varDiv.querySelector('span[data-type="median"]').textContent);
    assert.equal('125', varDiv.querySelector('span[data-type="na"]').textContent);
    assert.equal('20', varDiv.querySelector('span[data-type="naPct"]').textContent);
    assert.equal('https://example.com/foo?var=foo', varDiv.querySelector('img').getAttribute('src'));
  });

  test('setStudy enables full formula button', function() {
    let comp = new pbj.ModelVisualizeComponent(this.root, this.api);
    comp.setStudy(this.study);

    let spy = sinon.spy();
    comp.addEventListener('addVarToFullFormula', spy);

    let link = this.root.querySelector('table tbody tr:first-child td:last-child a');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);

    let btn = this.root.querySelector('#visualize-model-add-full');
    event = new MouseEvent('click');
    btn.dispatchEvent(event);

    assert(spy.called);
  });

  test('setStudy enables reduced formula button', function() {
    let comp = new pbj.ModelVisualizeComponent(this.root, this.api);
    comp.setStudy(this.study);

    let spy = sinon.spy();
    comp.addEventListener('addVarToReducedFormula', spy);

    let link = this.root.querySelector('table tbody tr:first-child td:last-child a');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);

    let btn = this.root.querySelector('#visualize-model-add-reduced');
    event = new MouseEvent('click');
    btn.dispatchEvent(event);

    assert(spy.called);
  });

  test('enables back link in variable detail view', function() {
    let comp = new pbj.ModelVisualizeComponent(this.root, this.api);
    comp.setStudy(this.study);

    let link = this.root.querySelector('table tbody tr:first-child td:last-child a');
    let event = new MouseEvent('click');
    link.dispatchEvent(event);

    link = this.root.querySelector('#visualize-model-var a.back');
    event = new MouseEvent('click');
    link.dispatchEvent(event);

    let mainDiv = this.root.querySelector('#visualize-model-vars');
    assert.equal('', mainDiv.getAttribute('class'));

    let varDiv = this.root.querySelector('#visualize-model-var');
    assert.equal('d-none', varDiv.getAttribute('class'));
  });
});

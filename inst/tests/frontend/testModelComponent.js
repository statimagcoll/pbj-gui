suite("ModelComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <form>
        <input id="model-formfull" name="formfull" type="text" />
        <input id="model-formred" name="formred" type="text" value="~ 1" />
        <select id="model-transform" name="transform">
          <option>none</option>
          <option>t</option>
          <option>edgeworth</option>
        </select>
        <select id="model-weights-column" name="weightsColumn">
          <option></option>
        </select>
        <input id="model-inverted-weights" type="checkbox" name="invertedWeights" value="true">
        <input id="model-robust" type="checkbox" name="robust" value="true" checked>
        <input id="model-zeros" type="checkbox" name="zeros" value="true">
        <input id="model-HC3" type="checkbox" name="HC3" value="true" checked>
        <button id="model-submit" class="active"></button>
      </form>
    `;
    this.api = sinon.createStubInstance(pbj.API);
    this.clock = sinon.useFakeTimers();
  });

  teardown(function() {
    sinon.restore();
    this.clock.restore();
  });

  test('setStudy creates weight column options', function() {
    let comp = new pbj.ModelComponent(this.root, this.api);

    let study = {
      varInfo: [
        { num: true, name: 'foo' },
        { num: false, name: 'bar' },
        { num: true, name: 'baz' }
      ]
    };
    comp.setStudy(study);

    let options = this.root.querySelectorAll('#model-weights-column option');
    assert.equal(3, options.length);
    assert.equal('', options[0].textContent);
    assert.equal('foo', options[1].textContent);
    assert.equal('baz', options[2].textContent);
  });

  test('setStudy configures form values', function() {
    let comp = new pbj.ModelComponent(this.root, this.api);

    let study = {
      varInfo: [
        { num: true, name: 'foo' },
        { num: false, name: 'bar' },
        { num: true, name: 'baz' }
      ],
      model: {
        formfull: 'foo', formred: 'bar', transform: 't',
        weightsColumn: 'baz', invertedWeights: true,
        robust: false, zeros: true, HC3: false
      }
    };
    comp.setStudy(study);

    let fd = new FormData(this.root.querySelector('form'));
    assert.equal('foo', fd.get('formfull'));
    assert.equal('bar', fd.get('formred'));
    assert.equal('t', fd.get('transform'));
    assert.equal('baz', fd.get('weightsColumn'));
    assert.equal('true', fd.get('invertedWeights'));
    assert.equal(null, fd.get('robust'));
    assert.equal('true', fd.get('zeros'));
    assert.equal(null, fd.get('HC3'));
  });

  suite('form submission', function() {
    setup(function() {
      this.comp = new pbj.ModelComponent(this.root, this.api);
      this.study = {
        varInfo: [
          { num: true, name: 'foo' },
          { num: false, name: 'bar' },
          { num: true, name: 'baz' }
        ]
      };
      this.comp.setStudy(this.study);

      this.form = this.root.querySelector('form');
      this.submitButton = this.form.querySelector('#model-submit');

      this.form.querySelector('input[name="formfull"]').value = "~ foo + bar";
      this.form.querySelector('input[name="formred"]').value = "~ foo";
      this.form.querySelector('select[name="transform"]').selectedIndex = 1;
      this.form.querySelector('select[name="weightsColumn"]').selectedIndex = 1;
      this.form.querySelector('input[name="invertedWeights"]').checked = true;
      this.form.querySelector('input[name="robust"]').checked = false;
      this.form.querySelector('input[name="zeros"]').checked = true;
      this.form.querySelector('input[name="HC3"]').checked = false;
      let event = new SubmitEvent('submit');
      this.form.dispatchEvent(event);
    });

    test('disables submit button', function() {
      assert(this.submitButton.hasAttribute('disabled'));
      assert.equal('running', this.submitButton.getAttribute('class'));
    });

    test('makes API call', function() {
      assert(this.api.createStatMap.calledWith(sinon.match.object,
        sinon.match.func));

      let call = this.api.createStatMap.getCall(0);
      let expected = {
        formfull: '~ foo + bar', formred: '~ foo', transform: 't',
        weightsColumn: 'foo', invertedWeights: true,
        robust: false, zeros: true, HC3: false
      };
      assert.deepEqual(expected, call.args[0]);
    });

    test('sets up timeout to check for completion', function() {
      let call = this.api.createStatMap.getCall(0);
      let callback = call.args[1];
      callback({}, 200);
      this.clock.tick(3000);

      assert(this.api.getStatMap.calledWith(sinon.match.func));
    });

    test('re-triggers timeout if job is still running', function() {
      let call = this.api.createStatMap.getCall(0);
      let callback = call.args[1];
      callback({}, 200);
      this.clock.tick(3000);

      call = this.api.getStatMap.getCall(0);
      callback = call.args[0];

      this.api.getStatMap.reset();
      callback({ status: 'running' }, 200);
      this.clock.tick(3000);
      assert(this.api.getStatMap.called);
    });

    test('dispatches event after job is finished', function() {
      let listener = sinon.stub();
      this.comp.addEventListener('statMapCreated', listener);

      let call = this.api.createStatMap.getCall(0);
      let callback = call.args[1];
      callback({}, 200);
      this.clock.tick(3000);

      call = this.api.getStatMap.getCall(0);
      callback = call.args[0];

      this.api.getStatMap.reset();
      let statMap = { foo: 'bar' }
      callback({ status: 'finished', statMap: statMap }, 200);
      assert(this.api.getStatMap.notCalled);
      assert(listener.called);

      call = listener.getCall(0);
      assert.deepEqual(statMap, call.args[0].detail);
    });
  });
});

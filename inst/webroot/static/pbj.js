var browsePath, token, statMapInfo, seiInfo;
function checkDataset(path) {
  if (typeof(token) === 'undefined') {
    console.error('token is undefined!');
    return;
  }

  let modal = $('#modal');
  let selectButton = modal.find('#modal-select-button');
  selectButton.prop('disabled', true).off('click');
  $.ajax({
    type: 'POST',
    url: `/checkDataset?token=${token}`,
    data: JSON.stringify({ path: path }),
    contentType: 'application/json',
    dataType: 'html',
    success: function(html) {
      modal.find('.modal-title').text('Assign dataset columns');
      modal.find('.modal-footer .text').text('');

      // Replace the content
      modal.find('.modal-body').html(html);
      modal.modal('show');

      modal.find('form input').change(function(event) {
        let set = modal.find('form input:checked');
        selectButton.prop('disabled', set.length != 1);
      });

      selectButton.click(function(event) {
        event.preventDefault();
        setFile('dataset', modal.find('form').data('path'));
        modal.find('input:checked').each(function(index) {
          let obj = $(this);
          let name = obj.attr('name');
          let value = obj.val();
          $('#study-dataset-' + name).val(value);
        });
        $('#study-dataset-columns').collapse('show');
        modal.modal('hide');
      });
    },
    error: function(xhr) {
      let content = '<pre>' + xhr.responseText + '</pre>';
      modal.find('#browse-error').html(content).removeClass('d-none');
    }
  });
}

function setFile(name, path) {
  $('#study-selected-' + name).text(path);
  $('#study-' + name).val(path);

  let invalid = false;
  $('#welcome-form input:required').each(function() {
    if ($(this).val() === "") {
      invalid = true;
      return(false);
    }
  });
  $('#study-submit').prop('disabled', invalid);
}

function browse(name, type, path) {
  if (typeof(token) === 'undefined') {
    console.error('token is undefined!');
    return;
  }

  // save browse path for subsequent calls
  browsePath = path;

  let modal = $('#modal');
  let selectButton = modal.find('#modal-select-button');
  selectButton.off('click');

  let payload = { type: type, path: path };
  $.ajax({
    type: 'POST',
    url: `/browse?token=${token}`,
    data: JSON.stringify(payload),
    contentType: 'application/json',
    dataType: 'json',
    success: function(data) {
      modal.find('.modal-title').text('Select ' + name);
      modal.find('.modal-footer .text').text('File pattern: ' + data.glob);

      // Replace the content
      modal.find('.modal-body').html(data.html);

      let table = modal.find('table.browse');
      table.find('tbody tr.file td').click(function(event) {
        let obj = $(event.target).parent();
        obj.siblings('.selected').removeClass('selected');
        obj.toggleClass('selected');
        selectButton.prop('disabled', table.find('tr.selected').length == 0);
      });
      table.find('tbody tr.folder td').dblclick(function(event) {
        let obj = $(event.target).parent();
        obj.addClass('focused');
        browse(name, type, obj.data('path'));
      });
      selectButton.prop('disabled', table.find('tr.selected').length == 0);

      // Select file if user clicks on select button
      selectButton.on('click', function(event) {
        event.preventDefault();
        let selectedPath = table.find('tr.selected').data('path');
        if (name == 'dataset') {
          checkDataset(selectedPath);
        } else {
          setFile(name, selectedPath);
          modal.modal('hide');
        }
      });

      // Select file if user double clicks on a file row
      table.find('tbody tr.file td').dblclick(function(event) {
        let obj = $(event.target).parent();
        let selectedPath = obj.data('path');
        if (name == 'dataset') {
          checkDataset(selectedPath);
        } else {
          setFile(name, selectedPath);
          modal.modal('hide');
        }
      });

      modal.find('button[name="parent"]').click(function(event) {
        event.preventDefault();
        let path = $(this).data('path');
        browse(name, type, path);
      });

      modal.find('form').submit(function(event) {
        event.preventDefault();
        let obj = $(event.target);
        let newPath = obj.find('input[name="path"]').val();
        browse(name, type, newPath);
      });

      modal.modal('show')
    },
    error: function(xhr) {
      if (typeof(xhr.responseJSON) === 'undefined') {
        console.log('unknown error:', xhr);
      }
      $('#modal').find('form').append('<i class="fa fa-exclamation-triangle text-danger"></i>');
    }
  });
}

function initWelcome() {
  if (typeof(token) === 'undefined') {
    console.error('token is undefined!');
    return;
  }

  $('#welcome-form button.browse').click(function(event) {
    event.preventDefault();
    let obj = $(event.target);
    browse(obj.data('name'), obj.data('type'), browsePath);
  });

  $('#welcome-form').submit(function(event) {
    event.preventDefault();

    let payload = {};
    $(this).find('input').each(function(index) {
      let obj = $(this);
      payload[obj.attr('name')] = obj.val();
    });

    $.ajax({
      type: 'POST',
      url: `/createStudy?token=${token}`,
      data: JSON.stringify(payload),
      contentType: 'application/json',
      dataType: 'json',
      success: function(data) {
        $('#study').html(data.study);
        $('#model').html(data.model);
        $('#welcome').fadeOut('fast', function() {
          $('#main').fadeIn('fast', initMain);
        });
        //$('#visualize-content').html(data.visualize);
        //$('#model-content').html(data.model);
        //$('#visualize-link').removeClass('disabled').tab('show');
        //$('#model-link').removeClass('disabled');
      },
      error: function(xhr) {
        if (typeof(xhr.responseJSON) === 'undefined') {
          console.log('unknown error:', xhr);
        }
      }
    });
  });
}

function checkStatMap() {
  if (typeof(token) === 'undefined') {
    console.error('token is undefined!');
    return;
  }

  $.ajax({
    type: 'GET',
    url: `/statMap?token=${token}`,
    contentType: 'application/json',
    success: function(result) {
      //let log = $('#statmap-log');
      //log.text(result.log).removeClass('d-none');

      if (result.status == 'running') {
        setTimeout(checkStatMap, 3000);
      } else if (result.status == 'finished') {
        //console.log('statmap finished, setting up interface');

        // hide job log
        //log.addClass('d-none');

        // set statmap tab content
        //console.log('set statmap tab content');
        $('#statmap').html(result.html).ready(initStatMap);

        // enable statmap nav link and show tab
        //console.log('enable statmap nav link and show tab');
        $('#statmap-tab').removeClass('disabled').tab('show');

        // re-enable model form submit button
        //console.log('re-enable model form submit button');
        $('#model-submit').prop('disabled', false).
          removeClass('running').addClass('active');

        //console.log('done setting up statmap interface');
      }
    },
    error: function(xhr) {
      console.log('unknown error:', xhr);
      $('#model-submit').prop('disabled', false).removeClass('running');
    }
  });
}

function getStudyPapayaParams() {
  let active = $('#study-data-row option:selected');
  let template = active.data('template');
  let outcome = active.data('outcome');

  let result = [];
  result["noNewFiles"] = true;
  result["images"] = [];
  if (template) {
    result["images"].push(template);
  }
  result["images"].push(outcome);
  return(result);
}

function addModelHist(id, name) {
  let url = `/hist?token=${token}&var=${name}"`;
  $(`<img id="hist-${id}" src="${url}">`).appendTo('#visualize-model');
}

function initStudyPapaya() {
  //console.log('running initStudyPapaya');
  let params = getStudyPapayaParams();
  papaya.Container.addViewer('visualize-study-papaya', params);
}

function getPapayaIndex(parentName) {
  for (let i = 0; i < papayaContainers.length; i++) {
    if (papayaContainers[i].containerHtml.parent().is(`#visualize-${parentName}-papaya`)) {
      return i;
    }
  }
  return -1;
}

function initMain() {
  if (typeof(token) === 'undefined') {
    console.error('token is undefined!');
    return;
  }

  // hook up select box in study tab
  $('#study-data-row').change(function(e) {
    let index = getPapayaIndex('study');
    if (index > -1) {
      let params = getStudyPapayaParams();
      papaya.Container.resetViewer(index, params);
    }
  });

  // add initial model histograms
  let modelVisForm = $('#model-visualize-form');
  modelVisForm.find('input.toggle:checked').each(function() {
    let obj = $(this);
    addModelHist(obj.data('id'), obj.attr('name'));
  });

  // hook up histogram checkboxes in model tab
  modelVisForm.find('input.toggle').change(function(event) {
    let obj = $(event.target);
    let id = obj.data('id');
    let img = $(`#visualize-model #hist-${id}`);
    if (obj.is(':checked')) {
      img.fadeIn('fast');

      let all = modelVisForm.find('input.toggle:not(:checked)').length == 0;
      $('#model-visualize-all').prop('checked', all);
    } else {
      img.fadeOut('fast');
      $('#model-visualize-all').prop('checked', false);
    }
  });

  $('#model-visualize-all').change(function(event) {
    let obj = $(this);
    if (obj.is(':checked')) {
      modelVisForm.find('input.toggle:not(:checked)').
        prop('checked', true).change();
    } else {
      modelVisForm.find('input.toggle:checked').
        prop('checked', false).change();
    }
  });

  // hook up statmap creation form in model tab
  $('#model-form').submit(function(event) {
    event.preventDefault();

    let form = $(this);
    let data = {
      'token': token,
      'formfull': form.find('input[name="formfull"]').val(),
      'formred':  form.find('input[name="formred"]').val(),
      'weightsColumn': form.find('select[name="weightsColumn"]').val(),
      'invertedWeights': form.find('input[name="invertedWeights"]').is(":checked"),
      'robust': form.find('input[name="robust"]').is(":checked"),
      'transform': form.find('select[name="transform"]').val(),
      'zeros': form.find('input[name="zeros"]').is(":checked"),
      'HC3': form.find('input[name="HC3"]').is(":checked"),
    };

    $('#model-submit').prop('disabled', true).
      removeClass('active').addClass('running');

    $.ajax({
      type: 'POST',
      url: `/createStatMap?token=${token}`,
      data: JSON.stringify(data),
      contentType: 'application/json',
      success: function(result) {
        setTimeout(checkStatMap, 3000);
      },
      error: function(xhr) {
        console.log('unknown error:', xhr);
      }
    });
  });

  // toggle study visualization on study tab change
  $('#main a[data-toggle="tab"]').on('show.bs.tab', function(event) {
    let prev, prevName;
    if (typeof(event.relatedTarget) !== 'undefined') {
      prev = $(event.relatedTarget);
      prevName = prev.data('target');
    }
    let curr = $(event.target);
    let currName = curr.data('target');

    // setup papaya only after container element is visible
    let papayaCallback = function() {
      if (currName == 'statmap') {
        if ($('#visualize-statmap-papaya').children().length == 0) {
          setTimeout(initStatMapPapaya, 1);
        }
      //} else if (currName == 'study') {
        //if ($('#visualize-study-papaya').children().length == 0) {
          //setTimeout(initStudyPapaya, 1);
        //}
      } else if (currName == 'sei') {
        if ($('#visualize-sei-study').children().length == 0) {
          setTimeout(initSEIPapaya, 1);
        }
      }
    };

    if (typeof(prev) !== 'undefined') {
      $(`#${prevName}`).fadeOut('fast', function() {
        $(`#${currName}`).fadeIn('fast');
      });
      $(`#visualize-${prevName}`).fadeOut('fast', function() {
        $(`#visualize-${currName}`).fadeIn('fast', papayaCallback);
      });
    } else {
      $(`#${currName}`).fadeIn('fast');
      $(`#visualize-${currName}`).fadeIn('fast', papayaCallback);
    }
  });

  // initialize papaya if study tab is active
  if ($('#study-tab').hasClass('active')) {
    initStudyPapaya();
  }
}

function getStatMapPapayaParams() {
  if (statMapInfo === undefined) {
    console.error('statMapInfo is undefined!');
    return undefined;
  }

  let active = $('#statmap-image option:selected');
  let imageName = active.data('name');

  let params = [];
  params['images'] = [];

  if ('template' in statMapInfo) {
    params['images'].push(statMapInfo['template'])
  }
  params['images'].push(statMapInfo[imageName])

  return params;
}

function initStatMapPapaya() {
  //console.log('running initStatMapPapaya');
  let params = getStatMapPapayaParams();
  if (params === undefined) {
    console.error('statMap params is undefined!');
    return;
  }

  papaya.Container.addViewer('visualize-statmap-papaya', params);
}

function deleteSeiCft(event) {
  event.preventDefault();

  if ($('#sei-cft-groups .sei-cft-group').length == 1) {
    // don't delete the last one
    return;
  }

  $(event.target).parent('.sei-cft-group').remove();
}

function initStatMap() {
  //console.log('running initStatMap');
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
}

function checkSEI() {
  if (typeof(token) === 'undefined') {
    console.error('token is undefined!');
    return;
  }

  $.ajax({
    type: 'GET',
    url: `/sei?token=${token}`,
    contentType: 'application/json',
    success: function(result) {
      let progress = $('#sei-progress').removeClass('d-none');
      let pct = Math.round(result.progress.n / result.progress.total * 100);
      progress.find('p').text(`Completed ${result.progress.n} of ${result.progress.total} passes.`)
      progress.find('.progress-bar').width(`${pct}%`);

      if (result.status == 'running') {
        setTimeout(checkSEI, 3000);
      } else if (result.status == 'finished') {
        // hide job progress
        progress.addClass('d-none');

        // set sei tab content
        $('#sei').html(result.html).ready(initSEI);

        // enable sei nav link and show tab
        $('#sei-tab').removeClass('disabled').tab('show');

        // re-enable sei form submit button
        $('#sei-submit').prop('disabled', false).
          removeClass('running').addClass('active');
      }
    },
    error: function(xhr) {
      console.log('unknown error:', xhr);
      $('#sei-submit').prop('disabled', false).removeClass('running');
    }
  });
}

function getSEIPapayaParams() {
  if (seiInfo === undefined) {
    console.error('seiInfo is undefined!');
    return undefined;
  }

  let active = $('#sei-image option:selected');
  let imageName = active.data('name');

  let params = [];
  params['images'] = [];

  if ('template' in seiInfo) {
    params['images'].push(seiInfo['template'])
  }
  params['images'].push(seiInfo[imageName])

  return params;
}

function initSEIPapaya() {
  //console.log('running initSEIPapaya');
  let params = getSEIPapayaParams();
  console.log(params);
  if (params === undefined) {
    console.error('sei params is undefined!');
    return;
  }

  papaya.Container.addViewer('visualize-sei-papaya', params);
}

function initSEI() {
  $('#sei-image').change(function(e) {
    let index = getPapayaIndex('sei');
    if (index > -1) {
      let params = getSEIPapayaParams();
      if (params === undefined) {
        console.error('sei params is undefined!');
        return;
      }
      papaya.Container.resetViewer(index, params);
    }
  });
}

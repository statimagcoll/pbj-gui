suite("StatMapComponent", function() {
  setup(function() {
    this.root = document.createElement('div');
    this.root.innerHTML = `
      <div>
        <form id="statmap-visualize-form" autocomplete="off">
          <select id="statmap-image" class="form-control" name="image">
            <option data-name="stat" selected>Chi-squared statistic</option>
            <option data-name="coef">Coefficient</option>
          </select>
        </form>

        <form id="sei-form" class="mt-4">
          <fieldset class="d-flex flex-column form-group">
            <legend>
              Cluster forming thresholds
              <i class="far fa-question-circle" title="Cluster forming thresholds"
                data-toggle="popover" data-container="body" data-trigger="hover"
                data-custom-class="text-justify text-break"
                data-content="This is the uncorrected threshold used to define spatially contiguous suprathreshold clusters. p-values for these clusters are then computed using the spatial extent or spatial mass of each cluster. Adjusted p-values are assigned based on the distribution of the maximum extent (or mass) cluster under the global null hypothesis that the parameter values for the covariates of interest are zero."
              ></i>
            </legend>
            <div class="d-flex flex-row">
              <div class="mr-4">
                Threshold type:
                <i class="far fa-question-circle" title="Threshold type"
                  data-toggle="popover" data-container="body" data-trigger="hover"
                  data-custom-class="text-justify text-break"
                  data-content="The cluster forming threshold can be chosen to satisfy a robust effect size index (RESI; Vandekar & Stephens 2021) or p-value threshold."
                ></i>
              </div>
              <div class="form-check mr-4">
                <input class="form-check-input" type="radio" name="cftType" id="cft-type-s" value="s">
                <label class="form-check-label" for="cft-type-s">Effect size</label>
              </div>
              <div class="form-check mr-4">
                <input class="form-check-input" type="radio" name="cftType" id="cft-type-p" value="p">
                <label class="form-check-label" for="cft-type-p">p-value</label>
              </div>
            </div>
            <div id="sei-cft-groups" class="d-flex flex-row flex-wrap">
              <template>
                <div class="d-flex flex-row align-items-center mr-3 mt-3 sei-cft-group">
                  <input class="form-control sei-cft-input mr-1" name="cfts[]" type="number" step="0.01">
                  <i class="fa fa-trash sei-cft-trash"></i>
                </div>
              </template>
            </div>
            <div class="mt-3">
              <button id="sei-cft-add" class="btn btn-secondary"><i class="fa fa-plus"></i> Add</button>
            </div>
          </fieldset>

          <div class="form-group">
            <label for="sei-method">
              Resampling method
              <i class="far fa-question-circle" title="Resampling method"
                data-toggle="popover" data-container="body" data-trigger="hover"
                data-custom-class="text-justify text-break"
                data-content="The type of resampling method to choose. Defaults to Wild T Rademacher bootstrap. Permutation is also highly effective. The permutation method is the Freedman-Lane procedure implemented in FSL's randomise (Winkler 2014)."
              ></i>
            </label>
            <select id="sei-method" class="form-control" name="method">
              <option>t</option>
              <option>permutation</option>
              <option>conditional</option>
              <option>nonparametric</option>
            </select>
          </div>

          <div class="form-group">
            <label for="sei-nboot">Number of bootstrap samples</label>
            <input id="sei-nboot" class="form-control" name="nboot" type="number"
                   step="1" min="1">
          </div>

          <button id="sei-submit" type="submit" class="btn btn-primary active">
            <span class="label">Resample</span>
            <span class="spinner spinner-border spinner-border-sm" role="status"></span>
            <span class="running">Running...</span>
          </button>
          <div id="sei-progress" class="d-none mt-3">
            <p></p>
            <div class="progress">
              <div class="progress-bar progress-bar-striped progress-bar-animated" role="progressbar" aria-valuenow="75" aria-valuemin="0" aria-valuemax="100"></div>
            </div>
          </div>
        </form>
      </div>
    `;
    this.api = sinon.createStubInstance(pbj.API);
  });

  teardown(function() {
    sinon.restore();
  });
});

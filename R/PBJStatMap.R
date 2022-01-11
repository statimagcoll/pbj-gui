PBJStatMap <- setRefClass(
  Class = "PBJStatMap",
  fields = c("statMap", "template"),
  methods = list(
    initialize = function(statMap, template) {
      statMap <<- statMap
      template <<- template
    },

    getStat = function() {
      statMap$stat
    },

    getCoef = function() {
      statMap$coef
    },

    toList = function() {
      list(
        stat = statMap$stat,
        coef = statMap$coef,
        template = template
      )
    }
  )
)

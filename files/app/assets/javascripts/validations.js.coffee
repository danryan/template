jQuery.validator.setDefaults
  errorClass: 'help-inline'
  validClass: 'success'
  success: (label) ->
    $(label).parents(".control-group").addClass("success")
  highlight: (element, errorClass, validClass) ->
    $(element).parents(".control-group").removeClass("success").addClass("error")
  unhighlight: (element, errorClass, validClass) ->
    $(element).parents(".control-group").removeClass("error")
  errorElement: 'span'
  ignore: null

jQuery.validator.addMethod "equals", 
  (value, element, param) ->
    if this.optional(element)
      return true

    values = $(element).val().split()

    _.each values, (val) ->
      unless _.include(param, val)
        return false

    return true

  jQuery.format("")
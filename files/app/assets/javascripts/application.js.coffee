# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
# or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# the compiled file.
# WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
# GO AFTER THE REQUIRES BELOW.
#
#= require jquery
#= require jquery_ujs
#= require underscore
#= require bootstrap
#= require bootstrap_ujs
#= require select2
#= require jquery.validate
#= require jquery.validate.additional-methods
#
#= require validations
#= require_tree .

jQuery ->
  # use AJAX to submit the "request invitation" form
  $('#invitation_button').live 'click', ->
    email = $('form #user_email').val()

    if $('form #user_opt_in').is(':checked')
      opt_in = true
    else
      opt_in = false

    dataString = "user[email]=#{email}&user[opt_in]=#{opt_in}"

    $.ajax
      type: "POST"
      url: "/users"
      data: dataString
      success: (data) ->
        $('#request-invite').html(data)
        loadSocial()
    return false;

# # load social sharing scripts if the page includes a Twitter "share" button
class loadSocial
  constructor: -> 
    # Twitter
    if (typeof (twttr) is not 'undefined')
      twttr.widgets.load()
    else
      $.getScript('http:#platform.twitter.com/widgets.js')

    # Facebook
    if (typeof (FB) != 'undefined')
      FB.init 
      status: true
      cookie: true
      xfbml: true
    else
      $.getScript("http:#connect.facebook.net/en_US/all.js#xfbml=1", ->
        FB.init({ status: true, cookie: true, xfbml: true })

    # Google+
    if (typeof (gapi) != 'undefined')
      $(".g-plusone").each ->
        gapi.plusone.render $(this).get(0)
    else
      $.getScript('https:#apis.google.com/js/plusone.js')

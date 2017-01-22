class ControlsView extends Marionette.ItemView

  initialize: ->
    @model.set "paused", false
    @model.set "minAge", 0
    @model.set "maxAge", 150

  template: require "../templates/controls.jade"

  modelEvents:
    "change": "render"

  events:
    "click button.pause": "pauseButtonClicked"
    "change input#minAge": "minAge"
    "change input#maxAge": "maxAge"

  pauseButtonClicked: ->
    @model.set "paused", !@model.get "paused"

  minAge: ->
    age = $("#minAge").val()
    if age >= 0 and age <= 150
      @model.set "minAge", age

  maxAge: ->
    age = $("#maxAge").val()
    if age >= 0 and age <= 150
      @model.set "maxAge", age

module.exports = ControlsView

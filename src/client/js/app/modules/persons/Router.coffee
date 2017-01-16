LayoutView = require "./views/LayoutView"

class Router extends Backbone.Router
	routes:
		"persons": "persons"

	persons: ->
		Application.layoutView.getRegion("body").show new LayoutView
		Application.triggerRoute "persons"

module.exports = Router

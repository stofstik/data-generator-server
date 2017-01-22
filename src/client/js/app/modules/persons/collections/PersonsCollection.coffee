PersonModel = require "../models/PersonModel"

class PersonsCollection extends Backbone.Collection

  url:        "persons"
  model:      PersonModel
  comparator: (person) -> -person.get "timestamp"

  initialize: ({ @controls }) ->
    @ioBind "create", @serverCreate

  serverCreate: (person) ->
    @add person if person.age >= @controls.get("minAge") \
      and person.age <= @controls.get("maxAge") \
      and !(@controls.get "paused")

    @pop() if @length > 20

module.exports = PersonsCollection

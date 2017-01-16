mongoose = require('mongoose')
Schema = mongoose.Schema

sharedDataSchema = new Schema
	port: { type: Number, required: true }
	createdAt: { type: Date, 'default': Date.now }
	updatedAt: { type: Date, 'default': Date.now }

# Do not use mongoose pluralize
sharedDataSchema.set('collection', 'sharedData')

sharedDataModel = mongoose.model('sharedData', sharedDataSchema)

module.exports = sharedDataModel

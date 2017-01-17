mongoose = require('mongoose')
Schema = mongoose.Schema

serviceSchema = new Schema
		name: { type: String, required: true }
		port: { type: Number, required: true }
		createdAt: { type: Date, 'default': Date.now }
		updatedAt: { type: Date, 'default': Date.now }

serviceModel = mongoose.model('service', serviceSchema)
serviceModel.SERVICE_NAME = "person-generator"

module.exports = serviceModel

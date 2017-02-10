_          = require "underscore"
$          = require "jquery"
Backbone   = require "backbone"
Backbone.$ = $
Marionette = require "backbone.marionette"
io         = require "socket.io-client"
sioStream  = require "socket.io-stream"

window._          = _
window.$          = $
window.jQuery     = $
window.Backbone   = Backbone
window.Marionette = Marionette

require "backbone.babysitter"
require "backbone.wreqr"
require "backbone.iobind/dist/backbone.iobind.js"
require "backbone.iobind/dist/backbone.iosync.js"
require "bootstrap"

# load marionette application
Application = window.Application = require "./Application"

# load application modules
require "./modules/todos"
require "./modules/persons"

# setup connection logic
address  = "/"
console.log "Connecting to #{address}"
socket = io.connect "#{address}",
  "reconnection": true
  "reconnection delay": 2000

# hack to play pause stream
stream = sioStream.createStream
  objectMode: true
window.onkeyup = (e) ->
  if !stream.isPaused()
    console.log 'pausing'
    stream.pause()
  else
    console.log 'resumed'
    stream.resume()

# start the app when socket.io is connected to the server
socket.on "connect", ->
  console.log "Connected"
  # create a socket.io-stream object
  stream = sioStream.createStream
    objectMode:    true

  # send the stream object over socket.io so we can pipe to it on the server
  sioStream(socket).emit "streamplz", stream
  # on data of our stream object log it to the console
  stream.on "data", (data) ->
    console.log data

  # start the client app
  Application.start()

  if Backbone.History.started
    route = Backbone.history.fragment or ""
    Backbone.history.loadUrl route
  else
    Backbone.history.start()

window.Application = Application
window.socket      = socket


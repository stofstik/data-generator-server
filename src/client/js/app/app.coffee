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
address  = "/person-stream"
console.log "Connecting to #{address}"
socket = io.connect "#{address}",
  "reconnect":          true
  "reconnection delay": 2000

socket.on "connect", ->
  console.log "Connected"
  # create a socket.io-stream object
  stream = sioStream.createStream()
  # send a stream object over sockets so we can stream to it on the server
  sioStream(socket).emit 'hello', stream
  # on data of our stream object log it to the console
  stream.on "data", (data) ->
    console.log data.toString 'utf-8'

  # start the client app
  Application.start()

  if Backbone.History.started
    route = Backbone.history.fragment or ""
    Backbone.history.loadUrl route
  else
    Backbone.history.start()

window.Application = Application
window.socket      = socket


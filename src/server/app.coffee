# required modules
_              = require "underscore"
async          = require "async"
http           = require "http"
express        = require "express"
path           = require "path"
methodOverride = require "method-override"
bodyParser     = require "body-parser"
socketio       = require "socket.io"
ioClient       = require "socket.io-client"
errorHandler   = require "error-handler"
mongoose       = require "mongoose"

log            = require "./lib/log"

Service      = require "./models/service-model"
app          = express()
server       = http.createServer app
io           = socketio.listen server
host         = "http://localhost"
mongoAddress = "mongodb://localhost:27017/Services"

# init mongo status logging
db = mongoose.connection
db.on 'connected', ->
  log.info "connected to mongodb"
db.on 'connecting', ->
  log.info "connecting to mongodb"
db.on 'error', (err) ->
  console.error err
  log.info "error connecting to mongodb"
db.on 'disconnected', ->
  log.info "disconnected from mongodb"

# collection of client sockets
sockets = []

retry = ->
  setTimeout ->
    connectToGenerator()
  , 5000

# connect to generator service
connectToGenerator = ->
  # find the person-generator service in the db
  Service.findOne { name: Service.SERVICE_NAME}, (err, data) ->
    # check for errors
    if(err)
      log.info "Error", err
      retry()
    if(!data)
      log.info "Error: no data"
      retry()

    # connect to the service with the data from the db
    address = "#{host}:#{data.port}"
    log.info "connecting to generator at #{address}"
    generator = ioClient.connect address,
      # we want to switch ports so handle reconnection ourselves
      "reconnection": false

    generator.on "connect", (socket) ->
      log.info "connected to generator"
      generator.on "dataGenerated", (data) ->
        socket.emit "persons:create", data for socket in sockets

    generator.on "connect_error", (err) ->
      log.info "could not reach generator at #{data.port}"
      retry()

    generator.on "disconnect", ->
      log.info "disconnected from generator"
      retry()

# websocket connection logic
io.on "connection", (socket) ->
  # add socket to client sockets
  sockets.push socket
  log.info "Socket connected, #{sockets.length} client(s) active"

  # disconnect logic
  socket.on "disconnect", ->
    # remove socket from client sockets
    sockets.splice sockets.indexOf(socket), 1
    log.info "Socket disconnected, #{sockets.length} client(s) active"

# express application middleware
app
  .use bodyParser.urlencoded extended: true
  .use bodyParser.json()
  .use methodOverride()
  .use express.static path.resolve __dirname, "../client"

# express application settings
app
  .set "view engine", "jade"
  .set "views", path.resolve __dirname, "./views"
  .set "trust proxy", true

# express application routess
app
  .get "/", (req, res, next) ->
    res.render "main"

# start the server
mongoose.connect mongoAddress
connectToGenerator()
server.listen 3000
log.info "Listening on 3000"

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

log            = require "./lib/log"

app          = express()
server       = http.createServer app
io           = socketio.listen server
# fixed location of service registry
servRegAddress = "http://localhost:3001"

SERVICE_NAME = "web-server"

# collection of client sockets
sockets = []

# websocket connection logic
io.on "connection", (socket) ->
  # add socket to client sockets
  sockets.push socket
  log.info "Socket connected, #{sockets.length} client(s) active"

  # TODO some kind of filter to pass on to the generators
  socket.on "setFilter", (filter) ->
    console.log filter

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

# connect to the service registry
serviceRegistry = ioClient.connect servRegAddress,
  "reconnection": true

# when we are connected to the registry start the web server
serviceRegistry.on "connect", (socket) ->
  server.listen 3000
  serviceRegistry.emit "service-up",
    name: SERVICE_NAME
    port: server.address().port

  log.info "Listening on port", server.address().port

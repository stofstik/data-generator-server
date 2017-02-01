# required modules
async          = require "async"
http           = require "http"
net            = require "net"
express        = require "express"
request        = require "request"
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

# use our audio generator endpoint
app
  .use(require("./routes/audiostream"))

# express application routes
app
  .get "/", (req, res, next) ->
    res.render "main"

# connect to the service registry
serviceRegistry = ioClient.connect servRegAddress,
  "reconnection": true

# when we are connected to the registry start the web server
serviceRegistry.on "connect", (socket) ->
  log.info "service registry connected"
  server.listen 3000
  log.info "Listening on port", server.address().port

  # we want to subscribe to whatever person-generator emits
  serviceRegistry.emit "subscribe-to",
    name: "person-generator"
  serviceRegistry.emit "subscribe-to",
    name: "person-stream"

instances = []
# when a new service we are subscribed to starts, connect to it
serviceRegistry.on "service-up", (service) ->
  switch service.name
    when "person-stream"
      if(instances.indexOf(service.port) != -1)
        log.info "already connected"
        return
      log.info "person-stream up"
      client = net.createConnection({ port: service.port }, () ->
        log.info "connected to #{service.name}:#{service.port}"
      )
      client.setEncoding('utf-8')
      client.on('data', (data) ->
        log.info "data:", data
      )
      client.on('end', () ->
        log.info 'ended'
      )

    when "person-generator"
      if(instances.indexOf(service.port) != -1)
        log.info "already connected"
        return
      instance = ioClient.connect "http://localhost:#{service.port}",
        "reconnection": false

      instance.on "connect", (socket) ->
        console.info "connected to, #{service.name}:#{service.port}"
        instances.push service.port

      instance.on "disconnect", (socket) ->
        console.info "disconnected from, #{service.name}:#{service.port}"
        instances.splice instances.indexOf(service.port), 1

      instance.on "data", (data) ->
        log.info data
        socket.emit "persons:create", data for socket in sockets

    else
      log.info "unknown service, did we subscribe to that?"

# notify of service registry disconnect
serviceRegistry.on "disconnect", () ->
  log.info "service registry disconnected"

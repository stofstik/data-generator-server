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
sioStream      = require "socket.io-stream"
errorHandler   = require "error-handler"

log            = require "./lib/log"

app          = express()
server       = http.createServer app
io           = socketio.listen server
# fixed location of service registry
servRegAddress = "http://localhost:3001"

SERVICE_NAME = "web-server"

clients  = [] # collection of client sockets
services = [] # collection of connected services

# client websocket connection logic
io.of('/person-stream').on "connection", (clientSocket) ->
  # when a client socket connects we want to wrap it using socket.io-stream
  # this way we can use node's stream abstraction easily
  #
  # the client emits a stream object we can use
  sioStream(clientSocket).on "imastream!", (stream, data) ->
    console.log('socket.io-stream connected') # o hai
    clientSocket.sioStream = stream # add stream to socket so we can write to it
    clients.push clientSocket       # push socket to array of connected browser clients

  log.info "Socket connected, #{clients.length} client(s) active"

  # disconnect logic
  clientSocket.on "disconnect", ->
    # remove socket from client sockets array
    clients.splice clients.indexOf(clientSocket), 1
    log.info "Socket disconnected, #{clients.length} client(s) active"

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

log.info "Waiting for service registry..."

# when we are connected to the registry start the web server
serviceRegistry.on "connect", (socket) ->
  log.info "service registry connected"
  server.listen 3000
  log.info "Listening on port", server.address().port

  # we want to subscribe to whatever person-generator emits
  serviceRegistry.emit "subscribe-to",
    name: "person-stream"
  serviceRegistry.emit "subscribe-to",
    name: "person-generator"

# when a new service we are subscribed to starts, connect to it
serviceRegistry.on "service-up", (service) ->
  # Check if we already have connection
  if(services.indexOf(service.port) != -1)
    log.info "already connected"
    return

  switch service.name
    when "person-stream"
      ###
        # Stream all the things!
        ###
      log.info "person-stream up"
      # connect to our person stream service directly using a TCP stream
      serviceConnection = net.createConnection { port: service.port }, () ->
        log.info "connected to #{service.name}:#{service.port}"
        services.push service.port

      for client in clients
        return unless client.sioStream
        serviceConnection.pipe client.sioStream


      # tcp stream on data write data to socket stream
      ###
        # serviceConnection.on 'data', (data) ->
        #   return unless clients.length
        #   log.info "data:", data
        #   for client in clients
        #     return unless client.sioStream
        #     client.sioStream.write(data)
        ###

      # socket disconnecting, log and remove from services array
      serviceConnection.on 'end', () ->
        log.info 'ended'
        console.info "disconnected from, #{service.name}:#{service.port}"
        services.splice services.indexOf(service.port), 1

    when "person-generator"
      ###
        # Use socket.io to emit data from this service to all clients
        ###
      log.info "person-generator up"
      instance = ioClient.connect "http://localhost:#{service.port}",
        "reconnection": false

      instance.on "connect", (socket) ->
        console.info "connected to, #{service.name}:#{service.port}"
        services.push service.port

      instance.on "disconnect", (socket) ->
        console.info "disconnected from, #{service.name}:#{service.port}"
        services.splice services.indexOf(service.port), 1

      instance.on "data", (data) ->
        log.info data
        client.emit "persons:create", data for client in clients

    else
      log.info "unknown service, did we subscribe to that?"

# notify of service registry disconnect
serviceRegistry.on "disconnect", () ->
  log.info "service registry disconnected"

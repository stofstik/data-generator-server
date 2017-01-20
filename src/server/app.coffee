# required modules
fs             = require "fs"
async          = require "async"
http           = require "http"
express        = require "express"
request        = require "request"
path           = require "path"
methodOverride = require "method-override"
bodyParser     = require "body-parser"
socketio       = require "socket.io"
ioClient       = require "socket.io-client"
errorHandler   = require "error-handler"
SoxCommand     = require "sox-audio"

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

# express application routes
app
  .get "/", (req, res, next) ->
    res.render "main"

subCommand = (file) ->
  return SoxCommand()
    .input(file)
    .output('-p')
    .outputFileType('mp3')

# TODO check file integrity
downloadFile = (service) ->
  filename = "#{service.name}-#{service.port}.mp3"
  return (callback) ->
    request "http://localhost:#{service.port}/audio.mp3"
      .pipe fs.createWriteStream(filename).on "close", () ->
        # callback for async, when all tasks finish we'll have an array of
        # filenames
        callback(null, "./#{filename}")

# a client is requesting an audio file
app
  .get "/audiostream.mp3", (req, response) ->
    response.set
      'Content-Type': 'audio/mpeg3'
      'Transfer-Encoding': 'chunked'
    # ask the service registry for the locations of all audio-generators
    request "#{servRegAddress}/getInstancesByServiceName/audio-generator",
      (err, res, body) ->
        # do some error checking
        if(err)
          console.log err
          return
        # the service registry returns an array of objects
        services = JSON.parse body
        if(services.err)
          console.log services.err
          return
        # for each connected audio generator download a file over http
        async.parallel \
          # return an array of functions
          (services.map (s) -> return downloadFile(s)), \
          # results holds an array of results from the callbacks
          (err, results) ->
            combineAudio results, response

combineAudio = (files, outputStream) ->
  soxCommand = SoxCommand()

  for file in files
    soxCommand.inputSubCommand \
      SoxCommand(file).inputFileType("mp3").output("-p")
  soxCommand.output(outputStream)
  soxCommand.outputFileType('mp3')
  soxCommand.outputChannels(1)
  soxCommand.combine('merge')

  soxCommand.on "prepare", (args) ->
    console.log "preparing with #{args.join ' '}"

  soxCommand.on "start", (cmdline) ->
    console.log "spawned sox with cmd: #{cmdline}"

  soxCommand.on "error", (err, stdout, stderr) ->
    console.log "cannot process audio #{err.message}"
    console.log "sox command stdout #{stdout}"
    console.log "sox command stderr #{stderr}"

  soxCommand.run()

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

instances = []
# when a new service we are subscribed to starts, connect to it
serviceRegistry.on "service-up", (service) ->
  switch service.name
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

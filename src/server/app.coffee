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
mongoose 			 = require "mongoose"

log       = require "./lib/log"

SharedData = require "./models/shared-data-model"
app       = express()
server    = http.createServer app
io        = socketio.listen server
host  = "http://localhost"
mongoAddress = "mongodb://localhost:27017/Services"
generator = null

# init DB
db = mongoose.connection
db.on 'connecting', ->
	log.info "connecting to mongodb"
db.on 'error', ->
	log.info "error connecting to mongodb"
db.on 'disconnected', ->
	log.info "disconnected from mongodb"
	setTimeout ->
		mongoose.connect mongoAddress, { server: { auto_reconnect: true } }
	, 5000


# TODO We need to get the data from the person-generator service
# So we need to connect to it in some way
# But we dont know on which port
#
# ########################
# ### SERVICE REGISTRY ###
# ########################
# Keep track of services and ports in mongodb
# Text file somewhere lolz
# etc. Basically a global variable somewhere, which all services have access to
#
# We could do some unixy thing maybe with netstat? meh...
# Scan ports? meh too slow
#
# If one entity has a fixed port we could always connect to that
#
# Maybe some kind of fallback mechanism?
# I would like to to eliminate single points of failure
#
# Firstly lets just seperate these two services DONE
# We'll connect to the person generator on a static port 3002 DONE
# So we can pipe that data to the connected clients DONE

# collection of client sockets
sockets = []

# connect to generator service

getGenerator = (port) ->
	address = "#{host}:#{port}"
	log.info "connecting to generator at #{address}"
	# We have the port, try to connect
	return ioClient.connect address,
		"reconnection":       false
		"reconnection delay": 2000

retry = ->
	setTimeout ->
		connectToGenerator()
	, 5000

connectToGenerator = ->
	SharedData.findOne { service: "person-generator"}, (err, data) ->
		# check for errors
		if(err)
			log.info "Error", err
			retry()
		if(!data)
			log.info "Error: no data"
			retry()
		generator = getGenerator data.port

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
mongoose.connect mongoAddress, { server: { auto_reconnect: true } }
connectToGenerator()
server.listen 3000
log.info "Listening on 3000"

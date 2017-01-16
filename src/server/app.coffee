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

log       = require "./lib/log"

app       = express()
server    = http.createServer app
io        = socketio.listen server
address  = "http://localhost:3002" # TODO a way to find the port
generator = ioClient.connect "#{address}",
	"reconnect":          true
	"reconnection delay": 2000

# TODO We need to get the data from the person-generator service
# So we need to connect to it in some way
# But we dont know on which port
#
# We could use an entry in a shared database
# We could use a text file somewhere
# etc. Basically a global variable somewhere, which both services have access to
#
# We could do some unixy thing maybe with netstat? meh...
# Scan ports?
#
# Firstly lets just seperate these two services DONE
# We'll connect to the person generator on a static port 3002 DONE
# So we can pipe that data to the connected clients DONE

# collection of client sockets
sockets = []

# connect to generator service
console.log "connecting to #{address}"

generator.on "connect", (socket) ->
	console.log "connected to generator"
	generator.on "dataGenerated", (data) ->
		socket.emit "persons:create", data for socket in sockets
	
# connection lost, remove listener, we'll get double data otherwise
generator.on "disconnect", ->
	console.log "disconnected from generator"
	generator.removeListener "dataGenerated"

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
	.get "/", (req, res, next) =>
		res.render "main"

# start the server
server.listen 3000
log.info "Listening on 3000"

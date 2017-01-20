fs         = require "fs"
express    = require "express"
async      = require "async"
request    = require "request"
router     = express.Router()

audio   = require "../lib/audio"

# fixed location of service registry
servRegAddress = "http://localhost:3001"

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
router.get "/audiostream.mp3", (req, response) ->
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
          # create a combined audio file and send it to the client
          audio.combine results, response

module.exports = router

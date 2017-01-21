fs         = require "fs"
SoxCommand = require "sox-audio"

audio = {}

audio.combine = (files, outputStream) ->
  # check valid input
  if(!files || files.length == 0 || !Array.isArray files)
    console.error "not enough files for SoxCommand"
    return outputStream.json(files: files)

  soxCommand = SoxCommand()
  # input a list of files to be combined
  for file in files
    soxCommand.inputSubCommand \
      SoxCommand(file) \
        .inputFileType("mp3") \
        .output("-p")
  # do not save the file, directly stream to client
  soxCommand.output(outputStream)
  soxCommand.outputFileType('mp3')
  soxCommand.outputChannels(2)
  # only combine if we have multiple files
  if(files.length > 1)
    soxCommand.combine('merge')
    soxCommand.addEffect("gain", "-n") # normalize
    soxCommand.addEffect("gain", 6) # increase gain. combining lowers volume?

  # set some logging
  soxCommand.on "start", (cmdline) ->
    console.log "spawned sox with cmd: #{cmdline}"
  soxCommand.on "error", (err, stdout, stderr) ->
    console.log "cannot process audio #{err.message}"
    console.log "sox command stdout #{stdout}"
    console.log "sox command stderr #{stderr}"
    outputStream.json(err: err) # tell the client we messed up : (

  # all done, delete all files
  soxCommand.on "end", () ->
    for file in files
      fs.unlink file, (err) ->

  # run it!
  soxCommand.run()

module.exports = audio

{ Duplex }  = require "stream"

class PullDuplex extends Duplex
  constructor: (options = {}) ->
    super objectMode: true
    @on "pipe", (src) ->
      console.log "PullDuplex pipe"
    @on "unpipe", (src) ->
      console.log "PullDuplex unpipe"
    @on "drain", () ->
      console.log "PullDuplex drain"
    # holds our callback when read buffer is full.
    # gets called again on first _read
    @callbacks = []

  _write: (object, encoding, cb) ->
    # the piped in readable stream called write() on us passing in `object`
    # transform object so we can log buffer sizes
    object.wBuf = @_writableState.getBuffer.length
    object.rBuf = @_readableState.buffer.length
    # call @push with object to add object to the buffer and
    # ask our readable stream if hwm is hit yet
    if @push object
      # HWM is not hit yet, process chunk
      cb()
    else
      # HWM hit store callback
      @callbacks.push cb

  _read: (size) ->
    # .shift() removes and returns first elemement from array
    # we then immediately call it. Noice!
    @callbacks.shift()() while @callbacks.length

module.exports = PullDuplex

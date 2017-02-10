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

  log: =>
    console.log "writable buffer", @_writableState.getBuffer().length
    console.log "readable buffer", @_readableState.buffer.length
    console.log "callbacks      ", @callbacks
    console.log ""

  _write: (object, encoding, cb) ->
    # the piped in readable stream called write() on us passing in `object`
    # transform object so we can log buffer sizes
    console.log object
    # call @push with object to add object to the buffer and
    # ask our readable stream if hwm is hit yet
    if @push object
      # HWM is not hit yet,    process chunk
      cb()
    else
      # HWM hit,               store callback
      @callbacks.push cb

  _read: (size) ->
    # .shift() removes and returns first elemement from array
    # we then immediately call it. Noice!
    @callbacks.shift()() while @callbacks.length

module.exports = PullDuplex

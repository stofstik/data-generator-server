{ Duplex }  = require "stream"

class PullDuplex extends Duplex
  constructor: (options = {}) ->
    super objectMode: true
    @on "pipe", (src) ->
      console.log "PullDuplex pipe"
    @on "end", () ->
      console.log "PullDuplex end"
    @on "close", () ->
      console.log "PullDuplex close"
    @on "drain", () ->
      console.log "PullDuplex drain"
    @on "error", () ->
      console.log "PullDuplex error"
    @on "finish", () ->
      console.log "PullDuplex finish"
    @on "unpipe", (src) ->
      console.log "PullDuplex unpipe"

    @callbacks = []

  _write: (object, encoding, cb) ->
    object.wBuf = @_writableState.getBuffer.length
    object.rBuf = @_readableState.buffer.length
    if @push object
      cb()
    else
      @callbacks.push cb

  _read: (size) ->
    # shift removes and returns first elem from array, then immediately call it
    @callbacks.shift()() while @callbacks.length

module.exports = PullDuplex

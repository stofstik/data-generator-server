class StreamBufferLogger
  constructor: () ->
    @interval = null
    @streams = []

  start: ->
    @stop()
    @interval = setInterval @log, 1000

  stop: ->
    clearInterval @interval if @interval

  push: (stream, name) ->
    unless stream._readableState
      console.log "not a stream..."
      return
    stream.name = name
    @streams.push stream

  splice: (stream) ->
    @streams.splice indexOf stream, 1

  log: =>
    console.log new Date
    @streams.map (s, i) ->
      if s.name
        console.log "stream #{s.name}:"
      else
        console.log "stream #{i}:"
      if s._readableState
        console.log "R", s._readableState.buffer.length

      if s._writableState.getBuffer
        console.log "W", s._writableState.getBuffer().length
      else
        console.log "W", s._writableState.buffer.length

module.exports = StreamBufferLogger

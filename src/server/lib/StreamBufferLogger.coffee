class StreamBufferLogger
  constructor: () ->
    @interval = null
    @streams = []

  start: ->
    @stop
    @interval = setInterval @log, 1000

  stop: ->
    clearInterval @interval if @interval

  addStream: (stream) ->
    @streams.push stream

  removeStream: (stream) ->
    @streams.splice indexOf stream, 1

  log: ->
    @streams.map (s) ->
      console.log s._readableState.buffer.length
      if s._writableState.getBuffer()
        console.log s._writableState.getBuffer().length
      else
        console.log s._writableState.buffer.length

module.exports = StreamBufferLogger

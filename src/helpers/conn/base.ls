EventEmitter = require \events

##
# Base driver class for all possible connections, such as Serial, Tcp, and Websocket.
#
class BaseDriver extends EventEmitter
  (pino, @id, @name, @uri, @tokens) ->
    self = @
    self.logger = logger = pino.child {messageKey: "TcpDriver##{id}"}
    self.logger.debug "#{name}:config => #{JSON.stringify tokens}"
    self.cb = null

  set_data_cb: (@cb) ->
    return

  on_data: (chunk) ->
    return @cb chunk if @cb?

  on_error: (err) ->
    @logger.info "err => #{err}"
    @logger.error err

  start: (done) ->
    return done!

  ##
  # Write a chunk of bytes as data to remote.
  #
  write: (chunk) ->
    return



module.exports = exports = {BaseDriver}

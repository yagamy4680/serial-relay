EventEmitter = require \events

const TIMER_EXPIRY = 1000ms
const CONNECTION_TIMER = 2s


##
# Base driver class for all possible connections, such as Serial, Tcp, and Websocket.
#
class BaseDriver extends EventEmitter
  (pino, @id, @name, @uri, @tokens) ->
    {className} = self = @
    self.logger = logger = pino.child {messageKey: "#{className}##{id}"}
    self.logger.debug "#{name}:config => #{JSON.stringify tokens}"
    self.cb = null
    self.started = no
    self.connected = no
    self.connecting = no
    self.connection_counter = CONNECTION_TIMER
    f = -> return self.at_timeout!
    self.timer = setInterval f, TIMER_EXPIRY

  set_data_cb: (@cb) ->
    return

  at_timeout: ->
    {logger, name, started, connected, connecting, connection_counter} = self = @
    return logger.info "<#{name}>: not started yet ..." unless started
    return if connected
    return logger.info "<#{name}>: connecting to #{self.uri.yellow} ... (connected: #{connected}, connecting: #{connecting}, connection_counter: #{connection_counter})" if connecting
    self.connection_counter = connection_counter - 1
    return if self.connection_counter > 0
    self.connection_counter = CONNECTION_TIMER
    self.connecting = yes
    return self.connect_internally!

  on_data: (chunk) ->
    return @cb chunk if @cb?

  start: (done) ->
    @started = yes
    @connecting = yes
    @.connect_internally!
    return done!

  write: (chunk) ->
    return unless @connected
    return @.write_internally chunk

  ##
  # Write a chunk of bytes as data to remote. Subclass of the BaseDriver
  # needs to overwrite this function.
  #
  write_internally: (chunk) ->
    return

  ##
  # Establish a connection to the target. Subclass of the BaseDriver
  # needs to overwrite this function. 
  #
  connect_internally: ->
    return

  on_connected: ->
    @connected = yes
    @connecting = no
    @connection_counter = CONNECTION_TIMER
  
  on_disconnected: ->
    @connected = no
    @connecting = no
    @connection_counter = CONNECTION_TIMER


module.exports = exports = {BaseDriver}

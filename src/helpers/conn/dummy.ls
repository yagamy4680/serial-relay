EventEmitter = require \events
require! <[net]>
{BaseDriver} = require \./base

##
# Startup a DummyClient with nothing!!
#
module.exports = exports = class TcpDriver extends BaseDriver
  (pino, @id, @name, @uri, @tokens) ->
    self = @
    self.className = "DummyDriver"
    super ...

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
    return @.on_connected!

  on_error: (err) ->
    {logger, name} = self = @
    logger.info "<#{name}>: at_error(err) => #{err}"
    logger.error err
  
  on_close: (err=null) ->
    {logger, name} = self = @
    logger.info "<#{name}>: at_close()"
    self.clean_and_reset!

  clean_and_reset: ->
    return @.on_disconnected!
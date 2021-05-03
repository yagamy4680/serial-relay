EventEmitter = require \events
SerialPort = require \serialport
Readline = require \@serialport/parser-readline
{BaseDriver} = require \./base

##
# Startup a Serial server with given config string (similar to socat):
#
# e.g. The full url `serial:///dev/tty.usbmodem123456781?settings=b115200,8,N,1&name=MPU` is composed of 
#      following fields:
#         name = MPU
#         pathname = /dev/tty.usbmodem123456781
#         qs = {
#            settings: 'b115200:8:N:1'
#            }
#
module.exports = exports = class SerialDriver extends BaseDriver
  (pino, @id, @name, @uri, @tokens) ->
    self = @
    self.className = "SerialDriver"
    super ...
    {pathname, qs} = tokens
    {settings} = qs
    [baudRate, dataBits, parity, stopBits] = xs = settings.split ','
    throw new Error "missing pathname in the given url: #{uri}" unless pathname?
    baudRate = 'b115200' unless baudRate? and \string is typeof baudRate
    throw new Error "incorrect baudrate setting: #{baudRate}" unless baudRate[0] is \b
    baudRate = parseInt baudRate.substring 1
    dataBits = '8' unless dataBits? and \string is typeof dataBits
    dataBits = parseInt dataBits
    parity = 'N' unless parity? and \string is typeof parity
    parity = 'none' if parity is \N
    stopBits = '1' unless stopBits? and \string is typeof stopBits
    stopBits = parseInt stopBits
    autoOpen = no
    self.readline = no
    self.readline = yes if qs.parser? and qs.parser is "readline"
    self.packetFilter = null
    self.pathname = filePath = pathname
    self.opts = opts = {autoOpen, baudRate, dataBits, parity, stopBits}
    self.configs = configs = {filePath, baudRate, parity, stopBits, dataBits}

  ##
  # Write a chunk of bytes as data to remote. Subclass of the BaseDriver
  # needs to overwrite this function.
  #
  write_internally: (chunk) ->
    return @p.write chunk

  ##
  # Establish a connection to the target. Subclass of the BaseDriver
  # needs to overwrite this function. 
  #
  connect_internally: ->
    {logger, name, configs, opts, pathname, readline} = self = @
    logger.info "<#{name}>: opening #{pathname.yellow} with options: #{(JSON.stringify opts).yellow} ..."
    p = self.p = new SerialPort pathname, opts
    if readline
      logger.info "<#{name}>: parser: ReadLine"
      pp = self.pp = p.pipe new Readline delimiter: '\r\n'
      pp.on \data, (data) -> return self.on_data data
    else
      pp = self.pp = null
      p.on \data, (data) -> return self.on_data data
    p.on \error, (err) -> return self.on_error err
    p.on \close, (err) -> return self.on_close err
    (err) <- p.open
    if err?
      logger.info "<#{name}>: open but error => #{err}"
      logger.error err
      return self.clean_and_reset!
    else
      logger.info "<#{name}>: connected."
      self.on_connected!

  on_error: (err) ->
    {logger, name} = self = @
    logger.info "<#{name}>: at_error(err) => #{err}"
    logger.error err
  
  on_close: (err=null) ->
    {logger, name} = self = @
    logger.info "<#{name}>: at_close(err) => #{err}"
    logger.error err if err?
    self.clean_and_reset!

  clean_and_reset: ->
    {p, pp} = self = @
    p.removeAllListeners \error
    p.removeAllListeners \data
    p.removeAllListeners \close
    pp.removeAllListeners \data if pp?
    self.pp = null if pp?
    self.p = null
    self.on_disconnected!


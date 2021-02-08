EventEmitter = require \events
SerialPort = require \serialport
require! <[byline through2]>

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
module.exports = exports = class SerialDriver extends EventEmitter
  (pino, @id, @name, @uri, @tokens) ->
    self = @
    {pathname, qs} = tokens
    {settings} = qs
    pino.debug JSON.stringify {id, name, pathname, qs}
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
    self.packetFilter = null
    self.connected = no
    self.pathname = filePath = pathname
    self.opts = opts = {autoOpen, baudRate, dataBits, parity, stopBits}
    self.configs = configs = {filePath, baudRate, parity, stopBits, dataBits}
    self.logger = logger = pino.child {messageKey: "SerialDriver##{id}"}
    logger.info "configs => #{JSON.stringify configs}"
    p = @p = new SerialPort filePath, opts
    p.on \error, (err) -> return self.on_error err
    p.on \data, (data) -> return self.on_data data

  set_data_cb: (@cb) ->
    return

  start: (done) ->
    {connected, pathname, opts, p, logger} = self = @
    return if connected
    logger.info "opening #{pathname.yellow} with options: #{(JSON.stringify opts).yellow} ..."
    (err) <- p.open
    return done err if err?
    self.connected = yes
    logger.debug "opened"
    return done!

  write: (chunk) ->
    return @p.write chunk

  on_data: (chunk) ->
    return @cb chunk if @cb?

  on_error: (err) ->
    @logger.info "err => #{err}"
    @logger.error err

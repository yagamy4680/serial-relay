EventEmitter = require \events
SerialPort = require \serialport
require! <[byline through2]>

##
# Startup a Serial server with given config string (similar to socat):
# e.g.
#       /dev/tty.usbmodem123456781:b115200:8:N:1
#
module.exports = exports = class SerialDriver extends EventEmitter
  (pino, @id, @configString) ->
    self = @
    self.packetFilter = null
    [c, name] = configString.split ':' 
    console.log JSON.stringify {c, name}
    throw new Error "missing name for SerialDriver => #{configString}" unless \string is typeof name
    [filePath, baudRate, dataBits, parity, stopBits] = xs = c.split ','
    throw new Error "missing filepath for serial drive => #{configString}" unless \string is typeof filePath
    baudRate = 'b115200' unless baudRate? and \string is typeof baudRate
    throw new Error "incorrect baudrate setting: #{baudRate}" unless baudRate[0] is \b
    baudRate = parseInt baudRate.substring 1
    dataBits = '8' unless dataBits? and \string is typeof dataBits
    dataBits = parseInt dataBits
    parity = 'N' unless parity? and \string is typeof parity
    parity = 'none' if parity is \N
    stopBits = '1' unless stopBits? and \string is typeof stopBits
    stopBits = parseInt stopBits
    self.configs = configs = {filePath, baudRate, parity, stopBits, dataBits}
    self.logger = logger = pino.child {messageKey: "SerialDriver##{id}"}
    logger.info "configs => #{JSON.stringify configs}"
    autoOpen = no
    connected = no
    self.name = name
    self.filePath = filePath
    self.opts = opts = {autoOpen, baudRate, dataBits, parity, stopBits}
    p = @p = new SerialPort filePath, opts
    p.on \error, (err) -> return self.on_error err
    p.on \data, (data) -> return self.on_data data

  set_peer_and_filter: (@peer, @packetFilter) ->
    return

  start: (done) ->
    {connected, filePath, opts, p, logger} = self = @
    return if connected
    logger.info "opening #{filePath.yellow} with options: #{(JSON.stringify opts).yellow} ..."
    (err) <- p.open
    return done err if err?
    self.connected = yes
    logger.debug "opened"
    return done!

  write: (chunk) ->
    return @p.write chunk

  on_data: (chunk) ->
    {peer, packetFilter, logger} = self = @
    return unless peer? or packetFilter?
    filtered = chunk
    filtered = (packetFilter self, chunk) if packetFilter? and \function is typeof packetFilter
    return unless filtered?
    return unless peer?
    return peer.write filtered

  on_error: (err) ->
    console.log "err => #{err}"
    @.logger.error err

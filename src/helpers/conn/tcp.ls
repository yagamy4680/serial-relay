EventEmitter = require \events
require! <[net]>
{BaseDriver} = require \./base

##
# Startup a TcpClient with given config string (similar to socat):
#
# e.g. The full url `tcp://10.42.0.213:9090?name=EPC` is composed of 
#      following fields:
#         name = EPC
#         pathname = 
#         qs = {
#            settings: 'b115200:8:N:1'
#            }
#
module.exports = exports = class TcpDriver extends BaseDriver
  (pino, @id, @name, @uri, @tokens) ->
    super ...
    self = @
    {hostname, port, host} = tokens
    port = \2020 unless port?
    port = parseInt port
    self.packetFilter = null
    self.connected = no
    self.hostname = hostname
    self.port = port
    self.host = "#{hostname}:#{port}"
    self.logger.debug JSON.stringify {id, name, hostname, port, uri}
    tcp = self.tcp = new net.Socket!
    tcp.on \error, (err) -> return self.on_error err
    tcp.on \data, (data) -> return self.on_data data

  start: (done) ->
    {connected, tcp, logger, port, hostname} = self = @
    return if connected
    logger.info "connecting to #{hostname.yellow} with port #{port} ..."
    <- tcp.connect port, hostname
    self.connected = yes
    logger.debug "connected"
    return done!

  write: (chunk) ->
    return @tcp.write chunk
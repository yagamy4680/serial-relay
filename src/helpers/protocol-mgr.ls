EventEmitter = require \events
require! <[fs path colors]>
TcpMonitor = require \./tcp-monitor
WebServer = require \./web

const COLORS =
  bytes:
    s2p: \green
    p2d: \brightGreen
    d2p: \cyan
    p2s: \brightCyan
  ascii:
    s2p: \white
    p2d: \white
    d2p: \white
    p2s: \white

const DUMP_BYTE_LENGTH = 15
const ZEROS = [ ((['--']*i).join ' ') for i from 0 to (DUMP_BYTE_LENGTH - 1) ]
const SPACES = [ (([' ']*i).join '' ) for i from 0 to (DUMP_BYTE_LENGTH - 1) ]




COLORIZE = (str, lv1, lv2) ->
  name = COLORS[lv1][lv2]
  func = colors[name]
  return func.apply colors, [str]


# Inspired by https://stackoverflow.com/questions/8495687/split-array-into-chunks
#
BULKIZE = (list, size) ->
  return [] if list.length is 0
  const head = list.slice 0, size
  const tail = list.slice size
  return [head] ++ (BULKIZE tail, size)


HEXIZE = (b) ->
  return "0#{(b.toString 16).toUpperCase!}" if b < 16
  return (b.toString 16).toUpperCase!


ASCIIZE = (b) ->
  return '.' unless (b >= 0x20) and (b <= 0x7F)
  return String.fromCharCode b



class DummyProtocol extends EventEmitter
  (@parent, @pino, @src_name, @dst_name) ->
    return
  
  start: (done) ->
    return done!

  process_src_bytes: (chunk) ->
    @.emit \from_src_filtered, chunk
    return null

  process_dst_bytes: (chunk) ->
    @.emit \from_dst_filtered, chunk
    return null



class WebsocketProtocol extends DummyProtocol
  (@parent, @pino, @src_name, @dst_name) ->
    self = @
    self.ws = null
    self.ws_event = \protocol
    self.ws_disconnect_func = null
    self.ws_protocol_func = null
    return
  
  start: (done) ->
    return done!

  init_remote: (@ws, configs={}) ->
    {ws_event} = self = @
    self.parent.logger.info "incoming a socket.io connection as protocol instance..."
    self.ws_disconnect_func = -> return self.at_ws_disconnect!
    self.ws_protocol_func = (direction, chunk) -> return self.process_remote_bytes direction, chunk
    ws.on \disconnect, self.ws_disconnect_func
    ws.on ws_event, self.ws_protocol_func

  at_ws_disconnect: ->
    {ws, ws_event, ws_protocol_func, ws_disconnect_func} = self = @
    ws.removeListener \disconnect, ws_disconnect_func
    ws.removeListener ws_event, ws_protocol_func
    self.ws_disconnect_func = null
    self.ws_protocol_func = null
    self.ws = null

  send_ws_packet: (direction, chunk) ->
    {ws_event, ws} = self = @
    setImmediate -> ws.send_packet ws_event, direction, chunk
    return null

  process_src_bytes: (chunk) ->
    return @.emit \from_src_filtered, chunk unless @ws?
    # console.log "process_src_bytes, sending #{chunk.length} bytes to remote socket.io client"
    return @.send_ws_packet \s2p, chunk

  process_dst_bytes: (chunk) ->
    return @.emit \from_dst_filtered, chunk unless @ws?
    # console.log "process_dst_bytes, sending #{chunk.length} bytes to remote socket.io client"
    return @.send_ws_packet \d2p, chunk
  
  process_remote_bytes: (direction, chunk) ->
    return @.emit \from_src_filtered, chunk if direction is \p2d
    return @.emit \from_dst_filtered, chunk if direction is \p2s


##
# Given 2 serial drivers (src and dst), the Protocol instance plays the 
# man in the middle to filter & manipulate protocol packets. 
#
# ProtocolManager is responsible for:
#   - initiate protocol instance
#   - create default protocol instance, in case protocol class doesn't exist => DummyProtocol
#   - listen to `from_src_filtered` event of Protocol instance, and bypass the received chunk of bytes to `dst`
#   - listen to `from_dst_filtered` event of Protocol instance, and bypass the received chunk of bytes to `src`
#
#           S2P        P2D
#     src --[1]--> p --[3]--> dst
#     dst --[2]--> p --[4]--> src
#           D2P        P2S
#
class ProtocolManager 
  (@pino, @ProtocolClass, @relayDir, @src, @dst, @portTcp, @portWeb, directions='p2d,p2s') ->
    self = @
    self.logger = logger = pino.child {messageKey: "ProtocolManager"}
    self.monitor = new TcpMonitor pino, portTcp
    self.web = w = new WebServer  pino, portWeb, "#{relayDir}#{path.sep}web"
    self.p = p = new ProtocolClass self, pino, src.name, dst.name
    self.monitor_traffic_filters = directions.split ','
    self.direction_dumps = direction_dumps = {}
    direction_dumps['s2p'] = "#{src.name}#{COLORIZE '-->', 'bytes', 's2p'}p-->#{dst.name}"
    direction_dumps['p2s'] = "#{src.name}#{COLORIZE '<--', 'bytes', 'p2s'}p<--#{dst.name}"
    direction_dumps['p2d'] = "#{src.name}-->p#{COLORIZE '-->', 'bytes', 'p2d'}#{dst.name}"
    direction_dumps['d2p'] = "#{src.name}<--p#{COLORIZE '<--', 'bytes', 'p2d'}#{dst.name}"
    logger.info "directions => #{JSON.stringify self.monitor_traffic_filters}"
    w.on \init_remote_protocol, (c, configs) -> return self.init_remote_protocol c, configs
    return
  
  start: (done) ->
    {logger, src, dst, monitor, web, p} = self = @
    p.on \from_src_filtered, (chunk, annotation=null, verbose=no) -> return self.process_p2d chunk, annotation, verbose
    p.on \from_dst_filtered, (chunk, annotation=null, verbose=no) -> return self.process_p2s chunk, annotation, verbose
    src.set_data_cb (chunk) -> return self.process_s2p chunk
    dst.set_data_cb (chunk) -> return self.process_d2p chunk
    (merr) <- monitor.start
    return done merr if merr?
    (werr) <- web.start
    return done werr if werr?
    (perr) <- p.start
    return done perr if perr?
    (derr) <- dst.start
    return done derr if derr?
    (serr) <- src.start
    return done serr if serr?
    logger.info "successfully initiate protocol, dst(#{dst.name}), and src(#{src.name})"
    return done!

  println: (line) ->
    console.log line
    text = "#{line}\n"
    @monitor.broadcast text
    @web.broadcastText "console", text

  bulk2text: (now, direction, bulk) ->
    {direction_dumps} = self = @
    len = bulk.length
    xs = [ (HEXIZE b) for b in bulk ]
    xt = xs.join ' '
    xt = "#{xt} #{ZEROS[DUMP_BYTE_LENGTH - len]}" if len < DUMP_BYTE_LENGTH
    xt = COLORIZE xt, \bytes, direction
    ys = [ (ASCIIZE b) for b in bulk ]
    yt = ys.join ''
    yt = "#{yt}#{SPACES[DUMP_BYTE_LENGTH - len]}" if len < DUMP_BYTE_LENGTH
    yt = COLORIZE yt, \ascii, direction
    d = direction_dumps[direction]
    return "#{now} #{d} | #{xt} | #{yt} !"

  dump_chunk: (direction, chunk, annotation, verbose) ->
    {monitor_traffic_filters, monitor} = self = @
    return unless verbose or (direction in monitor_traffic_filters)
    now = (new Date!).toISOString!
    xs = [ c for c in chunk ]
    bulks = BULKIZE xs, DUMP_BYTE_LENGTH
    xs = [ (self.bulk2text now, direction, c) for c in bulks ]
    xs[0] = "#{xs[0]} <== #{COLORIZE annotation, \bytes, direction}" if annotation?
    self.println "#{xs.join '\n'}\n"

  process_s2p: (chunk, annotation=null, verbose=no) -> # src -> protocol
    @.dump_chunk \s2p, chunk, annotation, verbose
    return @p.process_src_bytes chunk

  process_d2p: (chunk, annotation=null, verbose=no) -> # dst -> protocol
    @.dump_chunk \d2p, chunk, annotation, verbose
    return @p.process_dst_bytes chunk
  
  process_p2d: (chunk, annotation=null, verbose=no) -> # protocol -> dst
    @.dump_chunk \p2d, chunk, annotation, verbose
    return @dst.write chunk

  process_p2s: (chunk, annotation=null, verbose=no) -> # protocol -> dst
    @.dump_chunk \p2s, chunk, annotation, verbose
    return @src.write chunk

  init_remote_protocol: (ws, configs) ->
    return @p.init_remote ws, configs


module.exports = exports = (pino, assetDir, src, dst, monitor, directions) -> 
  pino.info "assetDir = #{assetDir}"
  relayDir = null
  if assetDir?
    relayDir = "#{assetDir}#{path.sep}.relay"
    try
      classPath = "#{relayDir}#{path.sep}protocol"
      ProtocolClass = require classPath
    catch
      pino.error e, "no such protocol instance: #{classPath.yellow}, due to the error #{e.name}"
      pino.info "fallback to DummyProtocol"
      ProtocolClass = DummyProtocol
  else
    ProtocolClass = WebsocketProtocol
    pino.info "use WebsocketProtocol as supervisor."

  pm = new ProtocolManager pino, ProtocolClass, relayDir, src, dst, monitor, directions
  return pm

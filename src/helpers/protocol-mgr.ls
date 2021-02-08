EventEmitter = require \events
require! <[fs path colors]>

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
  (@pino, @ProtocolClass, @assetDir, @src, @dst, @monitor, directions='p2d,p2s') ->
    self = @
    self.logger = logger = pino.child {messageKey: "ProtocolManager"}
    self.p = p = new ProtocolClass self, pino, src.name, dst.name
    self.monitor_traffic_filters = directions.split ','
    self.direction_dumps = direction_dumps = {}
    direction_dumps['s2p'] = "#{src.name}#{COLORIZE '-->', 'bytes', 's2p'}p-->#{dst.name}"
    direction_dumps['p2s'] = "#{src.name}#{COLORIZE '<--', 'bytes', 'p2s'}p<--#{dst.name}"
    direction_dumps['p2d'] = "#{src.name}-->p#{COLORIZE '-->', 'bytes', 'p2d'}#{dst.name}"
    direction_dumps['d2p'] = "#{src.name}<--p#{COLORIZE '<--', 'bytes', 'p2d'}#{dst.name}"
    logger.info "directions => #{JSON.stringify self.monitor_traffic_filters}"
    return
  
  start: (done) ->
    {logger, src, dst, monitor, p} = self = @
    p.on \from_src_filtered, (chunk, annotation=null, verbose=no) -> return self.process_p2d chunk, annotation, verbose
    p.on \from_dst_filtered, (chunk, annotation=null, verbose=no) -> return self.process_p2s chunk, annotation, verbose
    src.set_data_cb (chunk) -> return self.process_s2p chunk
    dst.set_data_cb (chunk) -> return self.process_d2p chunk
    (merr) <- monitor.start
    return done merr if merr?
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
    return @monitor.broadcast "#{line}\n"

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


module.exports = exports = (pino, assetDir, src, dst, monitor, directions) -> 
  try
    ProtocolClass = require "#{assetDir}/.relay/protocol"
  catch
    pino.error e, "no such protocol instance: #{assetDir}/.relay/protocol, due to the error #{e.name}"
    ProtocolClass = DummyProtocol

  pm = new ProtocolManager pino, ProtocolClass, assetDir, src, dst, monitor, directions
  return pm

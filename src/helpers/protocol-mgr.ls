EventEmitter = require \events
require! <[fs path]>


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
class ProtocolManager 
  (@pino, @ProtocolClass, @assetDir, @src, @dst) ->
    self = @
    logger = self.logger = pino.child {messageKey: "ProtocolManager"}
    p = self.p = new ProtocolClass self, pino, src.name, dst.name
    return
  
  start: (done) ->
    {logger, src, dst, p} = self = @
    p.on \from_src_filtered, (chunk) -> return dst.write chunk
    p.on \from_dst_filtered, (chunk) -> return src.write chunk
    src.set_peer_and_filter dst, (peer, chunk) -> return p.process_src_bytes chunk
    dst.set_peer_and_filter src, (peer, chunk) -> return p.process_dst_bytes chunk
    (serr) <- src.start
    return done serr if serr?
    (serr) <- dst.start
    return done serr if serr?
    (perr) <- p.start
    return done perr if perr?
    logger.info "successfully initiate src, dst, and p"
    return done!
    


module.exports = exports = (pino, assetDir, src, dst) -> 
  try
    ProtocolClass = require "#{assetDir}/.relay/protocol"
  catch
    pino.error "no such protocol instance: #{assetDir}/.relay/protocol"
    ProtocolClass = DummyProtocol

  pm = new ProtocolManager pino, ProtocolClass, assetDir, src, dst
  return pm


EventEmitter = require \events
SocketIo = require \socket.io
require! <[express http path lodash]>


class ConnectionHandler extends EventEmitter
  (@parent, @c) ->
    self = @
    {filepath, serialOpts} = parent
    @logger = parent.logger
    @logger.info "incoming socket.io connection ..."
    c.on \disconnect, -> return self.on_disconnect!
    c.on \config, (configs) -> return self.on_config configs
    c.on \protocol, (direction, chunk) -> return self.emit \protocol, direction, chunk

  write: (evt=\data, chunk=[]) ->
    return @c.emit evt, chunk
  
  send_packet: (evt, direction, chunk) ->
    return @c.emit evt, direction, chunk
  
  on_disconnect: ->
    @.emit \disconnect
    return @parent.remove_connection @

  on_config: (configs) ->
    return @parent.initiate_remote_protocol @, configs
  

module.exports = exports = class WebServer extends EventEmitter
  (pino, @port, @assetDir, @middlewares) ->
    self = @
    self.connections = []
    self.assetDir = path.resolve self.assetDir
    self.callbacks = {}
    logger = @logger = pino.child {messageKey: 'WebServer'}
    logger.info "assetDir => #{self.assetDir}"
    app = @app = express!
    app.use '/', express.static self.assetDir, {index: <[index.html index.htm]>}
    api = express!
    p = express!
    for k, v of middlewares
      p.use "/#{k}", v
      logger.info "register web middleware /api/p/#{k} => #{typeof v}"
    api.use '/p', p
    app.use '/api', api
    server = @server = http.createServer app
    io = @io = SocketIo server
    channel = @channel = io.of '/relay'
    channel.on 'connection', (c) -> return self.incoming_connection c

  set_api_callback: (name, func) ->
    @callbacks[name] = func

  start: (done) ->
    {server, port, logger, assetDir} = self = @
    logger.debug "starting web server ..."
    (err) <- server.listen port
    return done err if err?
    logger.info "listening port #{port}"
    return done!

  incoming_connection: (c) ->
    {connections} = self = @
    h = new ConnectionHandler self, c
    return connections.push h

  remove_connection: (h) ->
    {connections, prefix, logger} = self = @
    {remote} = h
    idx = lodash.findIndex connections, h
    logger.warn "disconnected, and removed from slots[#{idx}]"
    return connections.splice idx, 1 if idx?

  broadcast: (evt, chunk) ->
    {connections} = self = @
    [ (c.write evt, chunk) for c in connections ]

  broadcastText: (evt, text) ->
    chunk = Buffer.from text
    return @broadcast evt, chunk

  initiate_remote_protocol: (c, configs) ->
    {logger} = self = @
    {name} = configs
    setImmediate -> self.emit 'init_remote_protocol', c, configs
    return logger.info "initiate_remote_protocol ...: #{path.basename name} => #{JSON.stringify configs}"

require! <[url querystring]>
DummyDriver = require \./conn/dummy
SerialDriver = require \./conn/serial
TcpDriver = require \./conn/tcp

const CLASSES = 
  dummy: DummyDriver
  serial: SerialDriver
  tcp: TcpDriver


CreateConnection = (logger, id, uri) ->
  {protocol, pathname, query} = tokens = url.parse uri
  if uri is "dummy"
    protocol = "dummy"
    name = "Dummy"
  else
    {name} = qs = querystring.parse query
    throw new Error "unsupported connection type: #{protocol}" unless protocol in <[tcp: serial:]>
    name = "unknown#{id}" unless name?
    delete qs['name']
    tokens['qs'] = qs
  protocol = protocol.substring 0, protocol.length - 1 if protocol.endsWith ":"
  CLASS = CLASSES[protocol]
  CLASS = DummyDriver unless CLASS?
  c = new CLASS logger, id, name, uri, tokens
  return c

module.exports = exports = {CreateConnection}

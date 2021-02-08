require! <[url querystring]>
SerialDriver = require \./conn/serial
TcpDriver = require \./conn/tcp



CreateConnection = (logger, id, uri) ->
  {protocol, pathname, query} = tokens = url.parse uri
  {name} = qs = querystring.parse query
  throw new Error "unsupported connection type: #{protocol}" unless protocol in <[tcp: serial:]>
  name = "unknown#{id}" unless name?
  delete qs['name']
  tokens['qs'] = qs
  CLASS = if protocol is \tcp: then TcpDriver else SerialDriver
  c = new CLASS logger, id, name, uri, tokens
  return c

module.exports = exports = {CreateConnection}

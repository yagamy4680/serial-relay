SerialPort = require \serialport
SerialDriver = require \../helpers/serial
TcpServer = require \../helpers/tcp
WebServer = require \../helpers/web
require! <[pino path]>


ERR_EXIT = (logger, err) ->
  logger.error err
  return process.exit 1


module.exports = exports =
  command: "start <serial1> <serial2> [<assetDir>]"
  describe: "startup a relay server on serial1 and serial2 port, with a tcp server as monitor"

  builder: (yargs) ->
    yargs
      .example '$0 start /dev/tty.usbserial-FTA3BHX6,b115200,8,N,1:s1 /dev/tty.usbmodem123456781,b115200,8,N,1:s2', 'run tcp proxy server at default port 8080, and relay the traffic of serial port at path /dev/tty.usbmodem1462103'
      .alias \p, \port
      .default \p, 8080
      .describe \p, "the port number for tcp proxy server to listen"
      .alias \v, \verbose
      .default \v, no
      .describe \v, "verbose output"
      .boolean 'v'
      .demand <[p v]>


  handler: (argv) ->
    {config} = global
    {verbose, serial1, serial2} = argv
    console.log "verbose = #{verbose}"
    console.log JSON.stringify argv, ' ', null
    level = if verbose then 'trace' else 'info'
    prettyPrint = translateTime: 'SYS:HH:MM:ss.l', ignore: 'pid,hostname'
    console.log "prettyPrint => #{JSON.stringify prettyPrint}"
    logger = pino {prettyPrint, level}
    s1 = new SerialDriver logger, 1, serial1
    s2 = new SerialDriver logger, 2, serial2
    s1.set_peer_and_filter s2, (driver, chunk) -> 
      logger.info "#{driver.name} => #{s2.name}: #{(chunk.toString 'hex' .toUpperCase!).yellow}"
      return chunk
    s2.set_peer_and_filter s1, (driver, chunk) ->
      logger.info "#{s1.name} <= #{driver.name}: #{(chunk.toString 'hex' .toUpperCase!).magenta}"
      return chunk
    (s1err) <- s1.start
    return ERR_EXIT logger, s1err if s1err?
    (s12rr) <- s2.start
    return ERR_EXIT logger, s12rr if s12rr?

  /*
    opts = {baudRate, dataBits, parity, stopBits}
    (ports) <- SerialPort.list! .then
    xs = [ x for x in ports when x.path is filepath ]
    return logger.error "no such port: #{filepath}" unless xs.length >= 1
    xs = xs.pop!
    logger.debug "found #{filepath.yellow} => #{JSON.stringify xs}"
    ss = new SerialServer logger, filepath, baudRate, parity, stopBits, dataBits
    (serr) <- ss.start
    return ERR_EXIT logger, terr if terr?
    ts = new TcpServer logger, argv.port
    (terr) <- ts.start
    return ERR_EXIT logger, terr if terr?
    ws = new WebServer logger, argv.port + 1, argv.assetDir, filepath, opts
    (werr) <- ws.start
    return ERR_EXIT logger, werr if werr?

    ss.on \bytes, (chunk) -> 
      logger.debug "receive #{chunk.length} bytes from serial (#{(chunk.toString 'hex').toUpperCase!})"
      ts.broadcast chunk
      ws.broadcast chunk

    filename = path.basename filepath
    filename = filename.substring 4 if filename.startsWith "tty."

    ss.on \line, (line) -> logger.info "#{filename.yellow}: #{line}"

    ts.on \data, (chunk, connection) ->
      logger.info "receive #{chunk.length} bytes from tcp (#{(chunk.toString 'hex').toUpperCase!})"
      ss.write chunk
*/

SerialPort = require \serialport
SerialDriver = require \../helpers/serial
TcpServer = require \../helpers/tcp
WebServer = require \../helpers/web
CreateProtocolManager = require \../helpers/protocol-mgr
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
    {verbose, serial1, serial2, assetDir} = argv
    console.log "verbose = #{verbose}"
    console.log JSON.stringify argv, ' ', null
    assetDir = "." unless assetDir?
    assetDir = path.resolve process.cwd!, assetDir
    level = if verbose then 'trace' else 'info'
    prettyPrint = translateTime: 'SYS:HH:MM:ss.l', ignore: 'pid,hostname'
    console.log "prettyPrint => #{JSON.stringify prettyPrint}"
    console.log "assetDir => #{assetDir}"
    logger = pino {prettyPrint, level}
    s1 = new SerialDriver logger, 1, serial1
    s2 = new SerialDriver logger, 2, serial2
    pw = CreateProtocolManager logger, assetDir, s1, s2
    (err) <- pw.start
    return ERR_EXIT logger, err if err?
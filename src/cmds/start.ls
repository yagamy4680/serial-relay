{CreateConnection} = require \../helpers/connection
TcpServer = require \../helpers/tcp-monitor
WebServer = require \../helpers/web
CreateProtocolManager = require \../helpers/protocol-mgr
require! <[pino path]>

const EXAMPLE_CMD = '$0 start tcp://10.42.0.213:9090?name=EPC serial:///dev/tty.usbmodem123456781?settings=b115200,8,N,1&name=MPU'
const EXAMPLE_DESC = '''relay from one tcp connection (to remote 10.42.0.213:9090) to 
another serial connection (to local device /dev/tty.usbmodem123456781 with given settings), 
and setup a TcpServer as monitor.
'''
const EPILOG = '''
There are 2 types of supported connections to be relayed:

  1. Serial, 
      e.g. `serial:///dev/tty.usbmodem123456781?settings=b115200,8,N,1`
      Local UART device `/dev/tty.usbmodem123456781` with settings
        - baudrate (115200)
        - dataBit (8)
        - parity (N)
        - stopBits (1)

  2. Tcp
      e.g. tcp://10.42.0.213:9090
'''

ERR_EXIT = (logger, err) ->
  logger.error err
  return process.exit 1


module.exports = exports =
  command: "start <conn1> <conn2> [<assetDir>]"
  describe: "startup a relay server on conn1 and conn2 port, with a tcp server as monitor"

  builder: (yargs) ->
    yargs
      .example EXAMPLE_CMD, EXAMPLE_DESC
      .epilogue EPILOG
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
    {verbose, conn1, conn2, assetDir} = argv
    console.log "verbose = #{verbose}"
    console.log JSON.stringify argv, ' ', null
    assetDir = "." unless assetDir?
    assetDir = path.resolve process.cwd!, assetDir
    level = if verbose then 'trace' else 'info'
    prettyPrint = translateTime: 'SYS:HH:MM:ss.l', ignore: 'pid,hostname'
    console.log "prettyPrint => #{JSON.stringify prettyPrint}"
    console.log "assetDir => #{assetDir}"
    logger = pino {prettyPrint, level}
    c1 = CreateConnection logger, 1, conn1
    c2 = CreateConnection logger, 2, conn2
    pw = CreateProtocolManager logger, assetDir, c1, c2
    (err) <- pw.start
    return ERR_EXIT logger, err if err?

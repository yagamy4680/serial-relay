{CreateConnection} = require \../helpers/connection
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


There are 4 directions of filters:
  [1] s2p
  [2] d2p
  [3] p2d
  [4] p2s

        s2p        p2d
  src --[1]--> p --[3]--> dst
  dst --[2]--> p --[4]--> src
        d2p        p2s
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
      .describe \p, "the port number for tcp monitor server to listen"
      .alias \d, \directions
      .default \d, "p2d,p2s"
      .describe \d, "the direction filters for the traffics dumped to tcp monitor server"
      .alias \v, \verbose
      .default \v, no
      .describe \v, "verbose output"
      .boolean 'v'
      .demand <[p v]>


  handler: (argv) ->
    {config} = global
    {verbose, conn1, conn2, assetDir, port, directions} = argv
    portTcp = port
    portWeb = port + 1
    console.log JSON.stringify argv, ' ', null
    console.log "verbose = #{verbose}"
    console.log "directions = #{directions}"
    console.log "monitor: tcp:#{portTcp}, web:#{portWeb}"
    assetDir = "." unless assetDir?
    assetDir = path.resolve process.cwd!, assetDir
    level = if verbose then 'trace' else 'info'
    prettyPrint = translateTime: 'SYS:HH:MM:ss.l', ignore: 'pid,hostname'
    console.log "prettyPrint => #{JSON.stringify prettyPrint}"
    console.log "assetDir => #{assetDir}"
    logger = pino {prettyPrint, level}
    c1 = CreateConnection logger, 1, conn1
    c2 = CreateConnection logger, 2, conn2
    pw = CreateProtocolManager logger, assetDir, c1, c2, portTcp, portWeb, directions
    (err) <- pw.start
    return ERR_EXIT logger, err if err?

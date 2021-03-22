#!/usr/bin/env lsc
#
io = require \socket.io-client

c = io "ws://localhost:8081/relay", autoConnect:no
c.on \connect, -> 
    console.log "connected."
    c.emit \config, name: process.argv[1]

c.on \protocol, (direction, chunk) -> 
    console.log "#{direction}: #{chunk.toString 'hex'}"
    return c.emit \protocol, \p2d, chunk if direction is \s2p
    return c.emit \protocol, \p2s, chunk if direction is \d2p
    return

c.connect!

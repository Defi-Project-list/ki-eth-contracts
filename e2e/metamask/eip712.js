const io = require('socket.io-client')

const socket = io("ws://127.0.0.1:3003", {
  reconnectionDelayMax: 10000,
})

socket.emit('sign request', process.argv[2])

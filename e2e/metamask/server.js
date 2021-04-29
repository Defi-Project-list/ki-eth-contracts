const express = require('express')
const app = express()
const http = require('http')
const server = http.createServer(app)
const io = require("socket.io")(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
})

app.get('/', (req, res) => {
  res.sendFile(__dirname + '/signer.html')
})


app.use('/', express.static(__dirname))

io.on('connection', (socket) => {
  console.log('a user connected')
  socket.on('disconnect', () => {
    console.log('user disconnected')
  })
  socket.on('sign request', msg => {
	io.emit('sign', msg)
  })
  socket.on('send request', msg => {
	io.emit('send', msg)
  })

})

server.listen(3003, () => {
  console.log('listening on *:3003')
})


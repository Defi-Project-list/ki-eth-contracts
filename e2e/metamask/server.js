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

let signer

app.use('/', express.static(__dirname))

io.on('connection', (socket) => {
  console.log('user connected', socket.id)
  socket.on('disconnect', () => {
    console.log('user disconnected')
  })
  socket.on('signer', () => {
    	console.log('signer registed')
	signer = socket
  })
  socket.on('sign request', (msg, callback) => {
	console.log('sign request:', msg)
	signer & signer.emit('sign', msg, res => { console.log(res); callback(res) })
  })
  socket.on('send request', msg => {
	console.log('send request:', msg, callback)
	siger & signer.emit('send', msg, res => { console.log(res); callback(res) })
  })

})

server.listen(3003, () => {
  console.log('listening on *:3003')
})


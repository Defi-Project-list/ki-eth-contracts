const socket = io("ws://localhost:3003")

const messages = document.getElementById('messages')
const form = document.getElementById('form')
const input = document.getElementById('input')

window.ethereum.enable()

const send = params => {
	ethereum.request({ method: 'eth_accounts' })
  	.then(address => {
		window.ethereum.request({
	    		method: 'eth_sendTransaction',
			params: [{ from: address[0], value: '0x2386f26fc10000', ...params[0]}],
	  	})
	  	.then((result) => {
			console.log(JSON.stringify(result))
	  	})
	  	.catch((error) => {
			console.warn(JSON.stringify(error))
	  	})
	})
  	.catch((err) => {
	  console.warn(err)
	})
}

const sign = (params, callback) => {
	ethereum.request({ method: 'eth_accounts' })
  	.then(address => {
		window.ethereum.request({
    			method: 'eth_signTypedData_v4',
			params: [address[0], JSON.stringify(params[0])],
			from: address[0],
	  	})
	  	.then((result) => {
			console.log(JSON.stringify(result))
			callback(result)
	  	})
	  	.catch((error) => {
			console.warn(JSON.stringify(error))
	  	})
	})
  	.catch((err) => {
	  console.warn(err)
	})
}

const sign_v1 = (params, callback) => {
	ethereum.request({ method: 'eth_accounts' })
  	.then(address => {
		const req = {
                        method: 'eth_signTypedData',
                        params: [params[0], address[0]],
                        from: address[0],
                }
		console.log('req', JSON.stringify(req, null, 2))
		window.ethereum.request(req)
	  	.then((result) => {
			console.log(JSON.stringify(result))
			callback(result)
	  	})
	  	.catch((error) => {
			console.warn(JSON.stringify(error))
	  	})
	})
  	.catch((err) => {
	  console.warn(err)
	})
}

socket.on('send', msg => {
  const item = document.createElement('li')
  const params = JSON.parse(msg)
  item.textContent = `SEND to=${params[0].to} value=${params[0].value}`
  messages.appendChild(item)
  window.scrollTo(0, document.body.scrollHeight)
  send(params, callback)
})

socket.on('sign', (msg, callback) => {
  const item = document.createElement('li')
  const params = JSON.parse(msg)
  item.textContent = `SIGN ${msg}`
  messages.appendChild(item)
  window.scrollTo(0, document.body.scrollHeight)
  sign(params, callback)
})

socket.on('sign_v1', (msg, callback) => {
  const item = document.createElement('li')
  const params = JSON.parse(msg)
  item.textContent = `SIGN ${msg}`
  messages.appendChild(item)
  window.scrollTo(0, document.body.scrollHeight)
  sign_v1(params, callback)
})

socket.on('connect', () => {
  socket.emit('signer')
})

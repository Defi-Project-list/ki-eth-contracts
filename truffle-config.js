const HDWalletProvider = require("truffle-hdwallet-provider");
let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
    networks: {
	    rinkeby: {
	        provider: function() {
			    mnemonic = 'pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade';
			    return new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/Mi3WQKlqLIU6IQtAvddB");
		    },
			network_id: '3',
		},
	    ganache: {
		    provider: function() {
			    return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/");
		    },
		    network_id: '5777',
	    },
		test: {
		    provider: function() {
			    return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
		    },
		    network_id: '*',
	    },
	    development: {
		    provider: function() {
			    return new HDWalletProvider(mnemonic, "http://127.0.0.1:9545/");
		    },
		    network_id: '*',
	    },
    }
};

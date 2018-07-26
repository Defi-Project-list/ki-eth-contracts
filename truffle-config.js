
const HDWalletProvider = require("truffle-hdwallet-provider");
// let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
let mnemonic = "pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade";

// const ganache = require('ganache-cli');
const devNetwork = {
  host: "127.0.0.1",	
  port: 8545,
  network_id: "*"
};

module.exports = {
  networks: {
    rinkeby: {
      provider: function() {
        mnemonic =
          "pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade";
        return new HDWalletProvider(
          mnemonic, "https://rinkeby.infura.io/Mi3WQKlqLIU6IQtAvddB"
        );
      },
      network_id: "4"
    },
    ganache: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      },
      network_id: "1337",
    },
    development: devNetwork,
    dev: devNetwork
  }
};

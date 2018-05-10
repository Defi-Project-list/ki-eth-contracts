
const HDWalletProvider = require("truffle-hdwallet-provider");
let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

// const ganache = require('ganache-cli');
const devNetwork = {
  host: "127.0.0.1",	
  port: 7545,
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
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/");
      },
      network_id: "5777",
    },
    development: devNetwork,
    dev: devNetwork
  }
};


const HDWalletProvider = require("truffle-hdwallet-provider");
// let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
//let mnemonic = "pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade";
let mnemonic = "front assume robust donkey senior economy maple enhance click bright game alcohol";

// const ganache = require('ganache-cli');
const devNetwork = {
  host: "127.0.0.1",	
  port: 8545,
  network_id: "*",
  gas: 7000000
};

module.exports = {
  networks: {
    rinkeby: {
      provider: function() {
        mnemonic =
          "front assume robust donkey senior economy maple enhance click bright game alcohol";
        return new HDWalletProvider(
          mnemonic, "https://rinkeby.infura.io/Mi3WQKlqLIU6IQtAvddB"
        );
      },
      network_id: "4",
      gas: 7000000
    },
    kovan: {
      provider: function() {
        mnemonic =
          "front assume robust donkey senior economy maple enhance click bright game alcohol";
        return new HDWalletProvider(
          mnemonic, "https://kovan.infura.io/Mi3WQKlqLIU6IQtAvddB"
        );
      },
      network_id: "42",
      gas: 7000000
    },
    ropsten: {
      provider: function() {
        mnemonic =
          "front assume robust donkey senior economy maple enhance click bright game alcohol";
        return new HDWalletProvider(
          mnemonic, "https://ropsten.infura.io/Mi3WQKlqLIU6IQtAvddB"
        );
      },
      network_id: "3",        
      gas: 7000000
    },
    ganache: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      },
      network_id: "1337",
      gas: 7000000
    },
    development: devNetwork,
    dev: devNetwork
  },
  solc: {
        optimizer: {
            enabled: true,
            runs: 200
        }
    }
};

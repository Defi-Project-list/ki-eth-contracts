
const HDWalletProvider = require("@truffle/hdwallet-provider");
// let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
let mnemonic = "pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade";
//let mnemonic = "front assume robust donkey senior economy maple enhance click bright game alcohol";
const gas = 8200000;

// const ganache = require('ganache-cli');
const devNetwork = {
  host: "127.0.0.1",
  port: 8545,
  network_id: "*",
  provider: function() {
    const mnemonic = 'awesome grain neither pond excess garage tackle table piece assist venture escape'
    return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/");
  },
  // gas
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
      gas
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
      gas
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
      gas
    },
    ganache: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      },
      network_id: "1337",
      gas
    },
    development: devNetwork,
    dev: devNetwork
  },
  solc: {
      settings: {
        optimizer: {
          enabled: true,
          runs: 400   // Optimize for how many times you intend to run the code
        },
      },
        optimizer: {
            enabled: true,
            runs: 400
        }
    }
};

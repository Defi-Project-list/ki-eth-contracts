
const HDWalletProvider = require("@truffle/hdwallet-provider");
const ganache = require("ganache-cli")
let server

// let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
let mnemonic = "pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade";
// let mnemonic = "front assume robust donkey senior economy maple enhance click bright game alcohol";
const gas = 12500000;

// const ganache = require('ganache-cli');
const devNetwork = {
  // host: "127.0.0.1",
  // port: 8545,
  network_id: "*",
  provider: function() {
     const mnemonic = 'awesome grain neither pond excess garage tackle table piece assist venture escape'
    return new HDWalletProvider(mnemonic, 'ws://localhost:8545')
//     {
//       mnemonic: {
//         phrase: mnemonic
//       },
//       providerOrUrl: "http://localhost:8545",
//       numberOfAddresses: 10,
// });
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
          mnemonic, "https://rinkeby.infura.io/v3/adb23ed195ef4a499b698007beb437ca"
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
	    host: "127.0.0.1",
      port: 8545,
      // provider: function() {
      //   return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      // },
      network_id: "*",
      gas,
      ens: {
        registry: {
          address: '0x194882C829ba3F56C7B7b99175435381d8Ac30B9',
        },
      },
    },
    development: {
      network_id: "*",
      provider: function () {
        // const mnemonic = 'awesome grain neither pond excess garage tackle table piece assist venture escape'
        const mnemonic = 'front assume robust donkey senior economy maple enhance click bright game alcohol'
        const port = 7545
        if (!server) {
          server = ganache.server({ mnemonic })
           server.listen(port, () => { console.log('ready') })
         }
         const provider = new HDWalletProvider(mnemonic, `http://127.0.0.1:${port}`)
         return provider
       },
    },
    dev: devNetwork
  },
  compilers: {
     solc: {
       // version: "0.6.11"  // ex:  "0.4.20". (Default: Truffle's installed solc)
       version: "0.8.4"  // ex:  "0.4.20". (Default: Truffle's installed solc)
     }
  },
  ens: {
    enabled: true
  },
  mochax: {
    reporter: 'eth-gas-reporter',
    reporterOptions : {
      url: 'http://127.0.0.1:7545',
    },
    // timeout: 100000
  },
  solc: {
      settings: {
        optimizer: {
          enabled: true,
          runs: 200   // Optimize for how many times you intend to run the code
        },
      },
        optimizer: {
            enabled: true,
            runs: 200
        }
    }
};

const HDWalletProvider = require("@truffle/hdwallet-provider");


module.exports = {
  plugins: [
    'truffle-plugin-verify'
  ],

  
  api_keys: {
    etherscan: 'T8Z8DMJTDYHKRSFKYYHJ7IH7DG2HB94TT3'
  },

  networks: {
    ganache: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*" ,// Match any network id
      gasPrice: 20000000000,
      gas: "6721975",
    },
    rinkeby: {
      provider: function() {
        const mnemonic =	"attack limb hood nothing divert clown target corn muscle leader naive small";
        return new HDWalletProvider(
          mnemonic, "https://rinkeby.infura.io/v3/adb23ed195ef4a499b698007beb437ca"
        );
      },
      network_id: 4,
      //gasPrice: 1,
      //gas: "7000000",
      //from: "0x29bC20DebBB95fEFef4dB8057121c8e84547E1A9",
      },
    },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
       version: "0.8.2",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
      //  evmVersion: "byzantium"
      }
    }
  },

 
  db: {
    enabled: false
  }
};



/* 
const HDWalletProvider = require("@truffle/hdwallet-provider");
const ganache = require("ganache-cli")
let server

const mnemonic = 'attack limb hood nothing divert clown target corn muscle leader naive small'; //0x29
// let mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
//let mnemonic = "pelican bench orchard wisdom honey deputy donate suspect airport sail quick decade";
// let mnemonic = "front assume robust donkey senior economy maple enhance click bright game alcohol";
const gas = 12500000;
const gasPrice = 470000000000;

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
        //mnemonic = "front assume robust donkey senior economy maple enhance click bright game alcohol";
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
      /* provider: function() {
         return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      }, */
      /*
      network_id: "*",
      gas,
      ens: {
        registry: {
          address: '0x194882C829ba3F56C7B7b99175435381d8Ac30B9',
        },
      },
    },
    testnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: "0x29bC20DebBB95fEFef4dB8057121c8e84547E1A9",
      //from: "0x1cbed60336E3FEe0734325fe70B13B805c15d99d",
      //gas: "2000000",//29999542
      //gasPrice: "470000000000",
    },
    bsc: {
      provider: () => new HDWalletProvider(mnemonic, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    development: {
      network_id: "*",
      provider: function () {
        const mnemonic = 'awesome grain neither pond excess garage tackle table piece assist venture escape'
        const port = 9545
        const accounts = 220
        if (!server) {
          server = ganache.server({
            mnemonic,
            total_accounts: accounts,
            gasLimit: 22500000,
            default_balance_ether: 1000,
          })
           server.listen(port, () => { console.log('ready') })
         }
         const provider = new HDWalletProvider({
           mnemonic,
           numberOfAddresses: accounts,
           providerOrUrl: `http://127.0.0.1:${port}`,
           _chainId: 4,
           _chainIdRpc: 4,
          })
         return provider
       },
      ens: {
        registry: {
          address: '0x194882C829ba3F56C7B7b99175435381d8Ac30B9',
        },
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
 */
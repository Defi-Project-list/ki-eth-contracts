var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Wallet = artifacts.require("./Wallet.sol");

var SW_Factory = artifacts.require("./SW_Factory.sol");
var SW_FactoryProxy = artifacts.require("./SW_FactoryProxy.sol");
var SmartWallet = artifacts.require("./SmartWallet.sol");
var SmartWallet2 = artifacts.require("./test/SmartWallet2.sol");

module.exports = function(deployer) {
  deployer.deploy(SW_Factory, { gas: 5712388 });
  deployer.deploy(SW_FactoryProxy, { gas: 5712388 });
  deployer.deploy(SmartWallet, { gas: 5712388 });
  deployer.deploy(SmartWallet2, { gas: 4712388 });
  deployer.deploy(Sender, { gas: 4712388 });
  deployer.deploy(Sanity, { gas: 4712389 });
  deployer.deploy(Wallet, {
    gas: 4712388,
    // value: web3.toWei(1, 'finney')
  });
}


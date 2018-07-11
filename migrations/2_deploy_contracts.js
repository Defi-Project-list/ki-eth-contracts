var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Wallet = artifacts.require("./Wallet.sol");

var SWProxyFactory = artifacts.require("./SWProxyFactory.sol");
var SmartWallet = artifacts.require("./SmartWallet.sol");
var SmartWallet2 = artifacts.require("./test/SmartWallet2.sol");

module.exports = function(deployer) {
  deployer.deploy(SWProxyFactory, { gas: 4712388 });
  deployer.deploy(SmartWallet, { gas: 5712388 });
  deployer.deploy(SmartWallet2, { gas: 4712388 });
  deployer.deploy(Sender, { gas: 4712388 });
  deployer.deploy(Sanity, { gas: 4712389 });
  deployer.deploy(Wallet, {
    gas: 4712388,
    // value: web3.toWei(1, 'finney')
  });
}


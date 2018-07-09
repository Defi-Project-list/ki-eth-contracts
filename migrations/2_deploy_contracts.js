var Sanity = artifacts.require("./Sanity.sol");
//var Backup = artifacts.require("./Backup.sol");
var Wallet = artifacts.require("./Wallet.sol");
var SWProxyFactory = artifacts.require("./SWProxyFactory.sol");
var SmartWallet = artifacts.require("./SmartWallet.sol");
var SmartWallet2 = artifacts.require("./SmartWallet2.sol");
var SWProxy = artifacts.require("./SWProxy.sol");
var Sender = artifacts.require("./Sender.sol");


module.exports = function(deployer) {
  deployer.deploy(SWProxyFactory, { gas: 4712388 });
  deployer.deploy(SmartWallet, { gas: 4712388 });
  deployer.deploy(SmartWallet2, { gas: 4712388 });
  deployer.deploy(Sender, { gas: 4712388 });
  deployer.deploy(Sanity, { gas: 4712388 });
  deployer.deploy(Wallet, {
    gas: 4712388,
    // value: web3.toWei(1, 'finney')
  });
}


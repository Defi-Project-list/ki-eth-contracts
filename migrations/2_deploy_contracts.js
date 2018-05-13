var Sanity = artifacts.require("./Sanity.sol");
//var Backup = artifacts.require("./Backup.sol");
var Wallet = artifacts.require("./Wallet.sol");


module.exports = function(deployer) {
  deployer.deploy(Sanity, { gas: 4712388 });
  deployer.deploy(Wallet, {
    gas: 4712388,
    // value: web3.toWei(1, 'finney')
  });
}


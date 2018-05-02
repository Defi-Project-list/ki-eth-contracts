var Sanity = artifacts.require("./Sanity.sol");
var Backup = artifacts.require("./Backup.sol");

module.exports = function(deployer) {
  deployer.deploy(Sanity, { gas: 4712388 });
  deployer.deploy(Backup, { gas: 4712388 });
};

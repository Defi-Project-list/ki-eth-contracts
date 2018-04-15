var Sanity = artifacts.require("./Sanity.sol");
var Backup = artifacts.require("./Backup.sol");

module.exports = function(deployer) {
  deployer.deploy(Sanity);
  deployer.deploy(Backup);
};

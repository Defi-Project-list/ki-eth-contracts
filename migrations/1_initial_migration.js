var Migrations = artifacts.require("./Migrations.sol");
const gasPrice =  web3.toWei(2, 'gwei');
const gas = 7000000;

module.exports = function(deployer) {
  deployer.deploy(Migrations, {gas, gasPrice});
};

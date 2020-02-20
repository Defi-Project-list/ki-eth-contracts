var Migrations = artifacts.require("./Migrations.sol");
const gasPrice =  web3.utils.toWei('3', 'gwei');
const gas = 6200000;

module.exports = function(deployer) {
  deployer.deploy(Migrations); //, {gas, gasPrice});
};

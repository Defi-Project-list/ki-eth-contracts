var Migrations = artifacts.require("./Migrations.sol");
const gasPrice =  web3.utils.toWei('3', 'gwei');
const gas = 12500000;

module.exports = async function (deployer) {
  console.log('initial_migrations')
  return
  await deployer.deploy(Migrations, {gas, gasPrice});
};

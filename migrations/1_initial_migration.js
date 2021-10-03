var Migrations = artifacts.require("./Migrations.sol");
//const gasPrice =  web3.utils.toWei('3', 'gwei');
//const gas = 12500000;
//const gas = "2000000";//29999542
//const gasPrice = "470000000000";

module.exports = async function (deployer) {
  console.log('initial_migrations')
  //return
  await deployer.deploy(Migrations);//, {gas, gasPrice});
};

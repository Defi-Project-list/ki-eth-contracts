var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Wallet = artifacts.require("./Wallet.sol");

var SW_Factory = artifacts.require("./SW_Factory.sol");
var SW_FactoryProxy = artifacts.require("./SW_FactoryProxy.sol");
var SmartWallet = artifacts.require("./SmartWallet.sol");
var SmartWallet2 = artifacts.require("./test/SmartWallet2.sol");
var Root = artifacts.require("./Root.sol");

const liveNetworks = { rinkeby: true, kovan: true };
const gasPrice =  web3.toWei(1, 'gwei');
const gas = 5912388;

module.exports = function(deployer, network) {
  deployer.then(async () => {
	  const factoryProxy = await deployer.deploy(SW_FactoryProxy, { gas, gasPrice, overwrite: !liveNetworks[network] });
  	  const factory = await deployer.deploy(SW_Factory, { gas, gasPrice });
	  await factoryProxy.setTarget(factory.address, { gas, gasPrice });
  	  const sw = await deployer.deploy(SmartWallet, { gas, gasPrice });
	  try { 
	  	await SW_Factory.at(factoryProxy.address).addVersion(sw.address, { gas, gasPrice });
	  }
	  catch(err) {
		console.error('addVersion failed. Please check version number.');
	  }
	  //await deployer.deploy(Wallet, { gas: 4712388 });
  	  //await deployer.deploy(Root, { gas: 4712388 });
  });

}


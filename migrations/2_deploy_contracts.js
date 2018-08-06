var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Wallet = artifacts.require("./Wallet.sol");

var SW_Factory = artifacts.require("./SW_Factory.sol");
var SW_FactoryProxy = artifacts.require("./SW_FactoryProxy.sol");
var SmartWallet = artifacts.require("./SmartWallet.sol");
var SmartWallet2 = artifacts.require("./test/SmartWallet2.sol");
var Root = artifacts.require("./Root.sol");

const liveNetworks = { rinkeby: true }

module.exports = function(deployer, network) {
  deployer.then(async () => {
	  const factoryProxy = await deployer.deploy(SW_FactoryProxy, { gas: 5812388 , overwrite: !liveNetworks[network] });
  	  const factory = await deployer.deploy(SW_Factory, { gas: 5812388 });
	  await factoryProxy.setTarget(factory.address);
  	  const sw = await deployer.deploy(SmartWallet, { gas: 5812388 });
	  try { 
	  	await SW_Factory.at(factoryProxy.address).addVersion(sw.address);
	  }
	  catch(err) {
		console.error('addVersion failed. Please check version number.');
	  }
	  //await deployer.deploy(Wallet, { gas: 4712388 });
  	  //await deployer.deploy(Root, { gas: 4712388 });
  });

}


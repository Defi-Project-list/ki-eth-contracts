var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Factory = artifacts.require("./Factory.sol");
var FactoryProxy = artifacts.require("./FactoryProxy.sol");
var Wallet = artifacts.require("./Wallet.sol");
var Oracle = artifacts.require("./Oracle.sol");
var SmartWallet2 = artifacts.require("./test/Wallet2.sol");
var Root = artifacts.require("./Root.sol");

const liveNetworks = { rinkeby: true, kovan: true };
const gasPrice =  web3.toWei(3, 'gwei');
const gas = 6200000;

module.exports = function(deployer, network) {
  deployer.then(async () => {
	  const factoryProxy = await deployer.deploy(FactoryProxy, { gas, gasPrice, overwrite: !liveNetworks[network] });
  	const factory = await deployer.deploy(Factory, { gas, gasPrice });
	  await factoryProxy.setTarget(factory.address, { gas, gasPrice });
  	const sw = await deployer.deploy(Wallet, { gas, gasPrice });
		const oracle = await deployer.deploy(Oracle, { gas, gasPrice });
	  try {
	  	await Factory.at(factoryProxy.address).addVersion(sw.address, oracle.address, { gas, gasPrice });
	  	await Factory.at(factoryProxy.address).deployVersion(await sw.version(), { gas, gasPrice });
	  }
	  catch(err) {
		console.error('addVersion failed. Please check version number.');
	  }
  	  //await deployer.deploy(Root, { gas: 4712388 });
  });

}


var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Factory = artifacts.require("./Factory.sol");
var FactoryProxy = artifacts.require("./FactoryProxy.sol");
var Wallet = artifacts.require("./Wallet.sol");
var Oracle = artifacts.require("./Oracle.sol");
var SmartWallet2 = artifacts.require("./test/Wallet2.sol");
var Root = artifacts.require("./Root.sol");

const liveNetworks = { rinkeby: true, kovan: true };

const gasPrice =  web3.utils.toWei('3', 'gwei');
const gas = 6000000;

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
	  const factoryProxy = await deployer.deploy(FactoryProxy, accounts[0], accounts[1], accounts[2], { gas, gasPrice, overwrite: !liveNetworks[network] });
  	const factory = await deployer.deploy(Factory, accounts[0], accounts[1], accounts[2], { gas, gasPrice });
	  await factoryProxy.setTarget(factory.address, { gas, gasPrice, from:accounts[0] });
	  await factoryProxy.setTarget(factory.address, { gas, gasPrice, from:accounts[1] });
  	const sw = await deployer.deploy(Wallet, { gas, gasPrice });
    const oracle = await deployer.deploy(Oracle, accounts[0], accounts[1], accounts[2], { gas, gasPrice });

	  try {
      const ora = await Oracle.at(oracle.address)
      await ora.setPaymentAddress(accounts[0], { from: accounts[0] })
      await ora.setPaymentAddress(accounts[0], { from: accounts[1] })

		  const fac = await Factory.at(factoryProxy.address)
		  
	  	await fac.addVersion(sw.address, oracle.address, { from: accounts[0], gas, gasPrice });
	  	await fac.addVersion(sw.address, oracle.address, { from: accounts[1], gas, gasPrice });
	  	await fac.deployVersion(await sw.version(), { from: accounts[0], gas, gasPrice });
	  	await fac.deployVersion(await sw.version(), { from: accounts[1], gas, gasPrice });

		  // const fac1 = await Factory.at(factory.address)
		  
	  	// await fac1.addVersion(sw.address, oracle.address, { from: accounts[0], gas, gasPrice });
	  	// await fac1.addVersion(sw.address, oracle.address, { from: accounts[1], gas, gasPrice });
	  	// await fac1.deployVersion(await sw.version(), { from: accounts[0], gas, gasPrice });
	  	// await fac1.deployVersion(await sw.version(), { from: accounts[1], gas, gasPrice });

    }
	  catch(err) {
		console.error('addVersion failed. Please check version number.', err);
	  }
  	  //await deployer.deploy(Root, { gas: 4712388 });
  });

}


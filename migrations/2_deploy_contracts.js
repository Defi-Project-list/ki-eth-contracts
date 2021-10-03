var Sanity = artifacts.require("./test/Sanity.sol");
var Sender = artifacts.require("./test/Sender.sol");

var Factory = artifacts.require("./Factory.sol");
var FactoryProxy = artifacts.require("FactoryProxy");
var Wallet = artifacts.require("./Wallet.sol");
var Oracle = artifacts.require("./Oracle.sol");
var SmartWallet2 = artifacts.require("./test/Wallet2.sol");
var Root = artifacts.require("./Root.sol");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const liveNetworks = {testnet:true};

//const gasPrice =  web3.utils.toWei('1000', 'wei');
//const gas = 2500000;
const gas = "2000000";//29999542
const gasPrice = "470000000000";

module.exports = function (deployer, network, accounts) {
  console.log('deploy_contracts')
  //return
  deployer.then(async () => {
	const sw_factory = await deployer.deploy(Factory, {from:accounts[0]})//,  gas, gasPrice });
	const sw_factory_proxy = await deployer.deploy(FactoryProxy, ZERO_ADDRESS, {from:accounts[0] })//, gas, gasPrice });
	//await sw_factory_proxy.setTarget("0x37BBb972a1f11d1b691268cdf94A601227A07528", { from: accounts[0] });
	//const factory = await Factory.at("0x6DaAD2710F013C0b459Eb7e05937342286fB4D9f");
    //const factoryProxy = await FactoryProxy.at("0x6DaAD2710F013C0b459Eb7e05937342286fB4D9f");
	const sw = await deployer.deploy(Wallet, {from:accounts[0]})//, { gas, gasPrice });
    const oracle = await deployer.deploy(Oracle, accounts[0], accounts[1], accounts[2], {from:accounts[0]})//, { gas, gasPrice });
	//const ora = await Oracle.at(oracle.address)
	//await ora.setPaymentAddress(accounts[0], { from: accounts[0] })
	//await ora.setPaymentAddress(accounts[0], { from: accounts[1] })

	//await factory.addVersion(sw.address, oracle.address, { from: accounts[0]})//, gas, gasPrice });
	//await factory.deployVersion(await sw.version(), { from: accounts[0]})//, gas, gasPrice });
  	  /*
	  try {
      
      

		  const fac = await Factory.at(factoryProxy.address)

	  	await fac.addVersion(sw.address, oracle.address, { from: accounts[0], gas, gasPrice });
	  	//await fac.addVersion(sw.address, oracle.address, { from: accounts[1], gas, gasPrice });
	  	await fac.deployVersion(await sw.version(), { from: accounts[0], gas, gasPrice });
	  	//await fac.deployVersion(await sw.version(), { from: accounts[1], gas, gasPrice });

		  // const fac1 = await Factory.at(factory.address)

	  	// await fac1.addVersion(sw.address, oracle.address, { from: accounts[0], gas, gasPrice });
	  	// await fac1.addVersion(sw.address, oracle.address, { from: accounts[1], gas, gasPrice });
	  	// await fac1.deployVersion(await sw.version(), { from: accounts[0], gas, gasPrice });
	  	// await fac1.deployVersion(await sw.version(), { from: accounts[1], gas, gasPrice });
*/
    }
	  //catch(err) {
	//	console.error('addVersion failed. Please check version number.', err);
	  //}
  	  //await deployer.deploy(Root, { gas: 4712388 });
  //}
  );

}


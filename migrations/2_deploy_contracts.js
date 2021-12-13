//var Sanity = artifacts.require("./test/Sanity.sol");
//var Sender = artifacts.require("./test/Sender.sol");

var Factory = artifacts.require("./Factory.sol");
var FactoryProxy = artifacts.require("FactoryProxy");
var GasReturn = artifacts.require("./GasReturn.sol");
var Wallet = artifacts.require("./RecoveryWallet.sol");
var Oracle = artifacts.require("./Oracle.sol");
var RecoveryOracle = artifacts.require("RecoveryOracle");
//var SmartWallet2 = artifacts.require("./test/Wallet2.sol");
// var Root = artifacts.require("./Root.sol");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const nftContractAddress = "0x0CC8292C43B390C19636C06bC5fD7269ABf4a3F2";
const oracleAddress = "0x04557cC70CDAE3bEF8ec1177E2b4a7e53089127a";
const recoveryWalletAddress = "0x7A0003E34fF767b5A3538bf570F446E9B52cF8Df";

/*
FactoryProxy - 0xfAB9A5dBd1dC0b590E3D77133ea5a2d623208594
Factory - 0x13c65b2c54753DD24fA48ca3E7EF8fc132e7E972
GasReturn - 0x88b46C68c546f46cC3B2A549B83090e72E0AF165
kiroboNFT - 0x0CC8292C43B390C19636C06bC5fD7269ABf4a3F2
RecoveryWallet - 0x7A0003E34fF767b5A3538bf570F446E9B52cF8Df
Oracle - 0x2358DF2B4B48F1F12bC7bdE9E6aaCeecEf0CFBF2
recoveryOracle - 0x8808874F60eBe53917D8aaD1e79250D18f15D923
*/

//const liveNetworks = {testnet:true};

//const gasPrice =  web3.utils.toWei('1000', 'wei');
//const gas = 2500000;
//const gas = "2000000";//29999542
//const gasPrice = "470000000000";

module.exports = function (deployer, network, accounts) {
  console.log('deploy_contracts')
  //return
  deployer.then(async () => {
	/* const sw_factory = await deployer.deploy(Factory, {from:accounts[0]})//,  gas, gasPrice });
	const sw_factory_proxy = await deployer.deploy(FactoryProxy, ZERO_ADDRESS, {from:accounts[0] })//, gas, gasPrice });
	const factory = await Factory.at(sw_factory_proxy.address);
	await sw_factory_proxy.setTarget(factory.address, { from: accounts[0] });
    const factoryProxy = await FactoryProxy.at(sw_factory_proxy.address);*/
	//const gasReturn = await deployer.deploy(GasReturn, accounts[0], "0xfAB9A5dBd1dC0b590E3D77133ea5a2d623208594", nftContractAddress, {from: accounts[0]});  
	
	//take gasReturn.address to hard code in RecoveryWallet contract and then run the next part
	const factory = await Factory.at("0xfAB9A5dBd1dC0b590E3D77133ea5a2d623208594",{ from: accounts[0]});
	//const sw = await deployer.deploy(Wallet, {from:accounts[0]})//, { gas, gasPrice });
    //const oracle = await deployer.deploy(Oracle, accounts[0], accounts[1], accounts[2], {from:accounts[0]})//, { gas, gasPrice });
	const sw = await Wallet.at("0x7A0003E34fF767b5A3538bf570F446E9B52cF8Df",{ from: accounts[0]});
	//const ora = await Oracle.at("0x2358DF2B4B48F1F12bC7bdE9E6aaCeecEf0CFBF2",{ from: accounts[0]});
	//const recoveryOracle = await deployer.deploy(RecoveryOracle, accounts[0], accounts[1], accounts[2], {from:accounts[0]})
	const recoO = await RecoveryOracle.at("0x8808874F60eBe53917D8aaD1e79250D18f15D923",{ from: accounts[0]});
	await recoO.setPaymentAddress(accounts[1], { from: accounts[0] })
	await recoO.setPaymentAddress(accounts[1], { from: accounts[1] })
	await factory.addVersion(sw.address, recoO.address,{ from: accounts[0]})//, gas, gasPrice });
	await factory.deployVersion(await sw.version(), { from: accounts[0]})//, gas, gasPrice });  */
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


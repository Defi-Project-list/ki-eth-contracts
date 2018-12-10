var ERC20Token = artifacts.require("./test/ERC20Token");

const liveNetworks = { rinkeby: true, kovan: true };
const gasPrice =  web3.toWei(3, 'gwei');
const gas = 6552388;

module.exports = function(deployer, network) {
  deployer.then(async () => {
    const token20 = await deployer.deploy(ERC20Token, "Kirobo20Test", "KBD20T", 18, { gas, gasPrice, overwrite: !liveNetworks[network] });
  });

}


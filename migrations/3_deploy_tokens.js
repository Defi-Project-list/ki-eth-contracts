const ERC20Token = artifacts.require("./test/ERC20Token");
const ERC721Token = artifacts.require("./test/ERC721Token");

const liveNetworks = { rinkeby: true, kovan: true };
const gasPrice =  web3.toWei(3, 'gwei');
const gas = 7000000;

module.exports = function(deployer, network) {
  deployer.then(async () => {
    const token20 = await deployer.deploy(ERC20Token, "Kirobo20Test", "KBD20T", 18, { gas, gasPrice, overwrite: !liveNetworks[network] });
    const token721 = await deployer.deploy(ERC721Token, "Kirobo721Test", "KBD721T", { gas, gasPrice, overwrite: !liveNetworks[network] });
  });

}


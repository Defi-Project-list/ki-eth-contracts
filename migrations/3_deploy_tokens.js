
const ERC20Token = artifacts.require("./test/ERC20Token");
const ERC721Token = artifacts.require("./test/ERC721Token");

const liveNetworks = { rinkeby: true, kovan: true };
const gasPrice =  web3.utils.toWei('3', 'gwei');
const gas = 6700000;

module.exports = function (deployer, network) {
  console.log('deploy_tokens')
  deployer.then(async () => {
    const token20 = await deployer.deploy(ERC20Token, "Kirobo20Test", "KBD20T", { gas, gasPrice, overwrite: !liveNetworks[network] });
    const token721 = await deployer.deploy(ERC721Token, "Kirobo721Test", "KBD721T", { gas, gasPrice, overwrite: !liveNetworks[network] });
  });

}

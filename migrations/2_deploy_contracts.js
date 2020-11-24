var GasExpressPool = artifacts.require('./GasExpressPool.sol')

const json = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(json);
UniswapV2Factory.setProvider(this.web3._provider);

module.exports = async function(deployer, network, accounts) {
  // deployment steps
  // rinkeby
  await deployer.deploy(UniswapV2Factory, accounts[0], {from: accounts[0]})
  await deployer.deploy(GasExpressPool)

  // mainnet
  // deployer.deploy(SimpleMultiSig, 1)
}

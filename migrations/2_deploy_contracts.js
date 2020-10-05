var GasExpressPool = artifacts.require('./GasExpressPool.sol')

module.exports = function(deployer) {
  // deployment steps
  // rinkeby
  deployer.deploy(GasExpressPool)

  // mainnet
  // deployer.deploy(SimpleMultiSig, 1)
}

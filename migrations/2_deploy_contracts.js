var GasExpressPool = artifacts.require('./GasExpressPool.sol')
var Multicall = artifacts.require('./Multicall.sol')
var TestTokenA = artifacts.require('./TestTokenA.sol')
var TestTokenB = artifacts.require('./TestTokenB.sol')

const contract = require('@truffle/contract')

const factoryJson = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const UniswapV2Factory = contract(factoryJson)
UniswapV2Factory.setProvider(this.web3._provider)

const routerJson = require('@uniswap/v2-periphery/build/UniswapV2Router02.json')
const UniswapV2Router = contract(routerJson)
UniswapV2Router.setProvider(this.web3._provider)

const wethJson = require('@uniswap/v2-periphery/build/WETH9.json')
const WETH = contract(wethJson)
WETH.setProvider(this.web3._provider)

module.exports = async function(deployer, network, accounts) {
  // deployment steps

  await deployer.deploy(Multicall, { from: accounts[0] })
  const multicall = await Multicall.deployed()
  console.log(
    await multicall.aggregate.call([
      [
        Multicall.address,
        '0x4d2301cc00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1',
      ],
    ])
  )

  await deployer.deploy(TestTokenA, 'Token A', 'TA', { from: accounts[0] })
  await deployer.deploy(TestTokenB, 'Token B', 'TB', { from: accounts[0] })
  const tokenA = await TestTokenA.deployed()
  const tokenB = await TestTokenB.deployed()

  const weth = await deployer.deploy(WETH, { from: accounts[0] })

  const uniswapFactory = await deployer.deploy(UniswapV2Factory, accounts[0], {
    from: accounts[0],
  })
  const uniswapRouter = await deployer.deploy(
    UniswapV2Router,
    UniswapV2Factory.address,
    WETH.address,
    { from: accounts[0] }
  )

  await uniswapFactory.createPair(TestTokenA.address, TestTokenB.address, {
    from: accounts[0],
  })
  await uniswapFactory.createPair(TestTokenA.address, WETH.address, {
    from: accounts[0],
  })
  await uniswapFactory.createPair(TestTokenB.address, WETH.address, {
    from: accounts[0],
  })

  console.log('addLiquidityETH:approve....')
  await tokenA.approve(UniswapV2Router.address, '100000000000000')
  console.log(await tokenA.balanceOf.call(accounts[0]))
  console.log('addLiquidityETH....')
  //await uniswapRouter.addLiquidityETH(TestTokenA.address, '100', '100', '100', accounts[0], 1699853824, {from: accounts[0], value: '100'})

  await deployer.deploy(GasExpressPool, { from: accounts[0] })

  // write address data to interface
  const address = {
    multicall: Multicall.address,
    router: UniswapV2Router.address,
    factory: UniswapV2Factory.address,
    weth: WETH.address,
    tokenA: TestTokenA.address,
    tokenB: TestTokenB.address,
    shuttle: GasExpressPool.address,
  }

  var fs = require('fs')
  const util = require('util')
  const writeFile = util.promisify(fs.writeFile)
  const copyFile = util.promisify(fs.copyFile)
  await writeFile(
    '/home/hehe/projects/hack/fuck/src/constants/address.json',
    JSON.stringify(address)
  )
  await copyFile(
    '/home/hehe/projects/hack/Shuttle/build/contracts/GasExpressPool.json',
    '/home/hehe/projects/hack/fuck/src/constants/abis/shuttle.json'
  )
  // mainnet
  // deployer.deploy(SimpleMultiSig, 1)
}

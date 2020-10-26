const GasExpressPool = artifacts.require('GasExpressPool')
const amount = web3.utils.toWei('0.01', 'ether')
let instance

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}


async function execute(instance, num, isFarming) {
  let traders = []
  let value = []
  let farming= []

  let bytes = '0x'

  // 1 byte for numTrader
  bytes = bytes + web3.utils.padLeft(web3.utils.toHex(num), 2).slice(2)

  // 20 bytes for token addr, path ETH -> DAI
  bytes = bytes + 'c778417E063141139Fce010982780140Aa0cD5Ab' + 'c7AD46e0b8a400Bb3C915120d284AafbA8fc4735'

  // 2 bytes for gasPrice (in unit gwei)
  bytes = bytes + web3.utils.padLeft(web3.utils.toHex(1000), 4).slice(2)

  for (let i = 0; i < num; i++) {
    bytes = bytes + 'D3cEd3b16C8977ED0E345D162D982B899e978588'
  }

  for (let i = 0; i < num; i++) {
    // 32 bytes for value
    bytes = bytes + web3.utils.padLeft(web3.utils.toHex(amount), 64).slice(2)
  }

  for (let i = 0; i < num; i++) {
    // 1 byte for farming
    bytes = bytes + web3.utils.padLeft(web3.utils.toHex(isFarming), 2).slice(2)
  }

  let rv = await instance.parseTraderData.call(bytes)
  console.log(bytes, rv)
  //return instance.execute(bytes)
}

async function getGlobal() {
  const rewardPerShare = await instance.rewardPerShare.call()
  const totalSharesPerCycle = await instance.totalSharesPerCycle.call()
  const currentCycleStartingTime = await instance.currentCycleStartingTime.call()
  console.log(`rewardPerShare: ${rewardPerShare} totalSharesPerCycle ${totalSharesPerCycle} currentCycleStartingTime ${currentCycleStartingTime}`)
}

const NUM_TRADER = 8
module.exports = async function(callback) {
   instance = await GasExpressPool.deployed()
   //await instance.updateCycle()
   //await getGlobal()

   let gasPerTrader = []
   for (let i = 0; i < NUM_TRADER; i++) {
    console.log('before')
    //const receiptTrader = await instance.deposit(true, {value: amount})
    console.log(`done ${i}/${NUM_TRADER}`)
    //gasPerTrader.push(receiptTrader.receipt.gasUsed)
    //await sleep(1000)
  }

  const receipt = await execute(instance, NUM_TRADER, true)
  console.log(receipt)
  for(let i = 0; i < gasPerTrader.length; i++) {
    console.log('# trader: ', receipt.receipt.gasUsed/NUM_TRADER + gasPerTrader[i])
  }
  console.log('avg gas (execute): ', receipt.receipt.gasUsed/NUM_TRADER)
  callback()


  // perform actions
  /* GasExpressPool.deployed()
    .then(instance => {
      //return instance.reset()
      
      //return instance.deposit(true, {value: amount})
      //return execute(instance, 3, true)
      //return instance.traderSig.call(1)
      //return instance.getSig.call('0xD3cEd3b16C8977ED0E345D162D982B899e978588', amount, true)
    })
    .then(receipt => {
      console.log(receipt)
    })
    .catch(err => {
      console.log(err)
    }) */
}

// 0xab82e7d4b1f1d34d
// 0xab82e7d4b1f1d34d

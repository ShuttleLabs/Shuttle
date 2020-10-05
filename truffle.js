// babel does not transpile js in node_modules, we need to ignore them
require('babel-register')({
  ignore: /node_modules\/(?!openzeppelin-solidity\/test\/helpers)/
})
require('babel-polyfill')

const PrivateKeyProvider = require('truffle-privatekey-provider')
const fs = require('fs')

let privateKey = ''

if (fs.existsSync('privateKey.txt')) {
  privateKey = fs
    .readFileSync('privateKey.txt')
    .toString()
    .split('\n')[0]
}

module.exports = {
  quiet: false,
  networks: {
    development: {
      host: 'http://18.235.170.28',
      port: 8545,
      network_id: '1' // Match any network id
    },
    rinkeby: {
      provider: function() {
        return new PrivateKeyProvider(
          privateKey,
          'https://rinkeby.infura.io/v3/046d597601b14bb3ac0c73fa71f5ff23'
        )
      },
      network_id: '4',
      gas: 6000000,
      gasPrice: 100000000000
    },
    mainnet: {
      host: '18.235.170.28',
      port: 8545,
      network_id: '1',
      gas: 7000000,
      gasPrice: 10000000000
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions: {
      currency: 'USD',
      gasPrice: 20
    } // See options below
  },
  compilers: {
    solc: {
      version: "0.6.6",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1500
        }
      }
    }
 }
}

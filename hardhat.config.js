/* global usePlugin task module ethers require process */

require('@nomiclabs/buidler-waffle')
require("@nomiclabs/hardhat-ethers");
require('dotenv').config()

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(await account.getAddress())
  }
})

// You HAVE to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more

const config = {
  defaultNetwork: "localhost",
  networks: {},
    // This is a sample solc configuration that specifies which version of solc to use
  solidity: {
    version: '0.6.8'
  }
}

const INFURA_PROJECT_ID = process.env['INFURA_PROJECT_ID'] || "46801402492348e480a7e18d9830eab8"
const ROPSTEN_PRIVATE_KEY = process.env['ROPSTEN_PRIVATE_KEY']
if (ROPSTEN_PRIVATE_KEY) {
  config.networks.ropsten = {
    url: `https://ropsten.infura.io/v3/${INFURA_PROJECT_ID}`,
    accounts: [
      `0x${ROPSTEN_PRIVATE_KEY}`,
    ]
  }
}

module.exports = config

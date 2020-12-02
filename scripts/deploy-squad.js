/* global ethers process require */

// const hre = require("hardhat")
const crypto = require("crypto")
const defs = require("./default-defs.js")

// We require the Buidler Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `buidler run <script>` you'll find the Buidler
// Runtime Environment's members available in the global scope.
// const bre = require('@nomiclabs/buidler')

async function main () {
  // Buidler always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await bre.run('compile');
  // const ethers = hre.ethers

  const treasuryAddress = process.env['TREASURY_ADDRESS']
  if (treasuryAddress === undefined) {
    throw new Error("TREASURY_ADDRESS required")
  }

  const userAddress = process.env['USER_ADDRESS']
  if (userAddress === undefined) {
    throw new Error("USER_ADDRESS required")
  }

  const networkFeeRate = process.env['NETWORK_FEE_RATE'] || "0"
  const maxNetworkFeeRate = process.env['MAX_NETWORK_FEE_RATE'] || "1000"

  let tokenClaimCheckAddress = process.env['TOKEN_CLAIM_CHECK_ADDRESS']
  let curveAddress = process.env['CURVE_ADDRESS']
  let reserveTokenAddress = process.env['RESERVE_TOKEN_ADDRESS']
  let bondingCurveFactoryAddress = process.env['BONDING_CURVE_FACTORY_ADDRESS']
  let bondingCurveFactory

  // We get the contract to deploy
  if (tokenClaimCheckAddress === undefined) {
    const TokenClaimCheck = await ethers.getContractFactory('TokenClaimCheck')
    const tokenClaimCheck = await TokenClaimCheck.deploy("Token Claim Check", "TCC")
    await tokenClaimCheck.deployed()
    tokenClaimCheckAddress = tokenClaimCheck.address
    console.log('ClaimCheck deployed to:', tokenClaimCheckAddress)
  }
  if (curveAddress === undefined) {
    const LinearCurve = await ethers.getContractFactory('LinearCurve')
    const linearCurve = await LinearCurve.deploy()
    await linearCurve.deployed()
    curveAddress = linearCurve.address
    console.log("LinearCurve deployed to:", curveAddress)
  }
  if (reserveTokenAddress === undefined) {
    const ReserveToken = await ethers.getContractFactory('ERC20Managed')
    const reserveToken = await ReserveToken.deploy('Managed Token', 'MT')
    await reserveToken.deployed()
    reserveTokenAddress = reserveToken.address
    console.log("ManagedReserveToken deployed to:", reserveTokenAddress)
    await reserveToken.mint(treasuryAddress, ethers.utils.parseEther('10000'))
    console.log("Minted reserve tokens to:", treasuryAddress)
    await reserveToken.mint(userAddress, ethers.utils.parseEther('10000'))
    console.log("Minted reserve tokens to:", userAddress)
  }
  if (bondingCurveFactoryAddress === undefined) {
    const BondingCurveFactory = await ethers.getContractFactory('BondingCurveFactory')
    bondingCurveFactory = await BondingCurveFactory.deploy(reserveTokenAddress)
    bondingCurveFactoryAddress = bondingCurveFactory.address
    console.log("BondingCurveFactory deployed to:", bondingCurveFactoryAddress)
  }

  const SquadController = await ethers.getContractFactory('SquadController')
  const squadController = await SquadController.deploy(
    bondingCurveFactoryAddress,
    tokenClaimCheckAddress,
    networkFeeRate,
    maxNetworkFeeRate,
    treasuryAddress,
    curveAddress
  )
  await squadController.deployed()
  console.log('SquadController deployed to:', squadController.address)

  console.log('Accounting deployed to:', await squadController.accounting())

  console.log("Transfering factory ownership to controller")
  await bondingCurveFactory.transferOwnership(squadController.address)
  console.log("done!")

  // Submit default contributions
  let exampleId
  for(let i = 0; i < defs.length; i++) {
    const def = defs[i]
    def.id = '0x'+crypto.createHash('sha256').update(JSON.stringify(def)).digest('hex')
    exampleId = def.id
    let name
    if (def.Component) {
      name = def.Component.name
    } 
    if (def.Format) {
      name = def.Format.name
    }
    if (def.Game) {
      name = def.Game.name
    }
    console.log("Trying to submit new contribution:", name, def.id)
    await squadController.newContribution(
      def.id,
      treasuryAddress,
      0,
      ethers.utils.parseEther('1'),
      name,
      name.slice(0, 2),
      JSON.stringify(def)
    )
  }
  console.log('BOOL', await squadController.exists(exampleId), exampleId)
  console.log('Contributions submitted')
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })

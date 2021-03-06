/* global ethers process require */

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

  const treasuryAddress = process.env['TREASURY_ADDRESS']
  if (treasuryAddress === undefined) {
    throw new Error("TREASURY_ADDRESS required")
  }
  const networkFeeRate = process.env['NETWORK_FEE_RATE'] || "0"
  const maxNetworkFeeRate = process.env['MAX_NETWORK_FEE_RATE'] || "1000"

  // TEMPORARY DEFAULTS FOR ROPSTEN TEST
  let tokenClaimCheckAddress = process.env['TOKEN_CLAIM_CHECK_ADDRESS'] || "0x3e671040ffb4BbB9d93395f64b944901580Ba8A4"
  let curveAddress = process.env['CURVE_ADDRESS'] || "0xE0A4DDA27A32124396f8D882C81Bf8dEece83D78"
  let reserveTokenAddress = process.env['RESERVE_TOKEN_ADDRESS'] || "0xa34eDEA5857c7DD9BD2EB6090a8F25043856D878"
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

  console.log(
    'bondingCurveFactory.transferOwnership',
    await bondingCurveFactory.transferOwnership(squadController.address)
  )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })

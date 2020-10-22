/* global process ethers */

async function main() {
  const to = process.env['MINT_RESERVE_TO']
  if (to === undefined) {
    throw new Error("please set MINT_RESERVE_TO")
  }

  const ReserveToken = await ethers.getContractFactory('ERC20Managed')
  const [Owner] = await ethers.getSigners()
  const reserveToken = new ethers.Contract(
    '0x22bEc4c0CF61796761b8fae292C402ebF41f0D86',
    ReserveToken.interface,
    Owner,
  )
  const amount = ethers.utils.parseEther("100")
  await reserveToken.mint(to, amount)
  console.log(`Minted ${amount.toString()} to ${to}`)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })

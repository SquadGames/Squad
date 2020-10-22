/* global process ethers */

async function main() {
  const SquadController = await ethers.getContractFactory('SquadController')
  const [Alice] = await ethers.getSigners()
  const squadController = new ethers.Contract(
    '0x19Ce2C83f2F4Da92ECbEd17606f4c51f04942f76',
    SquadController.interface,
    Alice
  )

  const contributionId = ethers.utils.formatBytes32String(Date.now().toString())
  const beneficiary = await Alice.getAddress()
  const feeRate = 200
  const purchasePrice = 10
  const name = "test contribution"
  const symbol = "TG"
  const metadata = JSON.stringify({game: "SquadChess", type: "Format"})

  console.log(
    "squadController.bondingCurveFactory:",
    await squadController.bondingCurveFactory()
  )

  console.log(
    "squadController.curve:", await squadController.curve()
  )

  console.log(
    "Params:",
    contributionId,
    beneficiary,
    feeRate,
    purchasePrice,
    name,
    symbol,
    metadata
  )

  console.log(
    await squadController.newContribution(
      contributionId,
      beneficiary,
      feeRate,
      purchasePrice,
      name,
      symbol,
      metadata,
      {gasLimit: 4000000}
    )
  )
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })

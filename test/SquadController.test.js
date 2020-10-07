/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('SquadController', () => {

  let Owner, Alice, Bob, Treasury
  let owner, alice, bob, treasury
  let squadAlice, squadBob, squadTreasury
  let squadController
  let reserveToken
  let curve
  let aliceId

  const networkFee = 100

  beforeEach(async () => {
    [Owner, Alice, Bob, Treasury] = await ethers.getSigners()
    owner = await Owner.getAddress()
    alice = await Alice.getAddress()
    bob = await Bob.getAddress()
    treasury = await Treasury.getAddress()

    const ReserveToken = await ethers.getContractFactory("ERC20Managed")
    reserveToken = await ReserveToken.deploy("TestReserveToken", "TRT")

    const SquadController = await ethers.getContractFactory("SquadController")
    squadController = await SquadController.deploy(reserveToken.address, networkFee, treasury)

    const Curve = await ethers.getContractFactory("LinearCurve")
    curve = await Curve.deploy()

    await squadController.deployed()
    await curve.deployed()
    await reserveToken.deployed()

    squadAlice = squadController.connect(Alice)
    squadBob = squadController.connect(Bob)
    squadTreasury = squadController.connect(Treasury)

    aliceId = ethers.utils.formatBytes32String("aliceId")
    const aliceFee = ethers.BigNumber.from("200")
    const alicePurchasePrice = ethers.utils.parseEther("10")
    const name = "Contribution A"
    const symbol = "CA"
    const contributionURI = `squad.games/contributions/${aliceId}`
    const metadata = JSON.stringify({name, symbol, a: "a"})
    await expect(
      squadAlice.newContribution(
        aliceId,
        alice,
        aliceFee,
        alicePurchasePrice,
        curve.address,
        name,
        symbol,
        contributionURI,
        metadata
      )
    ).to.emit(squadController, "NewContribution")

  })

  it("Accepts new contributions", async () => {

    assert(squadController.exists(aliceId), "Controbution token does not exist")

    // it uses the right curve
    assert(
      (await squadController.price(aliceId, 0, ethers.utils.parseEther("10"))).eq(
        await curve.price(0, ethers.utils.parseEther("10"))),
      "price mismatch",
    )

    // it recorded the correct details
    assert(
      (await squadController.contributions(aliceId)).beneficiary === alice,
      "Incorrect beneficiary"
    )
  })

  it.skip("Beneficiary (only) sets the purchase price", async () => {
    // Experiment probably works fine without this!!!
    assert(false)
  })

  it("Sells license NFTs for the purchase price to buyers", async () => {
    const purchasePrice = (await squadBob.contributions(aliceId)).
    const amount = 
    await expect(
      squadBob.buy(
        aliceId,
        amount,
        maxPrice,
      )
    ).to.emit(squadController, "Buy").withArgs(aliceId)

    assert(false)
  })

  it("Redeems license NFTs from holders", async () => {
    assert(false)
  })

  it("Owner sets the network fee up to the limit", async () => {
    assert(false)
  })

  it("Beneficiary withdraws their fee and pays network fee", async () => {
    assert(false)
  })

  it("Buys back contribution tokens", async () => {
    assert(false)
  })
})

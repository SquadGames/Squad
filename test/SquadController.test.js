/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')
const { linearCurveAmount } = require('../utils.js')

describe('SquadController', () => {
  let Owner, Alice, Bob, Treasury
  let owner, alice, bob, treasury
  let squadController, reserveToken, curve, claimCheck
  let squadAlice, squadBob, squadTreasury, claimCheckBob, reserveTokenBob
  let aliceId, aliceTokenName

  const networkFee = 100
  const maxNetworkFee = 1000

  beforeEach(async () => {
    [Owner, Alice, Bob, Treasury] = await ethers.getSigners()
    owner = await Owner.getAddress()
    alice = await Alice.getAddress()
    bob = await Bob.getAddress()
    treasury = await Treasury.getAddress()

    const ReserveToken = await ethers.getContractFactory('ERC20Managed')
    reserveToken = await ReserveToken.deploy('Test Reserve Token', 'TRT')

    const ClaimCheck = await ethers.getContractFactory('TokenClaimCheck')
    claimCheck = await ClaimCheck.deploy('Test Claim Check', 'TCC')

    const SquadController = await ethers.getContractFactory('SquadController')
    squadController = await SquadController.deploy(
      reserveToken.address,
      claimCheck.address,
      networkFee,
      maxNetworkFee,
      treasury
    )

    const Curve = await ethers.getContractFactory('LinearCurve')
    curve = await Curve.deploy()

    squadAlice = squadController.connect(Alice)
    squadBob = squadController.connect(Bob)
    squadTreasury = squadController.connect(Treasury)
    claimCheckBob = claimCheck.connect(Bob)
    reserveTokenBob = reserveToken.connect(Bob)

    aliceId = ethers.utils.formatBytes32String('aliceId')
    const aliceFee = ethers.BigNumber.from('200')
    const alicePurchasePrice = ethers.utils.parseEther('10')
    aliceTokenName = 'Contribution A'
    const symbol = 'CA'
    const contributionURI = `squad.games/contributions/${aliceId}`
    const metadata = JSON.stringify({ name: aliceTokenName, symbol, a: 'a' })
    await expect(
      squadAlice.newContribution(
        aliceId,
        alice,
        aliceFee,
        alicePurchasePrice,
        curve.address,
        aliceTokenName,
        symbol,
        contributionURI,
        metadata
      )
    ).to.emit(squadController, 'NewContribution')
  })

  it('Accepts new contributions', async () => {
    assert(squadController.exists(aliceId), 'Controbution token does not exist')

    // it uses the right curve
    assert(
      (await squadController.price(aliceId, 0, ethers.utils.parseEther('10'))).eq(
        await curve.price(0, ethers.utils.parseEther('10'))),
      'price mismatch'
    )

    // it recorded the correct details
    assert(
      (await squadController.contributions(aliceId)).beneficiary === alice,
      'Incorrect beneficiary'
    )
  })

  it.skip('Beneficiary (only) sets the purchase price', async () => {
    // Experiment probably works fine without this!!!
    assert(false)
  })

  async function setUpForBuyLicense() {
    const aliceContribution = await squadBob.contributions(aliceId)
    const aliceContinuousToken = await squadBob.continuousTokens(aliceId)
    const aliceToken = new ethers.Contract(
      aliceContinuousToken.token,
      reserveToken.interface,
      Alice
    )
    const amount = linearCurveAmount(
      await aliceToken.totalSupply(), aliceContribution.purchasePrice
    )
    const maxPrice = aliceContribution.purchasePrice.add(
      ethers.utils.parseEther('0.001')
    )
    await reserveToken.mint(bob, maxPrice)
    await reserveTokenBob.approve(squadController.address, maxPrice)
    return { amount, maxPrice, aliceContinuousToken }
  }

  it('Sells license NFTs for the purchase price to buyers', async () => {
    const { amount, maxPrice, aliceContinuousToken } = await setUpForBuyLicense()
    await expect(
      squadBob.buyLicense(
        aliceId,
        amount,
        maxPrice,
        "test/token/uri",
      )
    ).to.emit(squadController, 'BuyLicense')

    // Bob should have the first NFT
    const bobsNFTid = await claimCheckBob.tokenOfOwnerByIndex(bob, 0)
    assert(bobsNFTid.toString() == '1', 'NFT not owned after buy')

    // Bobs NFT should claim `amount` of `aliceContinuousToken`
    const bobsClaim = await claimCheckBob.claims(bobsNFTid)
    assert(bobsClaim.amount.eq(amount), 'NFT claims wrong amount')
    assert(bobsClaim.token === aliceContinuousToken.token, 'NFT claims wrong token')

    // Controller should report that Bob is a license holder
    assert(
      await squadAlice.holdsLicense(aliceId, bobsNFTid, bob),
      'Controller misreports license holder'
    )
  })

  it("won't sell if it doesn't exist", async () => {
    const doesNotExistId = ethers.utils.formatBytes32String('doesnotexist')
    await expect(
      squadBob.buyLicense(
        doesNotExistId,
        0,
        0,
        "test/token/uri",
      )
    ).to.be.revertedWith(
      "ContinuousTokenFactory: continuous token does not exist"
    )
  })

  it('Owner sets the network fee up to the limit', async () => {
    const aboveMaxNetworkFee = maxNetworkFee + 1
    await expect(
      squadController.setNetworkFee(networkFee, aboveMaxNetworkFee)
    ).to.be.revertedWith("SquadController: cannot set fee higer than max")
    await expect(
      squadAlice.setNetworkFee(networkFee, maxNetworkFee)
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      squadController.setNetworkFee(networkFee, maxNetworkFee)
    ).to.emit(squadController, "SetNetworkFee").withArgs(networkFee, maxNetworkFee)
    assert(
      await squadController.networkFee() == maxNetworkFee,
      "Network fee failed to set"
    )
  })

  it('Beneficiary withdraws their fee and pays network fee', async () => {
    assert(false)
  })

  it('Buys back contribution tokens', async () => {
    assert(false)
  })
})

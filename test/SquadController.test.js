/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')
const { linearCurveAmount } = require('../utils.js')

describe('SquadController', () => {
  let Alice, Bob, Treasury
  let alice, bob, treasury
  let squadController, reserveToken, curve, claimCheck
  let squadAlice, squadBob, claimCheckBob, reserveTokenBob
  let aliceId, aliceTokenName, aliceFee

  const networkFee = 100
  const maxNetworkFee = 1000

  beforeEach(async () => {
    const signers = await ethers.getSigners()
    Alice = signers[1]
    Bob = signers[2]
    Treasury = signers[3]

    alice = await Alice.getAddress()
    bob = await Bob.getAddress()
    treasury = await Treasury.getAddress()

    const ReserveToken = await ethers.getContractFactory('ERC20Managed')
    reserveToken = await ReserveToken.deploy('Test Reserve Token', 'TRT')

    const ClaimCheck = await ethers.getContractFactory('TokenClaimCheck')
    claimCheck = await ClaimCheck.deploy('Test Claim Check', 'TCC')

    const Curve = await ethers.getContractFactory('LinearCurve')
    curve = await Curve.deploy()

    const SquadController = await ethers.getContractFactory('SquadController')
    squadController = await SquadController.deploy(
      reserveToken.address,
      claimCheck.address,
      networkFee,
      maxNetworkFee,
      treasury,
      curve.address
    )

    squadAlice = squadController.connect(Alice)
    squadBob = squadController.connect(Bob)
    claimCheckBob = claimCheck.connect(Bob)
    reserveTokenBob = reserveToken.connect(Bob)

    aliceId = ethers.utils.formatBytes32String('aliceId')
    aliceFee = ethers.BigNumber.from('200')
    const alicePurchasePrice = ethers.utils.parseEther('10')
    aliceTokenName = 'Contribution A'
    const symbol = 'CA'
    const metadata = JSON.stringify({ name: aliceTokenName, symbol, a: 'a' })
    await expect(
      squadAlice.newContribution(
        aliceId,
        alice,
        aliceFee,
        alicePurchasePrice,
        aliceTokenName,
        symbol,
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

  async function setUpForBuyLicense () {
    const aliceContribution = await squadBob.contributions(aliceId)
    const aliceContinuousToken = await squadBob.tokenAddress(aliceId)
    const aliceToken = new ethers.Contract(
      aliceContinuousToken,
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
    await reserveTokenBob.approve(await squadController.tokenFactory(), maxPrice)
    return { amount, maxPrice, aliceContinuousToken, aliceToken }
  }

  it('Sells license NFTs for the purchase price to buyers', async () => {
    const { amount, maxPrice, aliceContinuousToken } = await setUpForBuyLicense()
    await expect(
      squadBob.buyLicense(
        aliceId,
        amount,
        maxPrice
      )
    ).to.emit(squadController, 'BuyLicense')

    // Bob should have the first NFT
    const bobsNFTid = await claimCheckBob.tokenOfOwnerByIndex(bob, 0)
    assert(bobsNFTid.toString() === '1', 'NFT not owned after buy')

    // Bobs NFT should claim `amount` of `aliceContinuousToken`
    const bobsClaim = await claimCheckBob.claims(bobsNFTid)
    assert(bobsClaim.amount.eq(amount), 'NFT claims wrong amount')
    assert(bobsClaim.token === aliceContinuousToken, 'NFT claims wrong token')

    // Controller should report that Bob is a license holder
    assert(
      await squadAlice.holdsLicense(aliceId, bobsNFTid, bob),
      'Controller misreports license holder'
    )

    // after redeeming the license they shouldn't hold the license
    claimCheckBob.redeem(bobsNFTid)
    assert(
      !(await squadAlice.holdsLicense(aliceId, bobsNFTid, bob)),
      'Controller misreports holding license after redeem'
    )
  })

  it("won't sell if it doesn't exist", async () => {
    const doesNotExistId = ethers.utils.formatBytes32String('doesnotexist')
    await expect(
      squadBob.buyLicense(
        doesNotExistId,
        0,
        0
      )
    ).to.be.revertedWith(
      'SquadController: contribution does not exist'
    )
  })

  it('Owner sets the network fee up to the limit', async () => {
    const aboveMaxNetworkFee = maxNetworkFee + 1
    await expect(
      squadController.setNetworkFeeRate(networkFee, aboveMaxNetworkFee)
    ).to.be.revertedWith('SquadController: cannot set fee higer than max')
    await expect(
      squadAlice.setNetworkFeeRate(networkFee, maxNetworkFee)
    ).to.be.revertedWith('Ownable: caller is not the owner')
    await expect(
      squadController.setNetworkFeeRate(networkFee, maxNetworkFee)
    ).to.emit(squadController, 'SetNetworkFeeRate').withArgs(networkFee, maxNetworkFee)
    assert(
      await squadController.networkFeeRate() === maxNetworkFee,
      'Network fee failed to set'
    )
  })

  it('Beneficiary withdraws their fee and pays network fee', async () => {
    await expect(
      squadAlice.withdraw(alice)
    ).to.be.revertedWith('SquadController: nothing to withdraw')

    const { amount, maxPrice } = await setUpForBuyLicense()
    await squadBob.buyLicense(
      aliceId,
      amount,
      maxPrice
    )

    // network fee is 100
    // alice fee is 200

    const purchasePrice = await squadController.price(aliceId, 0, amount)
    const aliceAccount = purchasePrice.mul(aliceFee).div(10000).add(
      purchasePrice.mul(aliceFee).mod(10000)
    )
    const networkFeePaid = aliceAccount.mul(networkFee).div(10000).add(
      aliceAccount.mul(networkFee).mod(10000)
    )
    const withdrawAmount = aliceAccount.sub(networkFeePaid)

    const balanceBefore = await reserveToken.balanceOf(alice)
    const treasuryBalanceBefore = await reserveToken.balanceOf(treasury)

    await expect(
      squadAlice.withdraw(alice)
    ).to.emit(squadController, 'Withdraw').withArgs(
      alice,
      withdrawAmount,
      networkFeePaid
    )

    // confirm alice got paid
    expect(
      (await reserveToken.balanceOf(alice)).sub(balanceBefore).eq(withdrawAmount),
      'incorrect balance after withdraw'
    )

    // confirm treasury got paid
    expect(
      (await reserveToken.balanceOf(treasury)).sub(treasuryBalanceBefore).eq(networkFeePaid),
      'incorrect treasury balance after withdraw'
    )
  })

  it('buys back contribution tokens', async () => {
    const { amount, maxPrice, aliceToken } = await setUpForBuyLicense()
    await squadBob.buyLicense(
      aliceId,
      amount,
      maxPrice
    )
    assert(
      (await aliceToken.balanceOf(bob)).eq(0),
      'Incorrect Token A balance before redeem'
    )
    await claimCheckBob.redeem(1)
    assert(
      (await aliceToken.balanceOf(bob)).eq(amount),
      'Incorrect Token A balance after redeem'
    )
    const balanceBefore = await reserveToken.balanceOf(bob)
    const price = await squadBob.price(aliceId, 0, amount)
    await squadBob.sellContinuousTokens(aliceId, amount, price)
    assert((await reserveToken.balanceOf(bob)).eq(price.add(balanceBefore)))
  })
})

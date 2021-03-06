/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')
const { linearCurveAmount } = require('../utils.js')

describe('SquadController', () => {
  let Alice, Bob, Treasury
  let alice, bob, treasury
  let squadController, reserveToken, curve, claimCheck
  let squadAlice, squadBob, claimCheckBob, reserveTokenBob
  let aliceId, aliceTokenName, aliceFee

  const networkFeeRate = 100
  const maxNetworkFeeRate = 1000

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

    const BondingCurveFactory = await ethers.getContractFactory('BondingCurveFactory')
    const bondingCurveFactory = await BondingCurveFactory.deploy(reserveToken.address)

    const SquadController = await ethers.getContractFactory('SquadController')
    squadController = await SquadController.deploy(
      bondingCurveFactory.address,
      claimCheck.address,
      networkFeeRate,
      maxNetworkFeeRate,
      treasury,
      curve.address
    )

    bondingCurveFactory.transferOwnership(squadController.address)

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
      (await squadController.priceOf(aliceId, 0, ethers.utils.parseEther('10'))).eq(
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
    await reserveTokenBob.approve(await squadController.bondingCurveFactory(), maxPrice)
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
    const aboveMaxNetworkFee = maxNetworkFeeRate + 1
    await expect(
      squadController.setNetworkFeeRate(networkFeeRate, aboveMaxNetworkFee)
    ).to.be.revertedWith('SquadController: cannot set fee higer than max')
    await expect(
      squadAlice.setNetworkFeeRate(networkFeeRate, maxNetworkFeeRate)
    ).to.be.revertedWith('Ownable: caller is not the owner')
    await expect(
      squadController.setNetworkFeeRate(networkFeeRate, maxNetworkFeeRate)
    ).to.emit(squadController, 'SetNetworkFeeRate').withArgs(networkFeeRate, maxNetworkFeeRate)
    assert(
      await squadController.networkFeeRate() === maxNetworkFeeRate,
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

    const purchasePrice = await squadController.priceOf(aliceId, 0, amount)
    const aliceAccount = purchasePrice.mul(aliceFee).div(10000).add(
      purchasePrice.mul(aliceFee).mod(10000)
    )
    const networkFeePaid = aliceAccount.mul(networkFeeRate).div(10000).add(
      aliceAccount.mul(networkFeeRate).mod(10000)
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
    const price = await squadBob.priceOf(aliceId, 0, amount)
    const feeRate = (await squadBob.contributions(aliceId)).feeRate

    /** * This is how to calculate what the exact fee is going to be ***/
    const fee = price.mul(feeRate).div(10000).add(price.mul(feeRate).mod(100000))
    /** * This is how to calculate what the exact fee is going to be ***/

    const exactPrice = price.sub(fee)
    await squadBob.sellTokens(aliceId, amount, exactPrice)
    assert((await reserveToken.balanceOf(bob)).eq(exactPrice.add(balanceBefore)),
      'incorrect balance after withdraw'
    )
  })

  it('recovers rounding dust', async () => {
    // Setup: buy, redeem, and sell should leave some rounding dust
    const { amount, maxPrice } = await setUpForBuyLicense()
    await squadBob.buyLicense(
      aliceId,
      amount,
      maxPrice
    )
    const {
      amount: amount2,
      maxPrice: maxPrice2
    } = await setUpForBuyLicense()
    await squadBob.buyLicense(
      aliceId,
      amount2,
      maxPrice2
    )
    await claimCheckBob.redeem(2)
    await claimCheckBob.redeem(1)

    const price = await squadBob.priceOf(aliceId, 0, amount)
    const feeRate = (await squadBob.contributions(aliceId)).feeRate
    const exactFee = price.mul(feeRate).div(10000).add(price.mul(feeRate).mod(100000))
    const minPrice = price.sub(exactFee).sub(100)
    await squadBob.sellTokens(aliceId, amount, minPrice)

    const price2 = await squadBob.priceOf(aliceId, 0, amount2)
    const feeRate2 = (await squadBob.contributions(aliceId)).feeRate
    const exactFee2 = price2.mul(feeRate2).div(10000).add(price2.mul(feeRate).mod(100000))
    const minPrice2 = price2.sub(exactFee2).sub(100)
    await squadBob.sellTokens(aliceId, amount2, minPrice2)

    await squadBob.withdraw(alice)

    // check how much dust is left
    const dustLeft = await reserveToken.balanceOf(
      await squadController.bondingCurveFactory()
    )

    assert(dustLeft.gt(0), 'No dust left')
    assert(dustLeft.lt(10000), 'Too much dust left')

    // recover dust
    const treasuryBalance = await reserveToken.balanceOf(treasury)
    await expect(
      squadController.recoverReserveDust()
    ).to.emit(squadController, 'RecoverReserveDust').withArgs(
      treasury, dustLeft
    )
    assert(
      (await reserveToken.balanceOf(treasury)).eq(
        treasuryBalance.add(dustLeft)
      ),
      'Incorrect treasury balance after dust recovery'
    )
  })
})

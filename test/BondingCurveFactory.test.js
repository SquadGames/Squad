/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('BondingCurveFactory', () => {
  let Owner, owner, Alice
  let reserveToken, linearCurve, bondingCurveFactory
  let factoryOwner, factoryAlice, reserveOwner

  beforeEach(async () => {
    // Wallets
    const wallets = await ethers.getSigners()
    Owner = wallets[0]
    Alice = wallets[1]
    owner = await Owner.getAddress()

    // Deploy contracts
    const ERC20Managed = await ethers.getContractFactory('ERC20Managed')
    reserveToken = await ERC20Managed.deploy('reserve token', 'RSV')
    const LinearCurve = await ethers.getContractFactory('LinearCurve')
    linearCurve = await LinearCurve.deploy()
    const BondingCurveFactory = await ethers.getContractFactory('BondingCurveFactory')
    bondingCurveFactory = await BondingCurveFactory.deploy(reserveToken.address)
    await reserveToken.deployed()
    await linearCurve.deployed()
    await bondingCurveFactory.deployed()

    // Connect
    reserveOwner = reserveToken.connect(Owner)
    factoryOwner = bondingCurveFactory.connect(Owner)
    factoryAlice = bondingCurveFactory.connect(Alice)
  })

  it('allows creating, buying, and selling tokens', async () => {
    const name = 'alice coin'
    const id = ethers.utils.formatBytes32String(name)
    await factoryAlice.newBondingCurve(
      id,
      name,
      'ALC',
      linearCurve.address
    )
    const tokenAddress = (await factoryAlice.bondingCurves(id)).token
    const token = new ethers.Contract(tokenAddress, reserveToken.interface, Owner)
    assert(
      (await token.totalSupply()).eq(0),
      'New token not created successfully'
    )

    // buy tokens
    let ownerBalance = await token.balanceOf(owner)
    assert(ownerBalance.eq(0), "Owner's starting balance not 0")

    const buyAmount = ethers.constants.WeiPerEther.mul(10)
    let price = await factoryOwner.priceOf(id, 0, buyAmount)

    await reserveToken.mint(owner, price)
    await reserveOwner.approve(factoryOwner.address, price)
    await expect(factoryOwner.buy(
      id,
      buyAmount,
      owner,
      owner
    )).to.emit(factoryOwner, 'Buy').withArgs(
      id,
      name,
      buyAmount,
      price,
      owner,
      owner
    )
    ownerBalance = await token.balanceOf(owner)
    assert(ownerBalance.eq(buyAmount), "Owner's post-buy balance not buy amount")

    // sell tokens
    const sellAmount = ethers.constants.WeiPerEther.mul(8)
    const expectedSupply = (await token.totalSupply()).sub(sellAmount)
    price = await factoryOwner.priceOf(id, expectedSupply, sellAmount)

    await expect(factoryOwner.sell(
      id,
      sellAmount,
      0,
      price,
      owner,
      owner
    )).to.emit(factoryOwner, 'Sell').withArgs(
      id,
      name,
      sellAmount,
      0,
      price,
      owner,
      owner
    )
    ownerBalance = await token.balanceOf(owner)
    assert(ownerBalance.eq(expectedSupply), 'Sell failed')
  })

  it.skip('can buy for others', () => {
    assert(false)
  })
})

/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('ContinuousTokenFactory', () => {
  let Owner, Alice, Bob
  let owner, alice, bob
  let reserveToken, linearCurve, continuousTokenFactory
  let reserveOwner, reserveAlice, reserveBob
  let factoryOwner, factoryAlice, factoryBob

  beforeEach(async () => {
    // Wallets
    const wallets = await ethers.getSigners()
    Owner = wallets[0]
    Alice = wallets[1]
    Bob = wallets[2]
    owner = await Owner.getAddress()
    alice = await Alice.getAddress()
    bob = await Bob.getAddress()

    // Deploy contracts
    const ERC20Managed = await ethers.getContractFactory('ERC20Managed')
    reserveToken = await ERC20Managed.deploy('reserve token', 'RSV')
    const LinearCurve = await ethers.getContractFactory('LinearCurve')
    linearCurve = await LinearCurve.deploy()
    const ContinuousTokenFactory = await ethers.getContractFactory('ContinuousTokenFactoryMock')
    continuousTokenFactory = await ContinuousTokenFactory.deploy(reserveToken.address)
    await reserveToken.deployed()
    await linearCurve.deployed()
    await continuousTokenFactory.deployed()

    // Connect
    reserveOwner = reserveToken.connect(Owner)
    reserveAlice = reserveToken.connect(Alice)
    reserveBob = reserveToken.connect(Bob)
    factoryOwner = continuousTokenFactory.connect(Owner)
    factoryAlice = continuousTokenFactory.connect(Alice)
    factoryBob = continuousTokenFactory.connect(Bob)
  })

  it('allows creating, buying, and selling tokens', async () => {
    const name = 'alice coin'
    const id = ethers.utils.formatBytes32String(name)
    await expect(factoryAlice.newContinuousToken(
      id,
      name,
      'ALC',
      linearCurve.address
    )).to.emit(factoryAlice, 'NewContinuousToken')
    const tokenAddress = await factoryAlice.tokenAddress(id)
    const token = new ethers.Contract(tokenAddress, reserveToken.interface, Bob)
    assert(
      (await token.totalSupply()).eq(0),
      'New token not created successfully'
    )

    // buy tokens
    let bobBalance = await token.balanceOf(bob)
    assert(bobBalance.eq(0), "Bob's starting balance not 0")

    const buyAmount = ethers.constants.WeiPerEther.mul(10)
    const maxPrice = await factoryBob.price(id, 0, buyAmount)

    await reserveToken.mint(bob, maxPrice)
    await reserveBob.approve(factoryBob.address, maxPrice)
    await expect(factoryBob.buy(
      id,
      buyAmount,
      maxPrice,
      bob,
      bob,
    )).to.emit(factoryBob, 'Buy').withArgs(
      id,
      name,
      buyAmount,
      maxPrice,
      bob,
      bob,
    )
    bobBalance = await token.balanceOf(bob)
    assert(bobBalance.eq(buyAmount), "Bob's post-buy balance not buy amount")

    // sell tokens
    const sellAmount = ethers.constants.WeiPerEther.mul(8)
    const expectedSupply = (await token.totalSupply()).sub(sellAmount)
    const minPrice = await factoryBob.price(id, expectedSupply, sellAmount)

    await expect(factoryBob.sell(
      id,
      sellAmount,
      minPrice,
      bob
    )).to.emit(factoryBob, 'Sell').withArgs(
      id,
      name,
      sellAmount,
      minPrice,
      bob
    )
    bobBalance = await token.balanceOf(bob)
    assert(bobBalance.eq(expectedSupply), 'Sell failed')
  })

  it.skip("can buy for others", () => {
    assert(false)
  });
})

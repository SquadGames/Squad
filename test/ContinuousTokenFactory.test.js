/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('ContinuousTokenFactory', () => {
  let owner, alice, bob
  let reserveToken, linearCurve, continuousTokenFactory
  let reserveOwner, reserveAlice, reserveBob
  let factoryOwner, factoryAlice, factoryBob

  beforeEach(async () => {
    // Wallets
    const wallets = await ethers.getSigners()
    owner = await wallets[0]
    alice = await wallets[1]
    bob = await wallets[2]

    // Deploy contracts
    const ERC20Managed = await ethers.getContractFactory('ERC20Managed')
    reserveToken = await ERC20Managed.deploy('reserve token', 'RSV')
    const LinearCurve = await ethers.getContractFactory('LinearCurve')
    linearCurve = await LinearCurve.deploy()
    const ContinuousTokenFactory = await ethers.getContractFactory('ContinuousTokenFactory')
    continuousTokenFactory = await ContinuousTokenFactory.deploy(reserveToken.address)

    // Connect
    reserveOwner = reserveToken.connect(owner)
    reserveAlice = reserveToken.connect(alice)
    reserveBob = reserveToken.connect(bob)
    factoryOwner = continuousTokenFactory.connect(owner)
    factoryAlice = continuousTokenFactory.connect(alice)
    factoryBob = continuousTokenFactory.connect(bob)
  })

  it("allows creating, buying, and selling tokens", async () => {
    const id = ethers.utils.id("alice coin")
    await continuousTokenFactory.newContinuousToken(
      id, 
      "alice coin", 
      "ALC",
      linearCurve.address,
    )
    // TODO listen for event instead
    assert(
      Number(await continuousTokenFactory.totalSupply(id)) === 0,
      "New token not created successfully"
    )

    // buy tokens
    let bobBalance = await continuousTokenFactory.balanceOf(id, bob.getAddress())
    assert(Number(bobBalance) === 0, "Bob's starting balance not 0")

    const buyAmount = ethers.constants.WeiPerEther.mul(10)
    const price = await continuousTokenFactory.price(id, 0, buyAmount)
    await reserveToken.mint(bob.getAddress(), price)
    await reserveBob.approve(continuousTokenFactory.address, price)
    await factoryBob.buy(
      id,
      buyAmount,
      price,
      bob.getAddress()
    )
    // TODO listen for event instead
    bobBalance = await continuousTokenFactory.balanceOf(id, bob.getAddress())
    assert(Number(bobBalance) === Number(buyAmount), "Bob's post-buy balance not buy amount")

    // sell tokens
    assert(false, "Sell failed")

  })
})

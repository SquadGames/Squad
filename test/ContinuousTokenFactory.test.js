/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')
const { ethers } = require('ethers')

describe('ContinuousTokenFactory', () => {
  let Owner, Alice, Bob
  let owner, alice, bob
  let reserveToken, linearCurve, continuousTokenFactory
  let reserveOwner, reserveAlice, reserveBob
  let factoryOwner, factoryAlice, factoryBob

  beforeEach(async () => {
    // Wallets
    console.log(ethers, ethers.getSigners)
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
    reserveOwner = reserveToken.connect(owner)
    reserveAlice = reserveToken.connect(alice)
    reserveBob = reserveToken.connect(bob)
    factoryOwner = continuousTokenFactory.connect(owner)
    factoryAlice = continuousTokenFactory.connect(alice)
    factoryBob = continuousTokenFactory.connect(bob)
  })

  it("allows creating, buying, and selling tokens", async () => {
    const name = "alice coin"
    const id = ethers.utils.formatBytes32String(name)
    await expect(continuousTokenFactory.newContinuousToken(
      id, 
      name, 
      "ALC",
      linearCurve.address,
    )).to.emit(continuousTokenFactory, "NewContinuousToken")
    assert(
      (await continuousTokenFactory.totalSupply(id)).eq(0),
      "New token not created successfully"
    )

    // buy tokens
    const tokenAddress = await continuousTokenFactory.tokenAddress(id)
    const token = new ethers.Contract(tokenAddress, reserveToken.abi, Bob)
    let bobBalance = await token.balanceOf(bob)
    assert(bobBalance.eq(0), "Bob's starting balance not 0")
    
    const buyAmount = ethers.constants.WeiPerEther.mul(10)
    const price = await continuousTokenFactory.price(id, 0, buyAmount)
    await reserveToken.mint(bob, price)
    await reserveBob.approve(continuousTokenFactory.address, price)
    await expect(factoryBob.buy(
      id,
      buyAmount,
      price,
      bob
    )).to.emit(continuousTokenFactory, "Buy").withArgs(
      id,
      name,
      buyAmount,
      price,
      bob
    )
    bobBalance = await continuousTokenFactory.balanceOf(id, bob)
    assert(bobBalance.eq(buyAmount), "Bob's post-buy balance not buy amount")

    // sell tokens
    assert(false, "Sell failed")

  })
})

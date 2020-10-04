/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('TokenClaimCheck', () => {
  let tokenClaimCheck, tokenA, tokenB
  let Owner, owner, Alice, alice, Bob, bob
  let tccAlice, tccBob, tokenAAlice, tokenBAlice, tokenABob, tokenBBob

  beforeEach(async () => {
    // Wallets
    const wallets = await ethers.getSigners()
    Owner = wallets[0]
    Alice = wallets[1]
    Bob = wallets[2]

    // addresses
    owner = await Owner.getAddress()
    alice = await Alice.getAddress()
    bob = await Bob.getAddress()

    // deploy contracts
    const TokenClaimCheck = await ethers.getContractFactory('TokenClaimCheck')
    tokenClaimCheck = await TokenClaimCheck.deploy('Token Claim Check', 'TCC')
    const ManagedERC20 = await ethers.getContractFactory('ManagedERC20')
    tokenA = await ManagedERC20.deploy('Token A', 'TA')
    tokenB = await ManagedERC20.deploy('Token B', 'TB')
    await tokenClaimCheck.deployed()
    await tokenA.deployed()
    await tokenB.deployed()

    // connect to contracts
    tccAlice = tokenClaimCheck.connect(Alice)
    tccBob = tokenClaimCheck.connect(Bob)
    tokenAAlice = tokenA.connect(Alice)
    tokenABob = tokenA.connect(Bob)
    tokenBAlice = tokenB.connect(Alice)
    tokenBBob = tokenB.connect(Bob)

    // set up initial balances
    // Alice starts with token A
    await tokenA.mint(alice, ethers.utils.parseEther('100'))

    // Bob starts with token B
    await tokenB.mint(bob, ethers.utils.parseEther('100'))
  })

  it(
    'takes ERC20 token deposits in return for NFT claims and redeems them',
    async () => {
      // Alice deposits 20 A for a claim
      const aliceDeposit = ethers.utils.parseEther('20')
      const aliceClaimURI = 'test/aliceClaimURI'
      await tokenAAlice.approve(tokenClaimCheck.address, aliceDeposit)
      await expect(
        tccAlice.mint(
          alice, // to
          aliceDeposit, // amount
          alice, // from
          tokenA.address, // token
          aliceClaimURI // tokenURI
        )
      ).to.emit(tccAlice, 'Mint').withArgs(
        alice,
        aliceDeposit,
        alice,
        tokenA.address,
        aliceClaimURI
      )

      // Alice should have 80 token A and 0 token B
      assert((await tokenA.balanceOf(alice)).eq(ethers.utils.parseEther('80')),
        'Incorrect token A balance after mint'
      )

      // Bob deposits 70 B for a claim
      const bobDeposit = ethers.utils.parseEther('70')
      const bobClaimURI = 'test/bobClaimURI'
      await tokenBBob.approve(tokenClaimCheck.address, bobDeposit)
      await tccBob.mint(
        bob,
        bobDeposit,
        bob,
        tokenB.address,
        bobClaimURI
      )

      // Bob should have 30 token B and 0 token A
      assert((await tokenB.balanceOf(bob)).eq(ethers.utils.parseEther('30')),
        'Incorrect token B balance after mint'
      )

      // Alice and Bob trade claims
      const claimIdA = await tokenClaimCheck.tokenOfOwnerByIndex(alice, 0)
      await tccAlice.transferFrom(alice, bob, claimIdA)
      const claimIdB = await tokenClaimCheck.tokenOfOwnerByIndex(bob, 0)
      await tccBob.transferFrom(bob, alice, claimIdB)

      // Bob redeems claim A
      await tccBob.redeem(claimIdA)

      // Alice redeems claim B
      await tccAlice.redeem(claimIdB)

      // Alice should have 80 of token A and 70 of token B
      assert((await tokenA.balanceOf(alice)).eq(ethers.utils.parseEther('80')),
        'Incorrect Alice balance A after redeem'
      )
      assert((await tokenB.balanceOf(alice)).eq(ethers.utils.parseEther('70')),
        'Incorrect Alice balance B after redeem'
      )

      // Bob should have 20 of token Aand 30 of token B
      assert((await tokenA.balanceOf(bob)).eq(ethers.utils.parseEther('20')),
        'Incorrect Bob balance A after redeem'
      )
      assert((await tokenB.balanceOf(bob)).eq(ethers.utils.parseEther('30')),
        'Incorrect Bob balance B after redeem'
      )
    })
})

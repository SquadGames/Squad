/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('ManagedERC20', () => {
  let owner, alice
  let managedERC20, managedERC20Alice

  beforeEach(async () => {
    const wallets = await ethers.getSigners()
    owner = await wallets[0].getAddress()
    alice = await wallets[1].getAddress()

    const ManagedERC20 = await ethers.getContractFactory('ManagedERC20')
    managedERC20 = await ManagedERC20.deploy('test token name', 'TTN')

    managedERC20Alice = managedERC20.connect(wallets[1])
  })

  it('lets owner mint and burn tokens for accounts', async () => {
    // starts at zero
    assert(
      (await managedERC20.balanceOf(alice)).eq(0),
      'Incorrect starting balance'
    )

    // mint 100 for alice
    await managedERC20.mint(alice, ethers.utils.parseEther('100'))

    // Alice should have 100
    assert(
      (await managedERC20.balanceOf(alice)).eq(ethers.utils.parseEther('100')),
      'Incorrect balance after mint'
    )
  })

  it('No one else can mint or burn', async () => {
    await expect(
      managedERC20Alice.mint(alice, ethers.utils.parseEther('1'))
    ).to.be.revertedWith('Ownable: caller is not the owner')
  })
})

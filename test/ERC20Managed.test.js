/* global require beforeEach describe it ethers */

const { expect, assert } = require('chai')

describe('ERC20Managed', () => {
  let owner, alice
  let erc20Managed, erc20ManagedAlice

  beforeEach(async () => {
    const wallets = await ethers.getSigners()
    owner = await wallets[0].getAddress()
    alice = await wallets[1].getAddress()

    const ERC20Managed = await ethers.getContractFactory('ERC20Managed')
    erc20Managed = await ERC20Managed.deploy('test token name', 'TTN')

    erc20ManagedAlice = erc20Managed.connect(wallets[1])
  })

  it('lets owner mint and burn tokens for accounts', async () => {
    // starts at zero
    assert(
      (await erc20Managed.balanceOf(alice)).eq(0),
      'Incorrect starting balance'
    )

    // mint 100 for alice
    await erc20Managed.mint(alice, ethers.utils.parseEther('100'))

    // Alice should have 100
    assert(
      (await erc20Managed.balanceOf(alice)).eq(ethers.utils.parseEther('100')),
      'Incorrect balance after mint'
    )
  })

  it('No one else can mint or burn', async () => {
    await expect(
      erc20ManagedAlice.mint(alice, ethers.utils.parseEther('1'))
    ).to.be.revertedWith('Ownable: caller is not the owner')
  })
})

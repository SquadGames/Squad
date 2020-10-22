/* global require beforeEach describe it ethers */

const { assert } = require('chai')

describe('Accounting', () => {
  let Owner, owner, Alice, alice
  let accounting

  beforeEach(async () => {
    const wallets = await ethers.getSigners()
    Owner = wallets[0]
    owner = await Owner.getAddress()
    Alice = wallets[1]
    alice = await Alice.getAddress()

    const Accounting = await ethers.getContractFactory('Accounting')
    accounting = await Accounting.deploy()
  })

  it('tracks credits and debits in accounts', async () => {
    // starting with 0
    assert((await accounting.total(owner)).eq(0), "Owner's account started at nonzero total")
    assert((await accounting.total(alice)).eq(0), "Alice's account started at nonzero total")

    // crediting some amounts
    const ownerCredits = ['5', '23', '100'].map((n) => {
      return ethers.BigNumber.from(n)
    })
    const aliceCredits = ['123', '55', '1000'].map((n) => {
      return ethers.BigNumber.from(n)
    })

    // apply owner and alice credits
    await Promise.all(ownerCredits.map(async (c) => {
      return accounting.credit(owner, c)
    }))
    await Promise.all(aliceCredits.map(async (c) => {
      return accounting.credit(alice, c)
    }))

    // assert accounting is correct
    const ownerTotal = ownerCredits.reduce((n, m) => { return n.add(m) })
    const aliceTotal = aliceCredits.reduce((n, m) => { return n.add(m) })
    assert((await accounting.total(owner)).eq(ownerTotal), 'Owner total mismatch')
    assert((await accounting.total(alice)).eq(aliceTotal), 'Alice total mismatch')
    assert((await accounting.accountsTotal()).eq(ownerTotal.add(aliceTotal)))

    // reverse all credits with debits
    await Promise.all(ownerCredits.map(async (c) => {
      return accounting.debit(owner, c)
    }))
    await Promise.all(aliceCredits.map(async (c) => {
      return accounting.debit(alice, c)
    }))

    // all accounts should be zero
    assert((await accounting.total(owner)).eq(0), 'Owner account nonzero after debits')
    assert((await accounting.total(alice)).eq(0), 'Alice account nonzero after debits')
    assert((await accounting.accountsTotal()).eq(0), 'accountsTotal nonzero after debits')
  })
})

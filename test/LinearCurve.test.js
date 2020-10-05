/* global require beforeEach describe it ethers */

const { assert } = require('chai')

describe('LinearCurve', () => {
  let linearCurve

  beforeEach(async () => {
    const LinearCurve = await ethers.getContractFactory('LinearCurve')
    linearCurve = await LinearCurve.deploy()
  })

  it('returns the correct price', async () => {
    async function price (supply, amount) {
      const bigSupply = ethers.constants.WeiPerEther.mul(supply)
      const bigAmount = ethers.constants.WeiPerEther.mul(amount)
      return Number(await linearCurve.price(bigSupply, bigAmount))/10**18
    }

    // supply 0, amount 10
    assert(
      await price(0, 10) === 50, 
      'Price from 0 to 10 not 50'
    )

    // supply 100, amount 10
    assert(
      await price(100, 10) === 1050, 
      'Price from 100 to 110 not 1050'
    )

    // supply 10000, amount 10
    assert(
      await price(10000, 10) === 100050, 
      'Price from 10000 to 10010 not 100050'
    )
  })
})
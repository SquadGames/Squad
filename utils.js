/*
 *  This file largly taken from pre-ETHOnline work!!! Do Not Judge!!!
 */

/* global module require */

const ethers = require('ethers')

function bnsqrt (a, precision) {
  precision = precision <= 0 ? 1 : precision
  let x = a
  let root
  while (true) {
    root = a.div(x).add(x).div(2)
    if (root.sub(x).abs().lte(precision)) {
      return root
    }
    x = root
  }
}

function linearCurveAmount (s, p) {
  // simple linear curve x=y given
  // supply S and price P amount A = 1/2(squrt(8P+(2S+1)^2)-2S-1)
  // We scale the curve down by 10^18 however so we need to multiply
  // the P term here by 10^18
  const precision = 1
  const pMult = ethers.BigNumber.from('10').pow(18).mul(8)
  const a = bnsqrt(
    s.mul(2)
      .add(1)
      .pow(2)
      .add(p.mul(pMult)),
    precision
  ).sub(s.mul(2))
    .sub(1)
    .div(2)
  return a.add(precision)
}

module.exports = {
  linearCurveAmount,
  bnsqrt
}

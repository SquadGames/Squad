// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * `FeeLib`: fee split calculation
 */
library FeeLib {
    using SafeMath for uint256;
    using SafeMath for uint16;

    struct FeeSplit {
        uint256 fee;
        uint256 remainder;
    }

    /**
     * `calculateFeeSplit`: Returns the `fee` and the `remainder`
     * given a `total` and a feeRate in basis points
     *
     * Grants the remainder from devision, or the "rounding dust", to
     * the fee
     */
    function calculateFeeSplit(uint16 feeRate, uint256 total)
        internal
        pure
        returns (FeeSplit memory)
    {
        uint256 fee;
        uint256 dust;
        uint256 remainder;
        fee = total.mul(feeRate).div(10000);
        dust = total.mul(feeRate).mod(10000);
        fee = fee + dust;
        remainder = total - fee;
        return FeeSplit(fee, remainder);
    }
}

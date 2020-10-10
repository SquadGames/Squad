// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Curve.sol";

contract LinearCurve is Curve {
    using SafeMath for uint256;

    constructor() public {}

    function price(uint256 supply, uint256 amount)
        external
        override
        view
        returns (uint256)
    {
        // sum of the series from supply + 1 to new supply or (supply + amount)
        // average of the first term and the last term timen the number of terms
        //                supply + 1         supply + amount      amount

        uint256 t1 = supply.add(1); // the first newly minted token
        uint256 ta = supply.add(amount); // the last newly minted token
        uint256 a = amount; // number of tokens in the series

        // curve formula is p = s / 10^18

        // the forumula is p = a((t1 + ta)/2x10^18)
        // but deviding integers by introduces errors that are then multiplied
        // factor the formula to devide last

        // ((t1 * a) + (ta * a)) / 2x10^18

        return t1.mul(a).add(ta.mul(a)).div(2 * (10**18));
    }
}

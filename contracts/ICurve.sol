// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

interface Curve {
    function price(uint256 supply, uint256 units)
        external
        view
        returns (uint256);
}
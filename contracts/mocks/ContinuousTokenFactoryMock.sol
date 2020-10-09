// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "../ContinuousTokenFactory.sol";

contract ContinuousTokenFactoryMock is ContinuousTokenFactory {
    constructor(address _reserveToken)
        public
        ContinuousTokenFactory(_reserveToken)
    {}

    function buy(
        bytes32 id,
        uint256 amount,
        address buyer,
        address owner
    ) external returns (bool) {
        _buy(id, amount, buyer, owner);
    }

    function sell(
        bytes32 id,
        uint256 amount,
        address seller
    ) external returns (bool) {
        _sell(id, amount, seller);
    }
}

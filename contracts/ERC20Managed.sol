// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * `ERC20Managed` an ERC20 token that can be minted and burned by the
 * owner
 *
 * Used by the BondingCurveFactory as tokens for the bonding curves.
 */
contract ERC20Managed is Ownable, ERC20 {
    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {}

    /**
     * `mint`: Create `amount` new tokens for `account`
     */
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    /**
     * `burn`: Destroy `amount` of tokens from `account`
     */
    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}

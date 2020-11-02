// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./FeeLib.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * `Accounting` tracks credits and debits to accounts
 *
 * Only the owner may debit or credit accounts
 */
contract Accounting is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public accounts;
    uint256 public accountsTotal;

    constructor() public {}

    /**
     * `credit`: Increase an account by an amount
     *
     * Requires caller to be the owner
     *
     * Requires account to be a nonzero address
     */
    function credit(address account, uint256 amount) external onlyOwner() {
        require(account != address(0), "Accounting: credit zero address");
        accounts[account] = accounts[account].add(amount);
        accountsTotal = accountsTotal.add(amount);
    }

    /**
     * `credit`: Decrease an account by an amount
     *
     * Requires caller to be the owner
     *
     * Requires account to be a nonzero address
     */
    function debit(address account, uint256 amount) external onlyOwner() {
        require(account != address(0), "Accounting: debit zero address");
        accounts[account] = accounts[account].sub(amount);
        accountsTotal = accountsTotal.sub(amount);
    }

    /**
     * `total`: View returning the current total for an account
     *
     * Requires account to be a nonzero address
     */
    function total(address account) external view returns (uint256) {
        require(
            account != address(0),
            "Accounting: no account at zero address"
        );
        return accounts[account];
    }
}

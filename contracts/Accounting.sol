// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./FeeLib.sol";
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "@nomiclabs/buidler/console.sol";

contract Accounting is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public accounts;
    uint256 public accountsTotal;

    constructor() public {}

    function credit(address account, uint256 amount) public onlyOwner() {
        require(account != address(0), "Accounting: credit zero address");
        accounts[account] = accounts[account].add(amount);
        accountsTotal = accountsTotal.add(amount);
    }

    function debit(address account, uint256 amount) public onlyOwner() {
        require(account != address(0), "Accounting: debit zero address");
        accounts[account] = accounts[account].sub(amount);
        accountsTotal = accountsTotal.sub(amount);
    }

    function total(address account) public view returns (uint256) {
        require(
            account != address(0),
            "Accounting: no account at zero address"
        );
        return accounts[account];
    }
}

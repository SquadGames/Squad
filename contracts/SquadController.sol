// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Managed.sol";
import "./TokenClaimCheck.sol";
import "./ContinuousTokenFactory.sol";
import "./Curve.sol";
import "@nomiclabs/buidler/console.sol";

contract SquadController is Ownable, ContinuousTokenFactory {
    using SafeMath for uint256;
    using SafeMath for uint16;

    TokenClaimCheck public tokenClaimCheck;
    Curve public curve;

    uint16 public networkFeeRate; // in basis points
    uint16 public maxNetworkFee; // in basis points

    struct FeeSplit {
        uint256 fee;
        uint256 remainder;
    }

    address public treasury;
    mapping(address => uint256) public accounts;
    uint256 accountsTotal;

    struct Contribution {
        address beneficiary;
        uint16 fee; // in basis points
        uint256 purchasePrice;
    }
    mapping(bytes32 => Contribution) public contributions;

    mapping(uint256 => bytes32) public validLicenses;

    constructor (
                 address _reserveToken,
                 address _tokenClaimCheck,
                 uint16 _networkFeeRate,
                 uint16 _maxNetworkFee,
                 address _treasury,
                 address _curve
                 ) public ContinuousTokenFactory(_reserveToken) {
        require(
                _treasury != address(0),
                "SquadController: zero treasury address"
                );
        require(
                _tokenClaimCheck != address(0),
                "SquadController: zero TokenClaimCheck address"
                );
        require(
                _curve != address(0),
                "SquadController: zero Curve address"
                );
        require(
                _maxNetworkFee <= 10000,
                "SquadController: max network fee > 100%"
                );
        require(
                _networkFeeRate <= _maxNetworkFee,
                "SquadController: network gee > max"
                );
        networkFeeRate = _networkFeeRate;
        maxNetworkFee = _maxNetworkFee;
        treasury = _treasury;
        tokenClaimCheck = TokenClaimCheck(_tokenClaimCheck);
        curve = Curve(_curve);
    }

    event NewContribution(
                          address contributor,
                          bytes32 contributionId,
                          address beneficiary,
                          uint16 fee,
                          uint256 purchasePrice,
                          address continuousToken,
                          string metadata
                          );

    function newContribution(
                             bytes32 contributionId,
                             address beneficiary,
                             uint16 fee,
                             uint256 purchasePrice,
                             string calldata name,
                             string calldata symbol,
                             string calldata metadata
                             ) external {
        require(!exists(contributionId), "SquadController: contribution already exists");
        require(beneficiary != address(0), "SquadController: zero beneficiary address");

        newContinuousToken(contributionId, name, symbol, address(curve));

        contributions[contributionId] = Contribution(beneficiary, fee, purchasePrice);

        address tokenAddress = address(continuousTokens[contributionId].token);

        emit NewContribution(
                             msg.sender,
                             contributionId,
                             beneficiary,
                             fee,
                             purchasePrice,
                             tokenAddress,
                             metadata
                             );
    }

    event BuyLicense(
              address buyer,
              bytes32 contributionId,
              uint256 licenseId,
              string name,
              uint256 amount,
              uint256 price
              );

    function buyLicense(
                 bytes32 contributionId,
                 uint256 amount,
                 uint256 maxPrice
                 ) external mustExist(contributionId) {
        ERC20 token = continuousTokens[contributionId].token;
        uint256 supply = token.totalSupply();
        uint256 totalPrice = price(contributionId, supply, amount);
        Contribution memory contribution = contributions[contributionId];
        uint256 purchasePrice = contribution.purchasePrice;
        require(
                totalPrice <= maxPrice,
                "SquadController: totalPrice exceeds maxPrice"
                );
        require(
                totalPrice >= purchasePrice,
                "SquadController: not enough to meet purchasePrice"
                );

        // buy `amount` of the continuous token to be claimed by this license
        _buy(contributionId, amount, msg.sender, address(this));

        // TODO factor this out to reduce the size of the stack
        FeeSplit memory feeSplit = _calculateFeeSplit(contribution.fee, totalPrice);
        accounts[contribution.beneficiary] = accounts[contribution.beneficiary].add(feeSplit.fee);
        accountsTotal = accountsTotal.add(feeSplit.fee);

        // Create a license to claim those tokens check for the caller
        continuousTokens[contributionId].token.approve(address(tokenClaimCheck), amount);
        uint256 licenseId = tokenClaimCheck.mint(
                             msg.sender,
                             amount,
                             address(this),
                             address(token)
                             );

        // record valid license
        validLicenses[licenseId] = contributionId;

        string memory contributionTokenName = continuousTokens[contributionId].token.name();
        BuyLicense(
                   msg.sender,
                   contributionId,
                   licenseId,
                   contributionTokenName,
                   amount,
                   totalPrice
                   );
    }

    function holdsLicense(
                          bytes32 contributionId,
                          uint256 licenseId,
                          address account
                          ) external view mustExist(contributionId) returns (bool) {
        if(validLicenses[licenseId] != contributionId) {
            return false;
        }
        return account == tokenClaimCheck.ownerOf(licenseId);
    }

    event SetNetworkFeeRate(uint16 from, uint16 to);

    function setNetworkFeeRate(uint16 from, uint16 to) external onlyOwner {
        require(
                networkFeeRate == from,
                "SquadController: network fee compare failed"
                );
        require(
                to <= maxNetworkFee,
                "SquadController: cannot set fee higer than max"
                );
        networkFeeRate = to;
        emit SetNetworkFeeRate(from, to);
    }

    event Withdraw(
                   address account,
                   uint256 withdrawAmount,
                   uint256 networkFeePaid
                   );

    function withdraw(address account) public {
        require(accounts[account] > 0, "SquadController: nothing to withdraw");
        FeeSplit memory feeSplit = _calculateFeeSplit(networkFeeRate, accounts[account]);
        uint256 withdrawAmount = feeSplit.remainder;

        // transfer to account address
        reserveToken.transfer(account, withdrawAmount);

        // transfer to treasury
        reserveToken.transfer(treasury, feeSplit.fee);

        emit Withdraw(account, withdrawAmount, feeSplit.fee);
    }

    function _calculateFeeSplit(uint16 basisPoints, uint256 total)
        internal
        pure
        returns (FeeSplit memory)
    {
        uint256 fee;
        uint256 dust;
        uint256 remainder;
        fee = total.mul(basisPoints).div(10000);
        dust = total.mul(basisPoints).mod(10000);
        fee = fee + dust;
        remainder = total - fee;
        return FeeSplit(fee, remainder);
    }

    function reserveDust() public view returns (uint256) {
        return reserveToken.balanceOf(address(this)).sub(accountsTotal);
    }

    function recoverReserveDust() public {
        reserveToken.transfer(treasury, reserveDust());
    }


    /*    event SetPurchasePrice(
                           bytes32 contributionId,
                           uint256 fromPurchasePrice,
                           uint256 toPurchasePrice
                           );

    function setPurchasePrice(
                              bytes32 contributionId,
                              uint256 purchasePrice,
                              uint256 newPrice
                              ) public mustExist(contributionId) onlyBeneficiary(contributionId) {
        Contribution storage contribution = contributions[contributionId];
        require(
                contribution.purchasePrice == purchasePrice,
                "SquadController: purchasePrice missmatch"
                );

        contribution.purchasePrice = newPrice;

        emit SetPurchasePrice(contributionId, purchasePrice, newPrice);
    }

    modifier onlyBeneficiary(bytes32 contributionId) {
        require(
                msg.sender == contributions[contributionId].beneficiary,
                "SquadController: restricted to beneficiary"
                );
        _;
        }*/
}

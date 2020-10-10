// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Managed.sol";
import "./TokenClaimCheck.sol";
import "./ContinuousTokenFactory.sol";
import "./Curve.sol";
import "./Accounting.sol";
import "./FeeLib.sol";
import "@nomiclabs/buidler/console.sol";

contract SquadController is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint16;

    TokenClaimCheck public tokenClaimCheck;
    Curve public curve;
    Accounting public accounting;
    ContinuousTokenFactory public tokenFactory;

    uint16 public networkFeeRate; // in basis points
    uint16 public maxNetworkFee; // in basis points

    address public treasury;

    struct Contribution {
        address beneficiary;
        uint16 fee; // in basis points
        uint256 purchasePrice;
    }
    mapping(bytes32 => Contribution) public contributions;

    mapping(uint256 => bytes32) public validLicenses;

    constructor (
                 address reserveToken,
                 address _tokenClaimCheck,
                 uint16 _networkFeeRate,
                 uint16 _maxNetworkFee,
                 address _treasury,
                 address _curve
                 ) public {
        require(
                _treasury != address(0),
                "SquadController: zero treasury address"
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
        tokenFactory = new ContinuousTokenFactory(reserveToken);
        accounting = new Accounting();
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

        tokenFactory.newContinuousToken(contributionId, name, symbol, address(curve));

        contributions[contributionId] = Contribution(beneficiary, fee, purchasePrice);

        address tokenAddress = address(tokenFactory.tokenAddress(contributionId));

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
        ERC20 token = ERC20(tokenFactory.tokenAddress(contributionId));
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
        tokenFactory.buy(contributionId, amount, msg.sender, address(this));

        FeeLib.FeeSplit memory feeSplit = FeeLib.calculateFeeSplit(contribution.fee, totalPrice);
        accounting.credit(contribution.beneficiary, feeSplit.fee);

        // Create a license to claim those tokens check for the caller
        token.approve(address(tokenClaimCheck), amount);
        uint256 licenseId = tokenClaimCheck.mint(
                             msg.sender,
                             amount,
                             address(this),
                             address(token)
                             );

        // record valid license
        validLicenses[licenseId] = contributionId;

        string memory contributionTokenName = token.name();
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
        if(validLicenses[licenseId] != contributionId || !tokenClaimCheck.exists(licenseId)) {
            return false;
        }
        return account == tokenClaimCheck.ownerOf(licenseId);
    }

    function sellContinuousTokens(
                                  bytes32 contributionId,
                                  uint256 amount,
                                  uint256 minPrice
                                  ) public mustExist(contributionId) {
        uint256 supply = tokenFactory.totalSupply(contributionId);
        require(
                price(contributionId, supply.sub(amount), supply) >= minPrice,
                "SquadController: sale price lower than min price"
                );
        tokenFactory.sell(contributionId, amount, msg.sender);
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
        require(accounting.total(account) > 0, "SquadController: nothing to withdraw");
        FeeLib.FeeSplit memory feeSplit = FeeLib.calculateFeeSplit(networkFeeRate, accounting.total(account));
        uint256 withdrawAmount = feeSplit.remainder;

        // transfer to account address
        tokenFactory.transferReserve(account, withdrawAmount);

        // transfer to treasury
        tokenFactory.transferReserve(treasury, feeSplit.fee);

        emit Withdraw(account, withdrawAmount, feeSplit.fee);
    }

    function reserveDust() public view returns (uint256) {
        return tokenFactory.reserveBalanceOf(address(this)).sub(accounting.accountsTotal());
    }

    function recoverReserveDust() public {
        tokenFactory.transferReserve(treasury, reserveDust());
    }

    function price(bytes32 contributionId, uint256 supply, uint256 amount) public view returns (uint256) {
        return tokenFactory.price(contributionId, supply, amount);
    }

    function tokenAddress(bytes32 contributionId) public view returns (address) {
        ERC20Managed token;
        (token, ) = tokenFactory.continuousTokens(contributionId);
        return address(token);
    }

    function exists(bytes32 contributionId) public view returns (bool) {
        return contributions[contributionId].beneficiary != address(0);
    }

    modifier mustExist(bytes32 contributionId) {
        require(exists(contributionId), "SquadController: contribution does not exist");
        _;
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

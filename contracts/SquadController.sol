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

    uint16 public networkFee; // in basis points
    uint16 public maxNetworkFee; // in basis points

    address public treasury;
    mapping(address => uint256) public accounts;
    uint256 accountsTotal;

    struct Contribution {
        address beneficiary;
        uint16 fee; // in basis points
        uint256 purchasePrice;
        string contributionURI;
    }
    mapping(bytes32 => Contribution) public contributions;

    mapping(uint256 => bytes32) public validLicenses;

    constructor (
                 address _reserveToken,
                 address _tokenClaimCheck,
                 uint16 _networkFee,
                 uint16 _maxNetworkFee,
                 address _treasury
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
                _maxNetworkFee <= 10000,
                "SquadController: max network fee > 100%"
                );
        require(
                _networkFee <= _maxNetworkFee,
                "SquadController: network gee > max"
                );
        networkFee = _networkFee;
        maxNetworkFee = _maxNetworkFee;
        treasury = _treasury;
        tokenClaimCheck = TokenClaimCheck(_tokenClaimCheck);
    }

    event NewContribution(
                          address contributor,
                          bytes32 contributionId,
                          address beneficiary,
                          uint16 fee,
                          uint256 purchasePrice,
                          address continuousToken,
                          string contributionURI,
                          string metadata
                          );

    function newContribution(
                             bytes32 contributionId,
                             address beneficiary,
                             uint16 fee,
                             uint256 purchasePrice,
                             address curve,
                             string calldata name,
                             string calldata symbol,
                             string calldata contributionURI,
                             string calldata metadata
                             ) external {
        require(!exists(contributionId), "SquadController: contribution already exists");
        require(curve != address(0), "SquadController: zero curve address");
        require(beneficiary != address(0), "SquadController: zero beneficiary address");

        newContinuousToken(contributionId, name, symbol, curve);

        contributions[contributionId] = Contribution(beneficiary, fee, purchasePrice, contributionURI);

        address tokenAddress = address(continuousTokens[contributionId].token);

        emit NewContribution(
                             msg.sender,
                             contributionId,
                             beneficiary,
                             fee,
                             purchasePrice,
                             tokenAddress,
                             contributionURI,
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
                 uint256 maxPrice,
                 // TODO consider infering tokenURI from id. What
                 // problems come from the client providing the
                 // tokenURI?
                 string calldata tokenURI
                 ) external mustExist(contributionId) {
        ERC20 token = continuousTokens[contributionId].token;
        uint256 supply = token.totalSupply();
        uint256 totalPrice = price(contributionId, supply, amount);
        uint256 purchasePrice = contributions[contributionId].purchasePrice;
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

        // Create a license to claim those tokens check for the caller
        continuousTokens[contributionId].token.approve(address(tokenClaimCheck), amount);
        uint256 licenseId = tokenClaimCheck.mint(
                             msg.sender,
                             amount,
                             address(this),
                             address(token),
                             tokenURI
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

    event SetNetworkFee(uint16 from, uint16 to);

    function setNetworkFee(uint16 from, uint16 to) external onlyOwner {
        require(
                networkFee == from,
                "SquadController: network fee compare failed"
                );
        require(
                to <= maxNetworkFee,
                "SquadController: cannot set fee higer than max"
                );
        networkFee = to;
        emit SetNetworkFee(from, to);
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

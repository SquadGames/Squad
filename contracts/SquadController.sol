// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Managed.sol";
import "./ContinuousTokenFactory.sol";
import "./Curve.sol";

contract SquadController is Ownable, ContinuousTokenFactory {
    using SafeMath for uint256;
    using SafeMath for uint16;

    uint16 public networkFee; // in basis points

    address public treasury;
    mapping(address => uint256) public acounts;
    uint256 accountsTotal;

    struct Contribution {
        address beneficiary;
        uint16 fee; // in basis points
        uint256 purchasePrice;
        string contributionURI;
    }
    mapping(bytes32 => Contribution) public contributions;

    constructor (
                 address _reserveToken,
                 uint16 _networkFee,
                 address _treasury
                 ) public ContinuousTokenFactory(_reserveToken) {
        require(_treasury != address(0), "SquadController: zero treasury address");
        require(_networkFee <= 10000, "SquadController: network fee > 100%");
        networkFee = _networkFee;
        treasury = _treasury;
    }

    event NewContribution(
                          address contributor,
                          bytes32 indexed id,
                          address indexed beneficiary,
                          uint16 fee,
                          uint256 purchasePrice,
                          address continuousToken,
                          string contributionURI,
                          string indexed name,
                          string symbol,
                          string metadata
                          );

    function newContribution(
                             bytes32 id,
                             address beneficiary,
                             uint16 fee,
                             uint256 purchasePrice,
                             address curve,
                             string memory name,
                             string memory symbol,
                             string memory contributionURI,
                             string memory metadata
                             ) public {
        require(!exists(id), "SquadController: contribution already exists");
        require(curve != address(0), "SquadController: zero curve address");
        require(beneficiary != address(0), "SquadController: zero beneficiary address");

        newContinuousToken(id, name, symbol, curve);

        contributions[id] = Contribution(beneficiary, fee, purchasePrice, contributionURI);

        address tokenAddress = address(continuousTokens[id].token);

        emit NewContribution(
                             msg.sender,
                             id,
                             beneficiary,
                             fee,
                             purchasePrice,
                             tokenAddress,
                             contributionURI,
                             name,
                             symbol,
                             metadata
                             );
    }

    event SetPurchasePrice(
                           bytes32 indexed id,
                           uint256 fromPurchasePrice,
                           uint256 toPurchasePrice
                           );

    function setPurchasePrice(
                              bytes32 id,
                              uint256 purchasePrice,
                              uint256 newPrice
                              ) public mustExist(id) onlyBeneficiary(id) {
        Contribution storage contribution = contributions[id];
        require(
                contribution.purchasePrice == purchasePrice,
                "SquadController: purchasePrice missmatch"
                );

        contribution.purchasePrice = newPrice;

        emit SetPurchasePrice(id, purchasePrice, newPrice);
    }

    modifier onlyBeneficiary(bytes32 id) {
        require(
                msg.sender == contributions[id].beneficiary,
                "SquadController: restricted to beneficiary"
                );
        _;
    }
}

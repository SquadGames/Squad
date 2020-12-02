// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Managed.sol";
import "./TokenClaimCheck.sol";
import "./BondingCurveFactory.sol";
import "./Curve.sol";
import "./Accounting.sol";
import "./FeeLib.sol";
import "hardhat/console.sol";

/**
 * `SquadController` provides the basic Squad Platform
 *
 * It manages contributions and the bonding curves backing them
 * through a {BondingCurveFactory} ERC20 token.
 *
 * It manages licencing, allowing contributor (beneficiaries) to set a
 * constant price for a license to use their contribution through a
 * {TokenClaimCheck} ERC721 NFT.
 *
 * It manages network and beneficiary fees taken from purchases of the
 * bonding curve token.
 */
contract SquadController is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint16;

    TokenClaimCheck public tokenClaimCheck;
    Curve public curve;
    Accounting public accounting;
    BondingCurveFactory public bondingCurveFactory;

    uint16 public networkFeeRate; // in basis points
    uint16 public maxNetworkFeeRate; // in basis points

    address public treasury;

    struct Contribution {
        address beneficiary;
        uint16 feeRate; // in basis points
        uint256 purchasePrice;
    }
    mapping(bytes32 => Contribution) public contributions;

    mapping(uint256 => bytes32) public validLicenses;

    /**
     * `constructor` sets up needed values and contracts
     *
     * Sets the values for `networkFeeRate` and `maxNetworkFeeRate` in
     * basis points.
     *
     * Sets the `treasury`, `tokenClaimCheck`, and `curve`.
     *
     * Creates a new `bondingCurveFactory` with the `reserveToken` and
     * a new `accounting` contract.
     *
     * Requires `treasury` and `curve` addresses to be nonzero
     *
     * Requires `maxNetworkFeeRate` to be less than or equal to 10000
     * (100% equivilent)
     *
     * Requires `networkFeeRate` to be less than or equal to
     * `maxNetworkFeeRate`
     */
    constructor(
        address _bondingCurveFactory,
        address _tokenClaimCheck,
        uint16 _networkFeeRate,
        uint16 _maxNetworkFeeRate,
        address _treasury,
        address _curve
    ) public {
        require(
                _bondingCurveFactory != address(0),
                "SquadController: zero bondingCurveFactory address"
                );
        require(
            _treasury != address(0),
            "SquadController: zero treasury address"
        );
        require(_curve != address(0), "SquadController: zero Curve address");
        require(
            _maxNetworkFeeRate <= 10000,
            "SquadController: max network fee > 100%"
        );
        require(
            _networkFeeRate <= _maxNetworkFeeRate,
            "SquadController: network gee > max"
        );
        networkFeeRate = _networkFeeRate;
        maxNetworkFeeRate = _maxNetworkFeeRate;
        treasury = _treasury;
        tokenClaimCheck = TokenClaimCheck(_tokenClaimCheck);
        curve = Curve(_curve);
        bondingCurveFactory = BondingCurveFactory(_bondingCurveFactory);
        accounting = new Accounting();
    }

    event NewContribution(
        address contributor,
        bytes32 contributionId,
        string name,
        address beneficiary,
        uint16 feeRate,
        uint256 purchasePrice,
        address bondingCurve,
        string metadata
    );

    /**
     * `newContribution`: Creates and sets up a new contribution
     *
     * `contributionId`: Should uniquely identify the contribution. It
     * should be the hash of the contribution data. Contributions with
     * a given ID can only ever be created once
     *
     * `beneficiary`: The address that will earn fees when the bonding
     * curve token sells
     *
     * `feeRate`: The rate (in basis points) earned by the beneficiary
     * when the bonding curve token sells
     *
     * `purchasePrice`: The initial price (in `reserveToken`) of a
     * license to use the contribution. The beneficiary may change
     * this price at any time by calling `setPurchasePrice`
     *
     * `name`: The bonding curve token will be created with this name
     *
     * `symbol`: The bonding curve token will be created with this
     * symbol
     *
     * `metadata`: Data that will be included in the event logs. This
     * can be useful for client applications by including information
     * to help search for or categorize the contribution
     *
     * Creates a new bonding curve with the `bondingCurveFactory` and records
     * all needed information in the `contributions` mapping for
     * future reference
     *
     * Emits a `NewContribution` event
     */
    function newContribution(
        bytes32 contributionId,
        address beneficiary,
        uint16 feeRate,
        uint256 purchasePrice,
        string calldata name,
        string calldata symbol,
        string calldata metadata
    ) external {
        require(
            !exists(contributionId),
            "SquadController: contribution already exists"
        );
        require(
            beneficiary != address(0),
            "SquadController: zero beneficiary address"
        );

        bondingCurveFactory.newBondingCurve(
            contributionId,
            name,
            symbol,
            address(curve)
        );

        contributions[contributionId] = Contribution(
            beneficiary,
            feeRate,
            purchasePrice
        );

        address addr = tokenAddress(contributionId);

        emit NewContribution(
            msg.sender,
            contributionId,
            name,
            beneficiary,
            feeRate,
            purchasePrice,
            addr,
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

    /**
     * `buyLicense`: Buys an NFT licensefor the `purchasePrice`
     *
     * `contributionId`: Buy a license to use this contribution
     *
     * `amount`: Buy and claim this amount of bonding curve
     * token. It's required to cost more than the conribution's
     * current `purchasePrice`
     *
     * `maxPrice`: Revert if the price of `amount` has slipped above
     * this.
     *
     * A valid license costs a set price (in the `reserveToken`) equal
     * to the contribution's `purchasePrice` at the time of
     * purchase. This price is spent on an `amount` the contribution's
     * curved bond token. It is inneficient to find an `amount` to buy
     * that will cost that price. Therefor the client must do the
     * calculation before calling `buyLicense` and pass an `amount`
     * that will cost greater than or equal to the current
     * `purchasePrice`. That `amount` of curved bond token will be
     * bought, the license will claim that `amount`, and will be
     * redeemable for that `amount` from the `tokenClaimCheck`.
     *
     * `buyLicense` keeps track of all valid licenses that were
     * created and the contribution they are valid for.
     *
     * Emits a `BuyLicense` event
     */
    function buyLicense(
        bytes32 contributionId,
        uint256 amount,
        uint256 maxPrice
    ) external mustExist(contributionId) {
        ERC20 token;
        (token, ) = bondingCurveFactory.bondingCurves(contributionId);
        uint256 supply = token.totalSupply();
        uint256 totalPrice = priceOf(contributionId, supply, amount);
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
        bondingCurveFactory.buy(
            contributionId,
            amount,
            msg.sender,
            address(this)
        );

        FeeLib.FeeSplit memory feeSplit = FeeLib.calculateFeeSplit(
            contribution.feeRate,
            totalPrice
        );

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

    /**
     * `holdsLicense` Checks if an account holds a valid license
     * to use a contribution
     *
     * `contributionId`: The contribution being checked
     *
     * `licenseId`: The license being checked
     *
     * `account`: The user account being checked
     *
     * A license is valid if the NFT Claim Check exists and is a
     * valid license for the contribution in question. The `account`
     * holds it if they are the owner of the NFT.
     */
    function holdsLicense(
        bytes32 contributionId,
        uint256 licenseId,
        address account
    ) external view mustExist(contributionId) returns (bool) {
        if (
            validLicenses[licenseId] != contributionId ||
            !tokenClaimCheck.exists(licenseId)
        ) {
            return false;
        }
        return account == tokenClaimCheck.ownerOf(licenseId);
    }

    /**
     * `sellTokens`: Sells a contribution's curved bond tokens for
     * `reserveToken`
     *
     * `contributionId': The contribution's curved bond token to sell
     *
     * `amount`: The amount of token to sell
     *
     * `minPrice`: Reverts if the sale price is lower due to others
     *
     * See `BondingCurveFactory.sell`. This function passes the
     * correct `feeRate` for the contribution and sells on behalf of
     * the `msg.sender`
     */
    function sellTokens(
        bytes32 contributionId,
        uint256 amount,
        uint256 minPrice
    ) public mustExist(contributionId) {
        uint16 feeRate = contributions[contributionId].feeRate;
        bondingCurveFactory.sell(
            contributionId,
            amount,
            feeRate,
            minPrice,
            msg.sender,
            msg.sender
        );
    }

    event SetNetworkFeeRate(uint16 from, uint16 to);

    /**
     * `setNetworkFeeRate`: Sets the `networkFeeRate` if lower than
     * `maxNetworkFeeRate`
     *
     * `from`: Don't change the rate if the current rate is not what
     * the caller is changing it `from`
     *
     * `to`: The new rate
     *
     * Requires `to` to be less than or equal to `maxNetworkFeeRate`
     *
     * Emits a `SetNetworkFeeRate` event
     */
    function setNetworkFeeRate(uint16 from, uint16 to) external onlyOwner {
        require(
            networkFeeRate == from,
            "SquadController: network fee compare failed"
        );
        require(
            to <= maxNetworkFeeRate,
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

    /**
     * `withdraw`: Transferes to a beneficiary their earned fees and
     * pays the network fee
     *
     * `account`: The beneficiary to withdraw for
     *
     * Requires the `account` to have something to with draw; more
     * than zero.
     *
     * Emits a `Withdraw` event
     */
    function withdraw(address account) public {
        require(
            accounting.total(account) > 0,
            "SquadController: nothing to withdraw"
        );

        uint256 total = accounting.total(account);

        FeeLib.FeeSplit memory feeSplit = FeeLib.calculateFeeSplit(
            networkFeeRate,
            total
        );

        accounting.debit(account, total);

        // transfer to account address
        bondingCurveFactory.transferReserve(account, feeSplit.remainder);

        // transfer to treasury
        bondingCurveFactory.transferReserve(treasury, feeSplit.fee);

        emit Withdraw(account, feeSplit.remainder, feeSplit.fee);
    }

    /**
     * `reserveDust`: View returning the amount of `reserveToken` in the
     * system that is not accounted for due to rounding errors (or
     * "rounding dust")
     */
    function reserveDust() public view returns (uint256) {
        return
            bondingCurveFactory
                .reserveBalanceOf(address(bondingCurveFactory))
                .sub(accounting.accountsTotal());
    }

    event RecoverReserveDust(address to, uint256 amount);

    /**
     * `recoverReserveDust`: Transfers the rounding dust that has
     * accumulated in the system to the treasury.
     *
     * Requires there to be dust to recover
     *
     * Emits a `RecoverReserveDust` event
     */
    function recoverReserveDust() public {
        uint256 amount = reserveDust();
        require(amount > 0, "No dust to recover");
        bondingCurveFactory.transferReserve(treasury, amount);
        emit RecoverReserveDust(treasury, amount);
    }

    /**
     * `priceOf`: View returning the price of an amount given a supply
     * of a contribution bonding curve token
     *
     * see `bondingCurveFactory.priceOf`
     */
    function priceOf(
        bytes32 contributionId,
        uint256 supply,
        uint256 amount
    ) public view returns (uint256) {
        return bondingCurveFactory.priceOf(contributionId, supply, amount);
    }

    /**
     * `tokenAddress`: View returning the address of the
     * contribution's bonding curve ERC20 token
     */
    function tokenAddress(bytes32 contributionId)
        public
        view
        returns (address)
    {
        ERC20Managed token;
        (token, ) = bondingCurveFactory.bondingCurves(contributionId);
        return address(token);
    }

    /**
     * `totalSupplyOf`: View retuning the total supply of the
     * contribution's bonding curve token
     *
     * Requires the contribution to exist
     */
    function totalSupplyOf(bytes32 contributionId)
        external
        view
        mustExist(contributionId)
        returns (uint256)
    {
        return bondingCurveFactory.totalSupplyOf(contributionId);
    }

    /**
     * `exists`: View returning whether a contribution exists
     */
    function exists(bytes32 contributionId) public view returns (bool) {
        return contributions[contributionId].beneficiary != address(0);
    }

    /**
     * `mustExist`: Modifier used to require that a contribution
     * exist
     */
    modifier mustExist(bytes32 contributionId) {
        require(
            exists(contributionId),
            "SquadController: contribution does not exist"
        );
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

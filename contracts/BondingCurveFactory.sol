// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20Managed.sol";
import "./Curve.sol";
import "./FeeLib.sol";
import "hardhat/console.sol";

/**
 * `BondingCurveFactory`: Creates and interacts with new bonding
 * curves
 */
contract BondingCurveFactory is Ownable {
    using SafeMath for uint256;

    ERC20 public reserveToken;

    struct BondingCurve {
        ERC20Managed token;
        Curve curve;
    }

    mapping(bytes32 => BondingCurve) public bondingCurves;

    /**
     * `constructor`: Sets `reserveToken`
     *
     * Requires a nonzero reserve token address
     */
    constructor(address _reserveToken) public {
        require(
            _reserveToken != address(0),
            "BondingCurveFactory: no reserve token ERC20 address"
        );
        reserveToken = ERC20(_reserveToken);
    }

    event NewBondingCurve(
        bytes32 id,
        address token,
        string name,
        address curve
    );

    /**
     * `newBondingCurve`: Creates a new bonding curve
     *
     * `id`: The identifier for the bonding curve. Must be unique and
     * not previously used. This is intended to associate the bonding
     * curve with some entity it backs (like a Squad contribution) and
     * should be the hash or a unique identifier of that entity.
     *
     * `name`: The name of the bonding curve ERC20 token
     *
     * `symbol`: The symbol of the bonding curve ERC20 token
     *
     * `_curve`: The address of a contract that satisfies the `Curve`
     * interface. The curve price function should be strictly
     * increasing as supply increases
     *
     * Requires `id` not to already have a bond associated
     *
     * Requires a nonzero `_curve` address
     *
     * Emits a `NewBondingCurve` event
     */
    function newBondingCurve(
        bytes32 id,
        string calldata name,
        string calldata symbol,
        address _curve
    ) external returns (bool) {
        require(
            !exists(id),
            "BondingCurveFactory: continuous token already exists"
        );
        require(
            _curve != address(0),
            "BondingCurveFactory: curve at address 0"
        );
        // TODO find a way to require a Curve contract be at curve

        ERC20Managed token = new ERC20Managed(name, symbol);
        Curve curve = Curve(_curve);
        BondingCurve memory bondingCurve = BondingCurve(token, curve);
        bondingCurves[id] = bondingCurve;

        emit NewBondingCurve(id, address(token), name, address(curve));
        return true;
    }

    event Buy(
        bytes32 id,
        string name,
        uint256 amount,
        uint256 price,
        address from,
        address to
    );

    /**
     * `buy`: Mints `amount` of new tokens of a given bonding curve in
     * exchange for the price of that amount given the current supply
     *
     * `id`: The bonding curve to use
     *
     * `amount`: The amount of new tokens to mint
     *
     * `from`: Transfers the price in `reserveToken` from this
     * address.
     *
     * `to`: Newly minted tokens belong to this address
     *
     * Requires the caller to be the owner. This is intended to be
     * used by a controller contract that is the owner.
     *
     * Requires an allowance equal to or greater than the price of
     * `amount` from `from`
     *
     * Emits a `Buy` event
     */
    function buy(
        bytes32 id,
        uint256 amount,
        address from,
        address to
    ) external mustExist(id) onlyOwner returns (bool) {
        ERC20Managed token = bondingCurves[id].token;
        Curve curve = bondingCurves[id].curve;

        // Check price
        uint256 price = curve.price(token.totalSupply(), amount);

        // Transfer and mint
        require(reserveToken.transferFrom(from, address(this), price));
        token.mint(to, amount);

        emit Buy(id, token.name(), amount, price, from, to);
        return true;
    }

    event Sell(
        bytes32 id,
        string name,
        uint256 amount,
        uint16 feeRate,
        uint256 price,
        address from,
        address to
    );

    /**
     * `sell`: Burns `amount` of token from `from` and transfers their
     * price (minus the fee) to `to`
     *
     * `id`: The bonding curve token to burn
     *
     * `amount`: The amount to burn
     *
     * `feeRate`: The rate (in basis points) to subtract from the
     * price for the fee
     *
     * `minPrice`: The minimum price (after the fee) the seller is
     * willing to accept. Reverts if price - fee is lower than this
     *
     * `from`: The account to burn tokens from
     *
     * `to`: The account to send `reserveToken` to
     *
     * Requires the caller to be the owner. This is intended to be
     * used by a controller contract that is the owner.
     *
     * Requires `from` to have at least `amount`. Enough to burn
     *
     * Requires the price minus the fee to be greater than or equal to
     * `minPrice`
     *
     * Emits a `Sell` event
     */
    function sell(
        bytes32 id,
        uint256 amount,
        uint16 feeRate,
        uint256 minPrice,
        address from,
        address to
    ) external mustExist(id) onlyOwner returns (bool) {
        ERC20Managed token = bondingCurves[id].token;
        Curve curve = bondingCurves[id].curve;
        require(
            token.balanceOf(from) >= amount,
            "BondingCurveFactory: seller holds too few tokens"
        );

        // Check price
        uint256 price = curve.price(token.totalSupply().sub(amount), amount);
        FeeLib.FeeSplit memory feeSplit = FeeLib.calculateFeeSplit(
            feeRate,
            price
        );
        require(
            feeSplit.remainder >= minPrice,
            "BondingCurveFactory: sell price lower than minPrice"
        );

        // Burn and transfer
        token.burn(from, amount);
        require(reserveToken.transfer(to, feeSplit.remainder));

        emit Sell(
            id,
            token.name(),
            amount,
            feeRate,
            feeSplit.remainder,
            from,
            to
        );
        return true;
    }

    /**
     * `transferReserve`: Transfers an `amount` of `reserveToken` to `to`
     *
     * Requires caller to be the owner
     *
     * This is a convinience function so that the controller can have
     * control of transfering reserve token without complicated
     * approvals and allowances
     */
    function transferReserve(address to, uint256 amount)
        external
        onlyOwner
        returns (bool)
    {
        return reserveToken.transfer(to, amount);
    }

    /**
     * `reserveBalanceOf`: View returning the `reserveToken` balance
     * of `account`
     */
    function reserveBalanceOf(address account) external view returns (uint256) {
        return reserveToken.balanceOf(account);
    }

    /**
     * `priceOf`: View returning the price of a given curved bond
     * token according to it's curve.
     *
     * see `Curve`
     */
    function priceOf(
        bytes32 id,
        uint256 supply,
        uint256 units
    ) external view mustExist(id) returns (uint256) {
        Curve curve = bondingCurves[id].curve;
        return curve.price(supply, units);
    }

    /**
     * `totalSupplyOf`: View returning the total supply of a given
     * curved bond token
     */
    function totalSupplyOf(bytes32 id) external view returns (uint256) {
        return bondingCurves[id].token.totalSupply();
    }

    /*
    function tokenAddress(bytes32 id)
        external
        view
        mustExist(id)
        returns (address)
    {
        return address(bondingCurves[id].token);
        }*/

    function exists(bytes32 id) public view returns (bool) {
        return address(bondingCurves[id].token) != address(0);
    }

    modifier mustExist(bytes32 id) {
        require(
            exists(id),
            "BondingCurveFactory: continuous token does not exist"
        );
        _;
    }
}

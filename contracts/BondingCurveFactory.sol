// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20Managed.sol";
import "./Curve.sol";
import "./FeeLib.sol";
import "@nomiclabs/buidler/console.sol";

contract BondingCurveFactory is Ownable {
    using SafeMath for uint256;

    ERC20 public reserveToken;

    struct BondingCurve {
        ERC20Managed token;
        Curve curve;
    }

    mapping(bytes32 => BondingCurve) public bondingCurves;

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

    function newBondingCurve(
        bytes32 id,
        string memory name,
        string memory symbol,
        address _curve
    ) public returns (bool) {
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

    function transferReserve(address to, uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        return reserveToken.transfer(to, amount);
    }

    function reserveBalanceOf(address account) public view returns (uint256) {
        return reserveToken.balanceOf(account);
    }

    // TODO Consider changing this to priceOf to avoid confusion with
    // price variables in function bodies
    function priceOf(
        bytes32 id,
        uint256 supply,
        uint256 units
    ) public view mustExist(id) returns (uint256) {
        Curve curve = bondingCurves[id].curve;
        return curve.price(supply, units);
    }

    function totalSupplyOf(bytes32 id) public view returns (uint256) {
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

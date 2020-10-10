// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20Managed.sol";
import "./Curve.sol";

contract ContinuousTokenFactory is Ownable {
    using SafeMath for uint256;

    ERC20 public reserveToken;

    struct ContinuousToken {
        ERC20Managed token;
        Curve curve;
    }

    mapping(bytes32 => ContinuousToken) public continuousTokens;

    constructor(address _reserveToken) public {
        require(
            _reserveToken != address(0),
            "ContinuousTokenFactory: no reserve token ERC20 address"
        );
        reserveToken = ERC20(_reserveToken);
    }

    event NewContinuousToken(
        bytes32 id,
        address token,
        string name,
        address curve
    );

    function newContinuousToken(
        bytes32 id,
        string memory name,
        string memory symbol,
        address _curve
    ) public returns (bool) {
        require(
            !exists(id),
            "ContinuousTokenFactory: continuous token already exists"
        );
        require(
            _curve != address(0),
            "ContinuousTokenFactory: curve at address 0"
        );
        // TODO find a way to require a Curve contract be at curve

        ERC20Managed token = new ERC20Managed(name, symbol);
        Curve curve = Curve(_curve);
        ContinuousToken memory continuousToken = ContinuousToken(token, curve);
        continuousTokens[id] = continuousToken;

        emit NewContinuousToken(id, address(token), name, address(curve));
        return true;
    }

    event Buy(
        bytes32 id,
        string name,
        uint256 amount,
        uint256 price,
        address buyer,
        address owner
    );

    function buy(
        bytes32 id,
        uint256 amount,
        address buyer,
        address owner
    ) external onlyOwner mustExist(id) returns (bool) {
        ERC20Managed token = continuousTokens[id].token;
        Curve curve = continuousTokens[id].curve;

        // Check price
        uint256 price = curve.price(token.totalSupply(), amount);

        // Transfer and mint
        require(reserveToken.transferFrom(buyer, address(this), price));
        token.mint(owner, amount);

        emit Buy(id, token.name(), amount, price, buyer, owner);
        return true;
    }

    event Sell(
        bytes32 id,
        string name,
        uint256 amount,
        uint256 price,
        address seller
    );

    function sell(
        bytes32 id,
        uint256 amount,
        address seller
    ) external mustExist(id) onlyOwner returns (bool) {
        ERC20Managed token = continuousTokens[id].token;
        Curve curve = continuousTokens[id].curve;
        require(
            token.balanceOf(seller) >= amount,
            "ContinuousTokenFactory: seller holds too few tokens"
        );

        // Check price
        uint256 price = curve.price(token.totalSupply().sub(amount), amount);

        // Burn and transfer
        token.burn(seller, amount);
        require(reserveToken.transfer(seller, price));

        emit Sell(id, token.name(), amount, price, seller);
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
    function price(
        bytes32 id,
        uint256 supply,
        uint256 units
    ) public view mustExist(id) returns (uint256) {
        Curve curve = continuousTokens[id].curve;
        return curve.price(supply, units);
    }

    function totalSupply(bytes32 id) public view returns (uint256) {
        return continuousTokens[id].token.totalSupply();
    }

    function tokenAddress(bytes32 id)
        external
        view
        mustExist(id)
        returns (address)
    {
        return address(continuousTokens[id].token);
    }

    function exists(bytes32 id) public view returns (bool) {
        return address(continuousTokens[id].token) != address(0);
    }

    modifier mustExist(bytes32 id) {
        require(
            exists(id),
            "ContinuousTokenFactory: continuous token does not exist"
        );
        _;
    }
}

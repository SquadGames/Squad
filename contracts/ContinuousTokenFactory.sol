// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20Managed.sol";
import "./ICurve.sol";

contract ContinuousTokenFactory {
  using SafeMath for uint256;

  ERC20 public reserveToken;

  struct ContinuousToken {
    address token;
    address curve;
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
    address curve
  ) public {
    require(!exists(id), "ContinuousTokenFactory: invalid id");
    // TODO this probably isn't correct -- we want to check that a contract compliant with ICurve is at curve
    require(ICurve(curve), "ContinuousTokenFactory: curve not ICurve");

    ERC20Managed token = new ERC20Managed(name, symbol);
    ContinuousToken continuousToken = ContinuousToken(token, curve);
    continuousTokens[id] = continuousToken;

    emit NewContinuousToken(
      id,
      token,
      name,
      curve
    );
  }

  event Buy(
    bytes32 id, 
    string name,
    uint256 amount,
    uint256 price,
    address buyer,
  )

  function buy(
    bytes32 id, 
    uint256 amount,
    uint256 maxPrice,
    address buyer
  ) external {
    (ERC20Managed token, ICurve curve) = unpack(id);

    // Check price
    uint256 price = curve.price(token.totalSupply(), amount);
    require(price <= maxPrice, "ContinuousTokenFactory: price greater than maxPrice");

    // Transfer and mint
    require(
      reserveToken.transferFrom(buyer, address(this), price)
    );
    token.mint(buyer, amount);

    emit Buy(
      id,
      token.name,
      amount,
      price,
      to
    )
  }

  event Sell(
    bytes32 id,
    string name,
    uint256 amount,
    uint256 price,
    uint256 seller
  )

  function sell(
    bytes32 id,
    uint256 amount,
    uint256 minPrice,
    address seller
  ) external {
    require(balanceOf(id, seller) >= amount, "ContinuousTokenFactory: seller holds too few tokens");
    (ERC20Managed token, ICurve curve) = unpack(id);

    // Check price
    uint256 price = curve.price(token.totalSupply().sub(amount), amount);
    require(price >= minPrice, "ContinuousTokenFactory: price less than minPrice");

    // Burn and transfer
    token.burn(seller, amount);
    require(
      reserveToken.transfer(seller, price)
    );

    emit Sell(
      id,
      token.name,
      amount,
      price,
      seller
    )
  }

  // TODO portals to other ERC20 interface functions

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) public view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function exists(bytes32 id) internal view returns (bool) {
    return continuousTokens[id].token != address(0);
  }

  function unpack(bytes32 id) internal view returns (
    ERC20Managed token,
    ICurve curve
  ) {
    require(exists(id), "ContinuousTokenFactory: invalid id");
    ContinuousToken storage ct = continuousTokens[id];
    require(ct.token != address(0), "ContinuousTokenFactory: invalid token");
    require(ct.curve != address(0), "ContinuousTokenFactory: invalid curve");
    ERC20Managed token = ERC20Managed(ct.token)
    ICurve curve = ICurve(ct.curve)
    return (token, curve)
  }
}

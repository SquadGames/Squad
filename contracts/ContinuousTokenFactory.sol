// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20Managed.sol";
import "./Curve.sol";

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
  ) public returns (bool) {
    require(!exists(id), "ContinuousTokenFactory: invalid id");
    // require(Curve(curve).price(0, 1), "ContinuousTokenFactory: invalid curve");

    address token = address(new ERC20Managed(name, symbol));
    ContinuousToken memory continuousToken = ContinuousToken(token, curve);
    continuousTokens[id] = continuousToken;

    emit NewContinuousToken(
      id,
      token,
      name,
      curve
    );
    return true;
  }

  event Buy(
    bytes32 id, 
    string name,
    uint256 amount,
    uint256 price,
    address buyer
  );

  function buy(
    bytes32 id, 
    uint256 amount,
    uint256 maxPrice,
    address buyer
  ) external returns (bool) {
    (ERC20Managed token, Curve curve) = unpack(id);

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
      token.name(),
      amount,
      price,
      buyer
    );
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
    uint256 minPrice,
    address seller
  ) external returns (bool) {
    (ERC20Managed token, Curve curve) = unpack(id);
    require(token.balanceOf(seller) >= amount, "ContinuousTokenFactory: seller holds too few tokens");

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
      token.name(),
      amount,
      price,
      seller
    );
    return true;
  }

  // TODO portals to other ERC20 interface functions

  function totalSupply(bytes32 id) external view returns (uint256) {
    (ERC20Managed token, ) = unpack(id);
    return token.totalSupply();
  }

  function balanceOf(bytes32 id, address account) external view returns (uint256) {
    (ERC20Managed token, ) = unpack(id);
    return token.balanceOf(account);
  }

  function approve(
    bytes32 id, 
    address spender, 
    uint256 amount
  ) external returns (bool) {
    (ERC20Managed token, ) = unpack(id);
    return token.approve(spender, amount);
  }

  function allowance(
    bytes32 id,
    address owner, 
    address spender
  ) external view returns (uint256) {
    (ERC20Managed token, ) = unpack(id);
    return token.allowance(owner, spender);
  }

  function transfer(
    bytes32 id, 
    address recipient, 
    uint256 amount
  ) external returns (bool) {
    (ERC20Managed token, ) = unpack(id);
    return token.transfer(recipient, amount);
  }

  function transferFrom(
    bytes32 id,
    address sender, 
    address recipient, 
    uint256 amount
  ) external returns (bool) {
    (ERC20Managed token, ) = unpack(id);
    return token.transferFrom(sender, recipient, amount);
  }

  function exists(bytes32 id) internal view returns (bool) {
    return continuousTokens[id].token != address(0);
  }

  function unpack(bytes32 id) internal view returns (ERC20Managed, Curve) {
    require(exists(id), "ContinuousTokenFactory: invalid id");
    ContinuousToken storage ct = continuousTokens[id];
    require(ct.token != address(0), "ContinuousTokenFactory: invalid token");
    require(ct.curve != address(0), "ContinuousTokenFactory: invalid curve");
    ERC20Managed token = ERC20Managed(ct.token);
    Curve curve = Curve(ct.curve);
    return (token, curve);
  }
}

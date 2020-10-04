// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "./ERC20Managed.sol";
import "./ICurve.sol";

contract ContinuousTokenFactory {
  struct ContinuousToken {
    address token;
    address curve;
  }

  mapping(bytes32 => ContinuousToken) public continuousTokens;

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
    // TODO this probably isn't correct
    require(ICurve(curve), "ContinuousTokenFactory: curve must be ICurve");

    ERC20Managed token = new ERC20Managed(name, symbol);
    ContinuousToken continuousToken = ContinuousToken(token, curve);

    emit NewContinuousToken(
      id,
      token,
      name,
      curve
    );
  }

  function buy() public {}

  function sell() public {}

  function transfer() public {}

  // TODO portals to other ERC20 interface functions
}

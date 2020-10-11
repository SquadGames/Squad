## `BondingCurveFactory`





### `mustExist(bytes32 id)`






### `constructor(address _reserveToken)` (public)





### `newBondingCurve(bytes32 id, string name, string symbol, address _curve) → bool` (public)





### `buy(bytes32 id, uint256 amount, address from, address to) → bool` (external)





### `sell(bytes32 id, uint256 amount, uint16 feeRate, uint256 minPrice, address from, address to) → bool` (external)





### `transferReserve(address to, uint256 amount) → bool` (public)





### `reserveBalanceOf(address account) → uint256` (public)





### `priceOf(bytes32 id, uint256 supply, uint256 units) → uint256` (public)





### `totalSupplyOf(bytes32 id) → uint256` (public)





### `exists(bytes32 id) → bool` (public)






### `NewBondingCurve(bytes32 id, address token, string name, address curve)`





### `Buy(bytes32 id, string name, uint256 amount, uint256 price, address from, address to)`





### `Sell(bytes32 id, string name, uint256 amount, uint16 feeRate, uint256 price, address from, address to)`






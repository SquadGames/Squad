## `BondingCurveFactory`

`BondingCurveFactory`: Creates and interacts with new bonding
curves



### `mustExist(bytes32 id)`






### `constructor(address _reserveToken)` (public)

`constructor`: Sets `reserveToken`
Requires a nonzero reserve token address



### `newBondingCurve(bytes32 id, string name, string symbol, address _curve) → bool` (external)

`newBondingCurve`: Creates a new bonding curve
`id`: The identifier for the bonding curve. Must be unique and
not previously used. This is intended to associate the bonding
curve with some entity it backs (like a Squad contribution) and
should be the hash or a unique identifier of that entity.
`name`: The name of the bonding curve ERC20 token
`symbol`: The symbol of the bonding curve ERC20 token
`_curve`: The address of a contract that satisfies the `Curve`
interface. The curve price function should be strictly
increasing as supply increases
Requires `id` not to already have a bond associated
Requires a nonzero `_curve` address
Emits a `NewBondingCurve` event



### `buy(bytes32 id, uint256 amount, address from, address to) → bool` (external)

`buy`: Mints `amount` of new tokens of a given bonding curve in
exchange for the price of that amount given the current supply
`id`: The bonding curve to use
`amount`: The amount of new tokens to mint
`from`: Transfers the price in `reserveToken` from this
address.
`to`: Newly minted tokens belong to this address
Requires the caller to be the owner. This is intended to be
used by a controller contract that is the owner.
Requires an allowance equal to or greater than the price of
`amount` from `from`
Emits a `Buy` event



### `sell(bytes32 id, uint256 amount, uint16 feeRate, uint256 minPrice, address from, address to) → bool` (external)

`sell`: Burns `amount` of token from `from` and transfers their
price (minus the fee) to `to`
`id`: The bonding curve token to burn
`amount`: The amount to burn
`feeRate`: The rate (in basis points) to subtract from the
price for the fee
`minPrice`: The minimum price (after the fee) the seller is
willing to accept. Reverts if price - fee is lower than this
`from`: The account to burn tokens from
`to`: The account to send `reserveToken` to
Requires the caller to be the owner. This is intended to be
used by a controller contract that is the owner.
Requires `from` to have at least `amount`. Enough to burn
Requires the price minus the fee to be greater than or equal to
`minPrice`
Emits a `Sell` event



### `transferReserve(address to, uint256 amount) → bool` (external)

`transferReserve`: Transfers an `amount` of `reserveToken` to `to`
Requires caller to be the owner
This is a convinience function so that the controller can have
control of transfering reserve token without complicated
approvals and allowances



### `reserveBalanceOf(address account) → uint256` (external)

`reserveBalanceOf`: View returning the `reserveToken` balance
of `account`



### `priceOf(bytes32 id, uint256 supply, uint256 units) → uint256` (external)

`priceOf`: View returning the price of a given curved bond
token according to it's curve.
see `Curve`



### `totalSupplyOf(bytes32 id) → uint256` (external)

`totalSupplyOf`: View returning the total supply of a given
curved bond token



### `exists(bytes32 id) → bool` (public)






### `NewBondingCurve(bytes32 id, address token, string name, address curve)`





### `Buy(bytes32 id, string name, uint256 amount, uint256 price, address from, address to)`





### `Sell(bytes32 id, string name, uint256 amount, uint16 feeRate, uint256 price, address from, address to)`






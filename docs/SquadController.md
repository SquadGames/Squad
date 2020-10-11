## `SquadController`

`SquadController` provides the basic Squad Platform
It manages contributions and the bonding curves backing them
through a {BondingCurveFactory} ERC20 token.
It manages licencing, allowing contributor (beneficiaries) to set a
constant price for a license to use their contribution through a
{TokenClaimCheck} ERC721 NFT.
It manages network and beneficiary fees taken from purchases of the
bonding curve token.



### `mustExist(bytes32 contributionId)`

`mustExist`: Modifier used to require that a contribution
exist




### `constructor(address reserveToken, address _tokenClaimCheck, uint16 _networkFeeRate, uint16 _maxNetworkFeeRate, address _treasury, address _curve)` (public)

`constructor` sets up needed values and contracts
Sets the values for `networkFeeRate` and `maxNetworkFeeRate` in
basis points.
Sets the `treasury`, `tokenClaimCheck`, and `curve`.
Creates a new `bondingCurveFactory` with the `reserveToken` and
a new `accounting` contract.
Requires `treasury` and `curve` addresses to be nonzero
Requires `maxNetworkFeeRate` to be less than or equal to 10000
(100% equivilent)
Requires `networkFeeRate` to be less than or equal to
`maxNetworkFeeRate`



### `newContribution(bytes32 contributionId, address beneficiary, uint16 feeRate, uint256 purchasePrice, string name, string symbol, string metadata)` (external)

`newContribution`: Creates and sets up a new contribution
`contributionId`: Should uniquely identify the contribution. It
should be the hash of the contribution data. Contributions with
a given ID can only ever be created once
`beneficiary`: The address that will earn fees when the bonding
curve token sells
`feeRate`: The rate (in basis points) earned by the beneficiary
when the bonding curve token sells
`purchasePrice`: The initial price (in `reserveToken`) of a
license to use the contribution. The beneficiary may change
this price at any time by calling `setPurchasePrice`
`name`: The bonding curve token will be created with this name
`symbol`: The bonding curve token will be created with this
symbol
`metadata`: Data that will be included in the event logs. This
can be useful for client applications by including information
to help search for or categorize the contribution
Creates a new bonding curve with the `bondingCurveFactory` and records
all needed information in the `contributions` mapping for
future reference
Emits a `NewContribution` event



### `buyLicense(bytes32 contributionId, uint256 amount, uint256 maxPrice)` (external)

`buyLicense`: Buys an NFT licensefor the `purchasePrice`
`contributionId`: Buy a license to use this contribution
`amount`: Buy and claim this amount of bonding curve
token. It's required to cost more than the conribution's
current `purchasePrice`
`maxPrice`: Revert if the price of `amount` has slipped above
this.
A valid license costs a set price (in the `reserveToken`) equal
to the contribution's `purchasePrice` at the time of
purchase. This price is spent on an `amount` the contribution's
curved bond token. It is inneficient to find an `amount` to buy
that will cost that price. Therefor the client must do the
calculation before calling `buyLicense` and pass an `amount`
that will cost greater than or equal to the current
`purchasePrice`. That `amount` of curved bond token will be
bought, the license will claim that `amount`, and will be
redeemable for that `amount` from the `tokenClaimCheck`.
`buyLicense` keeps track of all valid licenses that were
created and the contribution they are valid for.
Emits a `BuyLicense` event



### `holdsLicense(bytes32 contributionId, uint256 licenseId, address account) → bool` (external)

`holdsLicense` Checks if an account holds a valid license
to use a contribution
`contributionId`: The contribution being checked
`licenseId`: The license being checked
`account`: The user account being checked
A license is valid if the NFT Claim Check exists and is a
valid license for the contribution in question. The `account`
holds it if they are the owner of the NFT.



### `sellTokens(bytes32 contributionId, uint256 amount, uint256 minPrice)` (public)

`sellTokens`: Sells a contribution's curved bond tokens for
`reserveToken`
`contributionId': The contribution's curved bond token to sell
`amount`: The amount of token to sell
`minPrice`: Reverts if the sale price is lower due to others
See `BondingCurveFactory.sell`. This function passes the
correct `feeRate` for the contribution and sells on behalf of
the `msg.sender`



### `setNetworkFeeRate(uint16 from, uint16 to)` (external)

`setNetworkFeeRate`: Sets the `networkFeeRate` if lower than
`maxNetworkFeeRate`
`from`: Don't change the rate if the current rate is not what
the caller is changing it `from`
`to`: The new rate
Requires `to` to be less than or equal to `maxNetworkFeeRate`
Emits a `SetNetworkFeeRate` event



### `withdraw(address account)` (public)

`withdraw`: Transferes to a beneficiary their earned fees and
pays the network fee
`account`: The beneficiary to withdraw for
Requires the `account` to have something to with draw; more
than zero.
Emits a `Withdraw` event



### `reserveDust() → uint256` (public)

`reserveDust`: View returning the amount of `reserveToken` in the
system that is not accounted for due to rounding errors (or
"rounding dust")



### `recoverReserveDust()` (public)

`recoverReserveDust`: Transfers the rounding dust that has
accumulated in the system to the treasury.
Requires there to be dust to recover
Emits a `RecoverReserveDust` event



### `priceOf(bytes32 contributionId, uint256 supply, uint256 amount) → uint256` (public)

`priceOf`: View returning the price of an amount given a supply
of a contribution bonding curve token
see `bondingCurveFactory.priceOf`



### `tokenAddress(bytes32 contributionId) → address` (public)

`tokenAddress`: View returning the address of the
contribution's bonding curve ERC20 token



### `totalSupplyOf(bytes32 contributionId) → uint256` (external)

`totalSupplyOf`: View retuning the total supply of the
contribution's bonding curve token
Requires the contribution to exist



### `exists(bytes32 contributionId) → bool` (public)

`exists`: View returning whether a contribution exists




### `NewContribution(address contributor, bytes32 contributionId, address beneficiary, uint16 feeRate, uint256 purchasePrice, address bondingCurve, string metadata)`





### `BuyLicense(address buyer, bytes32 contributionId, uint256 licenseId, string name, uint256 amount, uint256 price)`





### `SetNetworkFeeRate(uint16 from, uint16 to)`





### `Withdraw(address account, uint256 withdrawAmount, uint256 networkFeePaid)`





### `RecoverReserveDust(address to, uint256 amount)`






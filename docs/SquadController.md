## `SquadController`





### `mustExist(bytes32 contributionId)`






### `constructor(address reserveToken, address _tokenClaimCheck, uint16 _networkFeeRate, uint16 _maxNetworkFee, address _treasury, address _curve)` (public)





### `newContribution(bytes32 contributionId, address beneficiary, uint16 fee, uint256 purchasePrice, string name, string symbol, string metadata)` (external)





### `buyLicense(bytes32 contributionId, uint256 amount, uint256 maxPrice)` (external)





### `holdsLicense(bytes32 contributionId, uint256 licenseId, address account) → bool` (external)





### `sellTokens(bytes32 contributionId, uint256 amount, uint256 minPrice)` (public)





### `setNetworkFeeRate(uint16 from, uint16 to)` (external)





### `withdraw(address account)` (public)





### `reserveDust() → uint256` (public)





### `recoverReserveDust()` (public)





### `price(bytes32 contributionId, uint256 supply, uint256 amount) → uint256` (public)





### `tokenAddress(bytes32 contributionId) → address` (public)





### `totalSupplyOf(bytes32 contributionId) → uint256` (external)





### `exists(bytes32 contributionId) → bool` (public)






### `NewContribution(address contributor, bytes32 contributionId, address beneficiary, uint16 fee, uint256 purchasePrice, address bondingCurve, string metadata)`





### `BuyLicense(address buyer, bytes32 contributionId, uint256 licenseId, string name, uint256 amount, uint256 price)`





### `SetNetworkFeeRate(uint16 from, uint16 to)`





### `Withdraw(address account, uint256 withdrawAmount, uint256 networkFeePaid)`





### `RecoverReserveDust(address to, uint256 amount)`






## `Accounting`

`Accounting` tracks credits and debits to accounts
Only the owner may debit or credit accounts




### `credit(address account, uint256 amount)` (external)

`credit`: Increase an account by an amount
Requires caller to be the owner
Requires account to be a nonzero address



### `debit(address account, uint256 amount)` (external)

`credit`: Decrease an account by an amount
Requires caller to be the owner
Requires account to be a nonzero address



### `total(address account) → uint256` (external)

`total`: View returning the current total for an account
Requires account to be a nonzero address





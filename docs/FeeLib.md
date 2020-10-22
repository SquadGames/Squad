## `FeeLib`

`FeeLib`: fee split calculation




### `calculateFeeSplit(uint16 feeRate, uint256 total) → struct FeeLib.FeeSplit` (internal)

`calculateFeeSplit`: Returns the `fee` and the `remainder`
given a `total` and a feeRate in basis points
Grants the remainder from devision, or the "rounding dust", to
the fee





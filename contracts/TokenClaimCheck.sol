// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@nomiclabs/buidler/console.sol";

contract TokenClaimCheck is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct Claim {
        address token;
        uint256 amount;
    }

    mapping(uint256 => Claim) public claims;

    constructor(string memory name, string memory symbol)
        public
        ERC721(name, symbol)
    {}

    event Mint(
        address to,
        uint256 amount,
        address from,
        address token,
        string tokenURI
    );

    function mint(
        address to,
        uint256 amount,
        address from,
        address token,
        string memory tokenURI
    ) public {
        require(amount > 0, "TokenClaimCheck: claim zero amount");
        require(
            token != address(0),
            "TokenClaimCheck: claim token zero address"
        );

        // Transfer claimed amount
        require(ERC20(token).transferFrom(from, address(this), amount));

        // Record the claim
        _tokenIds.increment();
        uint256 newClaimId = _tokenIds.current();
        claims[newClaimId] = Claim(token, amount);

        // Mint the claim check
        _mint(to, newClaimId);
        _setTokenURI(newClaimId, tokenURI);

        emit Mint(to, amount, from, token, tokenURI);
    }

    event Redeem(uint256 claimId, uint256 amount, address owner);

    function redeem(uint256 claimId) public {
        Claim memory claim = claims[claimId];
        // require that the caller holds the claim
        require(
            _isApprovedOrOwner(_msgSender(), claimId),
            "TokenClaimCheck: redeem caller is not owner nor approved"
        );

        address claimOwner = ownerOf(claimId);

        // Transfer the claimed tokens to claim holder
        require(ERC20(claim.token).transfer(claimOwner, claim.amount));

        // Burn the NFT
        _burn(claimId);

        // clean up the claim data
        delete claims[claimId];

        emit Redeem(claimId, claim.amount, claimOwner);
    }
}

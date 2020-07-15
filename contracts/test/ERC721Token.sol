// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "../../node_modules/openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721 {
    uint256 private tokenId;

    constructor(
        string memory name,
        string memory symbol
    )
        ERC721(name, symbol)
        public
    {}

    function createTimeframe (
        string memory tokenURI
    )
        public
        returns (bool)
    {
        tokenId += 1;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return true;
    }
}

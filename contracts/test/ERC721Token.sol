// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "../../node_modules/openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "../../node_modules/openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ERC721Token is ERC721URIStorage {
    uint256 private tokenId;

    constructor(
        string memory name,
        string memory symbol
    )
        ERC721(name, symbol)
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

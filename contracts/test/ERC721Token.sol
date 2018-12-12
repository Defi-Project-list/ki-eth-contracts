pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";

contract ERC721Token is ERC721Full {
    uint256 private tokenId;

    constructor(
        string name,
        string symbol
    )
        ERC721Full(name, symbol)
        public
    {}

    function createTimeframe (
        string tokenURI
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
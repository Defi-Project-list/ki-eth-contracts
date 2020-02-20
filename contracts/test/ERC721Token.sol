pragma solidity 0.5.16;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";

contract ERC721Token is ERC721Full {
    uint256 private tokenId;

    constructor(
        string memory name,
        string memory symbol
    )
        ERC721Full(name, symbol)
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
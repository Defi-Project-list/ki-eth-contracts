// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "../lib/OracleBase.sol";

contract Oracle2 is OracleBase {
    mapping(address => bool) private s_tokens;

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) MultiSig(owner1, owner2, owner3) {}

    function updateToken(address token, bool safe) public {
        s_tokens[token] = safe;
    }

    function isTokenSafe(address token) public view returns (bool) {
        return s_tokens[token];
    }

    function is20Safe(address token) public view override returns (bool) {
        return s_tokens[token];
    }

    function is721Safe(address token) public view override returns (bool) {
        return s_tokens[token];
    }

    function version() external pure override returns (bytes8) {
        return bytes8("0.1");
    }
}

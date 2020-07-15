// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "../lib/IOracle.sol";

contract Oracle2 is IOracle {

    mapping (address=>bool) private tokens;

    function updateToken(address _token, bool _safe) public {
        tokens[_token] = _safe;
    }

    function isTokenSafe(address _token) public view returns (bool) {
        return tokens[_token];
    }

    function is20Safe(address _token) public view override returns (bool) {
        return tokens[_token];
    }

    function is721Safe(address _token) public view override returns (bool) {
        return tokens[_token];
    }

}
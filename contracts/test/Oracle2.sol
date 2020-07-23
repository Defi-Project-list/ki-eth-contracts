// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "../lib/OracleBase.sol";

contract Oracle2 is OracleBase {

    mapping (address=>bool) private tokens;

    constructor(address owner1, address owner2, address owner3) MultiSig(owner1, owner2, owner3) public {
    }

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

    function version() external pure override returns (bytes8) {
      return bytes8("0.1");
    }

}
// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./lib/IOracle.sol";

contract Oracle is IOracle {

    mapping (address=>bool) private tokens_20;
    mapping (address=>bool) private tokens_721;

    function update20(address _token, bool _safe) public {
        tokens_20[_token] = _safe;
    }

    function update721(address _token, bool _safe) public {
        tokens_721[_token] = _safe;
    }

    function is20Safe (address _token) public view override returns (bool) {
        return tokens_20[_token];
    }

    function is721Safe(address _token) public view override returns (bool) {
        return tokens_721[_token];
    }
}
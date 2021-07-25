// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./lib/OracleBase.sol";

contract RecoveryOracle is OracleBase {
    mapping(address => bool) private s_tokens_20;
    mapping(address => bool) private s_tokens_721;

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) MultiSig(owner1, owner2, owner3) {}

    function update20(address token, bool safe)
        external
        multiSig2of3(msg.value)
    {
        s_tokens_20[token] = safe;
    }

    function update721(address token, bool safe) external multiSig2of3(0) {
        s_tokens_721[token] = safe;
    }

    function is20Safe(address token) external view override returns (bool) {
        return s_tokens_20[token];
    }

    function is721Safe(address token) external view override returns (bool) {
        return s_tokens_721[token];
    }

    function version() external pure override returns (bytes8) {
        return bytes8("REC-0.1");
    }

    fallback() external {}
}

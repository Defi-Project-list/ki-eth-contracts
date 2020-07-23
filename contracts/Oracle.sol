// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./lib/OracleBase.sol";

contract Oracle is OracleBase {
    mapping (address=>bool) private tokens_20;
    mapping (address=>bool) private tokens_721;

    constructor(address owner1, address owner2, address owner3) MultiSig(owner1, owner2, owner3) public {
    }

    function update20(address _token, bool _safe) public multiSig2of3(msg.value) payable {
      tokens_20[_token] = _safe;
    }

    function update721(address _token, bool _safe) public multiSig2of3(0) {
        tokens_721[_token] = _safe;
    }

    function is20Safe (address _token) public view override returns (bool) {
        return tokens_20[_token];
    }

    function is721Safe(address _token) public view override returns (bool) {
        return tokens_721[_token];
    }

    function version() public pure override returns (bytes8) {
        return bytes8("1.2.1");
    }

}
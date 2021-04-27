// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./IOracle.sol";
import "./MultiSig.sol";

abstract contract OracleBase is IOracle, MultiSig {
    address payable internal s_payto;

    function paymentAddress() public view override returns (address payable) {
        return s_payto;
    }

    function initialized() public view override returns (bool) {
        require(s_payto != address(0), "payment address cannot be 0");
        return true;
    }

    function setPaymentAddress(address payable payto)
        public
        override
        multiSig2of3(0)
    {
        require(payto != address(0), "payment address cannot be 0");
        s_payto = payto;
    }
}

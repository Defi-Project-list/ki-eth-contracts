// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./IOracle.sol";
import "./MultiSig.sol";

abstract contract OracleBase is IOracle, MultiSig {
    address payable internal payto;

    function paymentAddress() public view override returns (address payable) {
        return payto;
    }

    function initialized() public view override returns (bool) {
        require(payto != address(0), "payment address cannot be 0");
        return true;
    }

    function setPaymentAddress(address payable _payto)
        public
        override
        multiSig2of3(0)
    {
        require(_payto != address(0), "payment address cannot be 0");
        payto = _payto;
    }
}

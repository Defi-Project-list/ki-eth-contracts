// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./IOracle.sol";
// import "./MultiSig.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

abstract contract OracleBase is IOracle, Ownable {
    address payable internal s_payto;

    function setPaymentAddress(address payable payto)
        external
        override
        onlyOwner()
    {
        require(payto != address(0), "payment address cannot be 0");
        s_payto = payto;
    }

    function paymentAddress() external view override returns (address payable) {
        return s_payto;
    }

    function initialized() external view override returns (bool) {
        //require(s_payto != address(0), "payment address cannot be 0");
        if (s_payto == address(0)) {
            //payment address cannot be 0
            return false;
        }
        return true;
    }
}

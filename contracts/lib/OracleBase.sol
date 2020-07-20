// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./IOracle.sol";

abstract contract OracleBase is IOracle {

    address payable internal payto;

    function paymentAddress() public view override returns (address payable) {
      return payto;
    }

    function initialized() public view override returns (bool) {
      require(payto != address(0), "payment address cannot be 0");
      return true;
    }

    function setPaymentAddress(address payable _payto) public override {
      require(_payto != address(0), "payment address cannot be 0");
      payto = _payto;
    }

}

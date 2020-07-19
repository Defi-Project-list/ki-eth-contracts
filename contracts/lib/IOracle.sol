// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

abstract contract IOracle {

    address internal payto;

    function paymentAddress() public view returns (address) {
      return payto;
    }

    function initialized() public view returns (bool) {
      require(payto != address(0), "payment address cannot be 0");
      return true;
    }

    function is20Safe(address _token) external view virtual returns (bool);
    function is721Safe(address _token) external view virtual returns (bool);
    function version() external pure virtual returns (bytes8);
    function setPaymentAddress(address) external virtual;
}

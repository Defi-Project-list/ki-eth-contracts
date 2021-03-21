// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IOracle {
    function is20Safe(address _token) external view returns (bool);
    function is721Safe(address _token) external view returns (bool);
    function version() external pure returns (bytes8);
    function setPaymentAddress(address payable) external;
    function paymentAddress() external view returns (address payable);
    function initialized() external view returns (bool);
}

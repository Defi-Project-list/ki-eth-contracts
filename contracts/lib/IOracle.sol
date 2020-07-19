// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

interface IOracle {
    function is20Safe(address _token) external view returns (bool);
    function is721Safe(address _token) external view returns (bool);
    function version() external pure returns (bytes8);
}

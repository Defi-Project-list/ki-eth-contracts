pragma solidity 0.4.24;

interface IOracle {
    function isTokenSafe(address _token) external view returns (bool);
}

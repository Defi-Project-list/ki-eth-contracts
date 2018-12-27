pragma solidity 0.4.24;

interface IOracle {
    function is20Safe(address _token) external view returns (bool);
    function is721Safe(address _token) external view returns (bool);
}

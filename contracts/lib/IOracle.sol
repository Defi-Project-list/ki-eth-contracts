pragma solidity 0.5.16;

interface IOracle {
    function is20Safe(address _token) external view returns (bool);
    function is721Safe(address _token) external view returns (bool);
}

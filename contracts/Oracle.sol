pragma solidity 0.4.24;

import "./lib/IOracle.sol";

contract Oracle is IOracle {

    mapping (address=>bool) private whitelist;

    function isTokenSafe(address _token) public view returns (bool) {
        return whitelist[_token];
    }

}
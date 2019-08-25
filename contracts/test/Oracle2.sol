pragma solidity 0.4.24;

import "../lib/IOracle.sol";

contract Oracle2 is IOracle {

    mapping (address=>bool) private tokens;

    function updateToken(address _token, bool _safe) public {
        tokens[_token] = _safe;
    }

    function isTokenSafe(address _token) public view returns (bool) {
        return tokens[_token];
    }

}
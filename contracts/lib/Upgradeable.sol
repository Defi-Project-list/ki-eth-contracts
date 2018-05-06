pragma solidity 0.4.23;

import "./Proxied.sol";

contract Upgradeable is Proxied {

    constructor() public {
        target = address(this);
    }

    function upgradeTo(address) public {
        assert(true); // this is used by isUpgradeable() in Proxy
    }

    modifier initializeOnceOnly() {
        if(!initialized[target]) {
            initialized[target] = true;
            emit EventInitialized(target);
            _;
        }
    }

    function initialize() initializeOnceOnly public {
        // initialize contract state variables here
    }
}

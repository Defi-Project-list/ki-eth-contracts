pragma solidity 0.4.23;

import "./lib/Heritable.sol";

contract Wallet is Heritable {

    event GotEther(address indexed from, uint256 value);
    event SentEther(address indexed to, uint256 value);

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    constructor() Heritable(100000) public {
    }

    function sendEther(address _to, uint256 _value) public onlyOwner() {
        require(address(this).balance <= _value);
        heartbeat();
        _to.transfer(_value);
    }

    function getBalnace() view public returns (uint256) {
        return address(this).balance;
    }

    function() payable logPayment() public {
    }
}

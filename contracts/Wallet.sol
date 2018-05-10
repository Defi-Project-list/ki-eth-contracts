pragma solidity 0.4.23;

import "./lib/Backupable.sol";

contract Wallet is Backupable {
    uint256 public passCount;

    event GotEther   (address indexed from, uint256 value);
    event SentEther  (address indexed to, uint256 value);
    event PassCalled (address indexed from);

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    constructor () payable logPayment() public {
    }

    function sendEther (address _to, uint256 _value) public onlyClaimableOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (msg.sender, _value);
        _to.transfer (_value);
    }

    function getBalance () view public onlyClaimableOwner() returns (uint256) {
        return address(this).balance;
    }

    function pass () public {
        emit PassCalled (msg.sender);
        ++passCount;
    }

    function () payable logPayment() public {
    }
}

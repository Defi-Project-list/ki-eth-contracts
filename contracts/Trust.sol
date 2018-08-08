pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Trust {

    using SafeMath for uint32;
    using SafeMath for uint40;
    using SafeMath for uint256;

    struct Fund {
        address wallet;
        uint40  start;
        uint32  period;
        uint16  times;
        bool    cancelable;
    }

    struct Self {
        address owner;
    }

    uint256 private amount;
    uint256 private payed;
    Fund public fund;
    Self private self;

    event GotEther          (address indexed from, uint256 value);
    event SentEther         (address indexed to, uint256 value);

    constructor (address  _wallet,
                 uint40   _start,
                 uint32   _period,
                 uint16   _times,
                 uint256  _amount,
                 bool     _cancelable)
                payable logPayment() public {

        require(_wallet != address(0));
        require(_wallet != msg.sender);
        require((_start > 0) && (_period > 0) && (_times > 0) && (_amount > 0));
        require(msg.value >= _amount.mul(_times));

        self.owner = msg.sender;
        fund.wallet = _wallet;
        fund.start = _start;
        fund.period = _period;
        fund.times = _times;
        amount = _amount;
        fund.cancelable = _cancelable;
    }

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    modifier onlyOwner () {
        require (msg.sender == self.owner, "msg.sender != self.owner");
        _;
    }

    function isOwner () view public returns (bool) {
        return msg.sender == self.owner;
    }

    function getPaymentValue() view public returns (uint256) {
        // solium-disable-next-line security/no-block-members
        if (block.timestamp < fund.start) {
            return 0;
        }
        // solium-disable-next-line security/no-block-members
        if (block.timestamp >= fund.start.add(fund.period.mul(fund.times))) {
            return address(this).balance;
        }
        // solium-disable-next-line security/no-block-members
        return block.timestamp.sub(fund.start).div(fund.period).add(1).mul(amount).sub(payed);
    }

    function getNextPaymentTimestamp() view public returns (uint256) {
        // solium-disable-next-line security/no-block-members
        if (block.timestamp < fund.start) {
            return fund.start;
        }
        uint256 endTimestamp = fund.start.add(fund.period.mul(fund.times));
        // solium-disable-next-line security/no-block-members
        if (block.timestamp >= endTimestamp) {
            if (address(this).balance > 0) {
                // solium-disable-next-line security/no-block-members
                return uint40(endTimestamp);
            }
            return uint40(0);
        }
        // solium-disable-next-line security/no-block-members
        return fund.start.add(payed.div(amount).mul(fund.period));
    }

    function getTotalPayed () view public returns (uint256) {
        return payed;
    }

    function getPaymentAmount () view public returns (uint256) {
        return amount;
    }

    function activateTrust() public {
        uint256 toPay = getPaymentValue();
        require (toPay > 0);
        payed += toPay;
        fund.wallet.transfer(toPay);
        emit SentEther(fund.wallet, toPay);
    }

    function getBalance () view public returns (uint256) {
        return address(this).balance;
    }

    function destroy() onlyOwner() public {
        selfdestruct (self.owner);
    }

    function () payable logPayment() public {
    }

    function version() pure public returns (bytes8) {
        return bytes8("0.1");
    }
}

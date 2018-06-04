pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
/*

contract Wallet {
    Trust private trust;

    function createTrust(address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable public {
        require(trust == Trust(0));
        trust = (new Trust).value(msg.value)(_wallet, _start, _period, _times, _amount, _cancelable);
    }

    function destroyTrust() public {
        require(trust != Trust(0));
        trust.destroy();
        trust = Trust(0);
    }

    function getTrust() public view returns (Trust) {
        return trust;
    }

    function isContract(address addr) public view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

}
*/

contract Trust {

    using SafeMath for uint32;
    using SafeMath for uint40;
    using SafeMath for uint256;

    struct TrustFund {
        address wallet;
        uint40  start;
        uint32  period;
        uint16  times;
        bool    cancelable;
    }

    struct Self {
        address owner;
        uint16 payments;
    }

    uint256 private amount;
    uint256 private payed;
    TrustFund private trust;
    Self private self;

    event GotEther   (address indexed from, uint256 value);
    event SentEther  (address indexed to, uint256 value);

    constructor (address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable logPayment() public {
        require(_wallet != address(0));
        require(_wallet != msg.sender);
        require((_start > 0) && (_period > 0) && (_times > 0) && (amount > 0));
        require(msg.value >= _amount.mul(_times));

        self.owner = msg.sender;
        trust.wallet = _wallet;
        trust.start = _start;
        trust.period = _period;
        trust.times = _times;
        amount = _amount;
        trust.cancelable = _cancelable;
    }

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    modifier onlyOwner () {
        require (msg.sender == self.owner, "msg.sender != trust.owner");
        _;
    }

    function getPaymentValue() view public returns (uint256) {
        // solium-disable-next-line security/no-block-members
        if (block.timestamp < trust.start) {
            return 0;
        }
        // solium-disable-next-line security/no-block-members
        if (block.timestamp >= trust.start.add(trust.period.mul(trust.times))) {
            return address(this).balance;
        }
        // solium-disable-next-line security/no-block-members
        return block.timestamp.sub(trust.start).div(trust.period).add(1).mul(amount).sub(payed);
    }

    function getNextPaymentTimestamp() view public returns (uint256) {
        // solium-disable-next-line security/no-block-members
        if (block.timestamp < trust.start) {
            return trust.start;
        }
        uint256 endTimestamp = trust.start.add(trust.period.mul(trust.times));
        // solium-disable-next-line security/no-block-members
        if (block.timestamp >= endTimestamp) {
            if (address(this).balance > 0) {
                // solium-disable-next-line security/no-block-members
                return uint40(endTimestamp);
            }
            return uint40(0);
        }
        // solium-disable-next-line security/no-block-members
        return trust.start.add(payed.div(amount).mul(trust.period));
    }

    function getTotalPayed () view public returns (uint256) {
        return payed;
    }

    function activateTrust() public {
        uint256 toPay = getPaymentValue();
        require (toPay > 0);
        payed += toPay;
        trust.wallet.transfer(toPay);
    }

    function getBalance () view public returns (uint256) {
        return address(this).balance;
    }

    function destroy() onlyOwner() public {
        selfdestruct (self.owner);
    }

    function () payable logPayment() public {
    }
}

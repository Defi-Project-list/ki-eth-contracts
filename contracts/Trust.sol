// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

// import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Trust {
    // using SafeMath for uint32;
    // using SafeMath for uint40;
    // using SafeMath for uint256;

    struct Fund {
        address payable wallet;
        uint40 start;
        uint32 period;
        uint16 times;
        bool cancelable;
    }

    struct Self {
        address payable owner;
    }

    uint256 private s_amount;
    uint256 private s_payed;
    Fund private s_fund;
    Self private s_self;

    event GotEther(address indexed from, uint256 value);
    event SentEther(address indexed to, uint256 value);

    constructor(
        address payable wallet,
        uint40 start,
        uint32 period,
        uint16 times,
        uint256 amount,
        bool cancelable
    ) payable logPayment() {
        require(wallet != address(0));
        require(wallet != msg.sender);
        require((start > 0) && (period > 0) && (times > 0) && (amount > 0));
        require(msg.value >= amount * times);

        s_self.owner = payable(msg.sender);
        s_fund.wallet = wallet;
        s_fund.start = start;
        s_fund.period = period;
        s_fund.times = times;
        s_amount = amount;
        s_fund.cancelable = cancelable;
    }

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == s_self.owner, "msg.sender != self.owner");
        _;
    }

    function isOwner() external view returns (bool) {
        return msg.sender == s_self.owner;
    }

    function fund() external view returns (Fund memory) {
      return s_fund;
    }

    function getPaymentValue() public view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        if (block.timestamp < s_fund.start) {
            return 0;
        }
        // solium-disable-next-line security/no-block-members
        if (block.timestamp >= s_fund.start + (s_fund.period * s_fund.times)) {
            return address(this).balance;
        }
        // solium-disable-next-line security/no-block-members
        return
            ((((block.timestamp - s_fund.start) / s_fund.period) + 1) * s_amount) -
            s_payed;
    }

    function getNextPaymentTimestamp() public view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        if (block.timestamp < s_fund.start) {
            return s_fund.start;
        }
        uint256 endTimestamp = s_fund.start + (s_fund.period * s_fund.times);
        // solium-disable-next-line security/no-block-members
        if (block.timestamp >= endTimestamp) {
            if (address(this).balance > 0) {
                // solium-disable-next-line security/no-block-members
                return uint40(endTimestamp);
            }
            return uint40(0);
        }
        // solium-disable-next-line security/no-block-members
        return s_fund.start + ((s_payed / s_amount) * s_fund.period);
    }

    function getTotalPayed() public view returns (uint256) {
        return s_payed;
    }

    function getPaymentAmount() public view returns (uint256) {
        return s_amount;
    }

    function activateTrust() public {
        uint256 toPay = getPaymentValue();
        require(toPay > 0);
        s_payed += toPay;
        s_fund.wallet.transfer(toPay);
        emit SentEther(s_fund.wallet, toPay);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function destroy() public onlyOwner() {
        selfdestruct(s_self.owner);
    }

    receive() external payable logPayment() {}

    function version() public pure returns (bytes8) {
        return bytes8("0.1");
    }
}

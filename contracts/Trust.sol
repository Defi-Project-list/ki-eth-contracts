// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

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

contract Trust {
    uint256 private s_amount;
    uint256 private s_payed;
    Fund private s_fund;
    Self private s_self;

    event GotEther(address indexed from, uint256 value);
    event SentEther(address indexed to, uint256 value);

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == s_self.owner, "TRUST: msg.sender != self.owner");
        _;
    }

    constructor(
        address payable wallet,
        uint40 start,
        uint32 period,
        uint16 times,
        uint256 amount
    ) payable logPayment() {
        require(wallet != address(0), "TRUST: no wallet");
        require(wallet != msg.sender, "TRUST: wallet is not sender");
        require((start > 0) && (period > 0) && (times > 0) && (amount > 0), "TRUST: zero not allowed");
        require(msg.value >= amount * times, "TRUST: mismatch amount");

        s_self.owner = payable(msg.sender);
        s_fund.wallet = wallet;
        s_fund.start = start;
        s_fund.period = period;
        s_fund.times = times;
        s_amount = amount;
    }

    receive() external payable logPayment() {}

    function activateTrust() external {
        uint256 toPay = getPaymentValue();
        require(toPay > 0, "TRUST: payment is 0");
        s_payed += toPay;
        (bool success, ) = s_fund.wallet.call{value: toPay}("");
        require(success, "TRUST: send funds failed");
        emit SentEther(s_fund.wallet, toPay);
    }

    function destroy() external onlyOwner() {
        selfdestruct(s_self.owner);
    }

    function isOwner() external view returns (bool) {
        return msg.sender == s_self.owner;
    }

    function fund() external view returns (Fund memory) {
        return s_fund;
    }

    function getNextPaymentTimestamp() external view returns (uint256) {
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

    function getTotalPayed() external view returns (uint256) {
        return s_payed;
    }

    function getPaymentAmount() external view returns (uint256) {
        return s_amount;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function version() external pure returns (bytes8) {
        return bytes8("0.1");
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
            ((((block.timestamp - s_fund.start) / s_fund.period) + 1) *
                s_amount) - s_payed;
    }
}

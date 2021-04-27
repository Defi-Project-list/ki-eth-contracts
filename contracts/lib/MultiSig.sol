// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

abstract contract MultiSig {
    mapping(address => bool) private s_owners;

    struct Action {
        address owner;
        uint256 value;
        bytes data;
    }

    Action private s_action;

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) {
        require(owner1 != address(0), "owner1 cannot be 0");
        require(owner2 != address(0), "owner2 cannot be 0");
        require(owner3 != address(0), "owner3 cannot be 0");

        require(owner1 != owner2, "owner1 cannot be owner2");
        require(owner2 != owner3, "owner2 cannot be owner3");
        require(owner1 != owner3, "owner1 cannot be owner3");

        s_owners[owner1] = true;
        s_owners[owner2] = true;
        s_owners[owner3] = true;
    }

    modifier multiSig2of3(uint256 value) {
        require(s_owners[msg.sender], "only owners");

        if (s_action.owner == address(0)) {
            s_action.owner = msg.sender;
            s_action.data = msg.data;
            s_action.value = value;
            return;
        }

        require(s_action.owner != msg.sender, "same owner cannot sign twice");
        require(s_action.value == value, "must sign the same value");
        require(
            keccak256(s_action.data) == keccak256(msg.data),
            "must sign the same data"
        );

        s_action.owner = address(0);
        _;
    }

    function isOwner() public view returns (bool) {
        return s_owners[msg.sender];
    }

    function cancel() public {
        require(s_owners[msg.sender], "only owners");
        s_action.owner = address(0);
    }

    function replaceOwner(address owner, address newOwner)
        public
        multiSig2of3(0)
    {
        require(s_owners[owner] == true, "owner should exist");
        require(s_owners[newOwner] == false, "new owner should not exist");
        s_owners[owner] = false;
        s_owners[newOwner] = true;
    }
}

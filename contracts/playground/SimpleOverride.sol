pragma solidity ^0.4.17;

contract A {
    uint public count;

    function incCount () public {
        ++count;
    }
}

contract B is A {
    uint public count2;

    function incCount () public {
        super.incCount();
        ++count2;
    }
}

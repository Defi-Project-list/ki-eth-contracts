pragma solidity ^0.4.17;

contract VisibilityPrice {
    uint private count;

    function incCount () public {
        ++count;
    }

    function pubGetCount () public view returns (uint) {
        return count;
    }

    function intGetCount () internal view returns (uint) {
        return count;
    }

    function prvGetCount () private view returns (uint) {
        return count;
    }

    function extGetCount () external view returns (uint) {
        return count;
    }

    function incCountPub () public returns (uint) {
        ++count;
        return pubGetCount();
    }

    function incCountInt () public returns (uint) {
        ++count;
        return intGetCount();
    }

    function incCountPrv () public returns (uint) {
        ++count;
        return prvGetCount();
    }

    //Not Possible
    /*
    function incCountExt () public returns (uint) {
        ++count;
        return extGetCount();
    }
    */

    function incCountDirect () public returns (uint) {
        ++count;
        return count;
    }

}

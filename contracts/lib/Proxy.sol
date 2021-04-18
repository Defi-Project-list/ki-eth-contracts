// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./StorageBase.sol";

contract Proxy is StorageBase {
    receive() external payable {
        revert("should not accept ether directly");
    }

    function transferEth(/*address payable _refund,*/ address payable _to, uint256 _value)
        public
        onlyCreator()
    {
        (bool success, bytes memory res) = 
            _to.call{gas: 20000, value: _value}("");
        if (!success) {
            revert(_getRevertMsg(res));
        }
        // _refund.call{value: tx.gasprice * 5000, gas: 10000}("");
        // _to.transfer(_value);
    }

    function transferERC20(/*uint256 _refundValue, address _refundAddress,*/ address _token, address payable _to, uint256 _value)
        external
        onlyCreator()
    {
        // uint256 gas = gasleft() + 40000;
        (bool success, bytes memory res) = 
            _token.call{gas: 80000}(abi.encodeWithSignature("transfer(address,uint256)", _to, _value));
        if (!success) {
            revert(_getRevertMsg(res));
        }
        // _token.call{gas: 80000}(abi.encodeWithSignature("transfer(address,uint256)", _refundAddress, _refundValue));
        // _refund.call{value: tx.gasprice * (gas-gasleft()), gas: 10000}("");
    }

    function _getRevertMsg(bytes memory returnData)
        internal
        pure
        returns (string memory)
    {
        if (returnData.length < 68)
            return "Wallet: Transaction reverted silently";

        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    fallback() external payable {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let res := delegatecall(
                gas(),
                sload(_target.slot),
                0x00,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0x00, 0x00, returndatasize())
            if res {
                return(0x00, returndatasize())
            }
            revert(0x00, returndatasize())
        }
    }
}

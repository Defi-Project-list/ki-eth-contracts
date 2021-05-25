// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./StorageBase.sol";

contract Proxy is StorageBase {

    fallback() external payable {
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let res := delegatecall(
                gas(),
                sload(s_target.slot),
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

    receive() external payable {
        revert("should not accept ether directly");
    }

    function call(address target, uint256 value, /*uint256 gas,*/ bytes calldata data) external onlyCreator() {
      (bool success, bytes memory res) = 
        target.call{value: value}(data);
      if (!success) {
        revert(_getRevertMsg(res));
      }
    }

    function transferEth(address payable to, uint256 value)
        external
        onlyCreator()
    {
        (bool success, bytes memory res) = 
            to.call{gas: 20000, value: value}("");
        if (!success) {
            revert(_getRevertMsg(res));
        }
    }

    function transferERC20(address token, address payable to, uint256 value)
        external
        onlyCreator()
    {
        (bool success, bytes memory res) = 
            token.call{gas: 80000}(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        if (!success) {
            revert(_getRevertMsg(res));
        }
    }

    function staticcall(address target, bytes calldata data) external view onlyCreator() {
      (bool success, bytes memory res) = 
        target.staticcall(data);
      if (!success) {
        revert(_getRevertMsg(res));
      }
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

}

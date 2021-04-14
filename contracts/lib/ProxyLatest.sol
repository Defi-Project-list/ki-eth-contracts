// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./StorageBase.sol";

contract ProxyLatest is StorageBase {
    receive() external payable {
        revert("should not accept ether directly");
    }

    function transferEth(address payable _to, uint256 _value)
        public
        onlyCreator()
    {
        _to.transfer(_value);
    }

    function transferERC20(address _token, address payable _to, uint256 _value)
        external
        onlyCreator()
    {
        (bool success, bytes memory res) = 
            _token.call(abi.encodeWithSignature("transfer(address,uint256)", _to, _value));
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

    fallback() external payable {
        address latest = ICreator(this.creator()).getLatestVersion();
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let res := delegatecall(gas(), latest, 0x00, calldatasize(), 0, 0)
            returndatacopy(0x00, 0x00, returndatasize())
            if res {
                return(0x00, returndatasize())
            }
            revert(0x00, returndatasize())
        }
    }
}

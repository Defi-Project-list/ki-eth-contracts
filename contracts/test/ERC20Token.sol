// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Capped.sol";
import "../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";

contract ERC20Token is ERC20, ERC20Capped, ERC20Burnable {

    constructor(
        string memory name,
        string memory symbol
    )
        ERC20Burnable()
        ERC20Capped(20000)
        ERC20(name, symbol)
        public
    {}

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Capped) { }

    function mint (address account, uint256 amount) public {
      _mint(account, amount);
    }

}

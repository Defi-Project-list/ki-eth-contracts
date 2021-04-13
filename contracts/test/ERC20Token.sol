// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ERC20Token is ERC20, ERC20Capped, ERC20Burnable {
    constructor(string memory name, string memory symbol)
        ERC20Burnable()
        ERC20Capped(20000)
        ERC20(name, symbol)
    {}

    // function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Capped) { }
    function _mint(address account, uint256 amount)
        internal
        override(ERC20, ERC20Capped)
    {
        ERC20Capped._mint(account, amount);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function transfer(address account, uint256 amount) public override returns (bool) {
        // _mint(account, amount);
        // _burn(account, amount);
        // _mint(account, amount);
        // _burn(account, amount);
        // _mint(account, amount);
        // _burn(account, amount);
        // _mint(account, amount);
        // _burn(account, amount);
        // _mint(account, amount);
        // _burn(account, amount);
        super.transfer(account, amount);
    }

}

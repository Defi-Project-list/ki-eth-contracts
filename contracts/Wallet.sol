// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

//import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol";

import "./lib/IOracle.sol";
import "./lib/Heritable.sol";
//import "./Trust.sol";

contract Wallet is IStorage, Heritable {
    //using SafeMath for uint256;

    event SentEther     (address indexed creator, address indexed owner, address indexed to, uint256 value);
    event Transfer20    (address indexed creator, address indexed token, address from, address indexed to, uint256 value);
    event Transfer721   (address indexed creator, address indexed token, address from, address indexed to, uint256 id, bytes data);

    function sendEther (address payable _to, uint256 _value) public onlyActiveOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (this.creator(), address(this), _to, _value);
        _to.transfer (_value);
    }

    function transfer20 (address _token, address _to, uint256 _value) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        emit Transfer20 (this.creator(), _token, address(this), _to, _value);
        IERC20(_token).transfer(_to, _value);
    }

    function transferFrom20 (address _token, address _from, address _to, uint256 _value) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this): address(_from);
        emit Transfer20 (this.creator(), _token, from, _to, _value);
        IERC20(_token).transferFrom(_from, _to, _value);
    }

    function transfer721 (address _token, address _to, uint256 _value) public onlyActiveOwner() {
        transferFrom721 (_token, address(0), _to, _value);
    }

    function transferFrom721 (address _token, address _from, address _to, uint256 _id) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this): address(_from);
        emit Transfer721 (this.creator(), _token, from, _to, _id, "");
        IERC721(_token).transferFrom(address(this), _to, _id);
    }

    function safeTransferFrom721 (address _token, address _from, address _to, uint256 _id) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this): address(_from);
        emit Transfer721 (this.creator(), _token, from, _to, _id, "");
        IERC721(_token).safeTransferFrom(address(this), _to, _id);
    }

    function safeTransferFrom721$Data (address _token, address _from, address _to, uint256 _id, bytes memory _data) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this): address(_from);
        emit Transfer721 (this.creator(), _token, from, _to, _id, _data);
        IERC721(_token).safeTransferFrom(address(this), _to, _id, _data);
    }

    function getBalance () public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf20 (address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function balanceOf721 (address _token) public view returns (uint256) {
        return IERC721(_token).balanceOf(address(this));
    }

    function is20Safe (address _token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).is20Safe(_token);
    }

    function is721Safe (address _token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).is721Safe(_token);
    }

    //function onERC721Received(address operator, address from, uint256 tokenId, bytes data) public returns (bytes4) {
    function onERC721Received (address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*
    function createTrust(address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable public {
        require(trust == Trust(0));
        trust = (new Trust).value(_amount.mul(_times))(_wallet, _start, _period, _times, _amount, _cancelable);
    }

    function destroyTrust() public {
        require(trust != Trust(0));
        trust.destroy();
        trust = Trust(0);
    }

    function getTrust() public view returns (Trust) {
        return trust;
    }
    */

    // IStorage Implementation
    function migrate () external onlyCreator() override {}

    function version() public pure override returns (bytes8){
        return bytes8("1.2.1");
    }

}

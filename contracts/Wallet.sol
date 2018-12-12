pragma solidity 0.4.24;

//import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol";

import "./lib/IOracle.sol";
import "./lib/Heritable.sol";
//import "./Trust.sol";

contract Wallet is IStorage, Heritable {
    //using SafeMath for uint256;

    event SentEther     (address indexed creator, address indexed owner, address indexed to, uint256 value);
    event Transfer20    (address indexed creator, address indexed owner, address indexed to, uint256 value);
    event Transfer721   (address indexed creator, address indexed owner, address indexed to, uint256 id);

    function sendEther (address _to, uint256 _value) public onlyActiveOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (this.creator(), owner, _to, _value);
        _to.transfer (_value);
    }

    function transfer20 (address _token, address _to, uint256 _value) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        emit Transfer20 (this.creator(), owner, _to, _value);
        IERC20(_token).transfer(_to, _value);
    }

    function transfer721 (address _token, address _to, uint256 _id) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        emit Transfer721 (this.creator(), owner, _to, _id);
        IERC721(_token).transferFrom(address(this), _to, _id);
    }

    function getBalance () public view returns (uint256) {
        return address(this).balance;
    }

    function get20Balance (address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function is20Safe (address _token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).isTokenSafe(_token);
    }

    //function onERC721Received(address operator, address from, uint256 tokenId, bytes data) public returns (bytes4) {
    function onERC721Received (address, address, uint256, bytes) public pure returns (bytes4) {
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
    function migrate () external onlyCreator()  {
    }

    function version() public pure returns (bytes8){
        return bytes8("1.1.12");
    }

}

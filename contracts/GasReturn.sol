// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "./lib/Backupable.sol";
import "./lib/DateTime.sol";
import "./Factory.sol";

abstract contract GasReturn is AccessControl, Backupable, DateTime
    //, Factory
    //, IKiroboNFT 
    {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address private owner;
    uint256 public totalBalance;
    uint256 public _kiroPrice;
    uint256 private _stakingAmountNeeded;
    uint256 private _timeInStaking = 31556926; //180 days
    address private _kiroEthPairAddress = 0x5CD136E8197Be513B06d39730dc674b1E0F6b7da;
    uint256 private _timeBetweenKiroPriceUpdate;
    uint256 public lastUpdateDateOfPrice;

    // keccak256("ACTIVATOR_ROLE");
    bytes32 public constant ACTIVATOR_ROLE = 0xec5aad7bdface20c35bc02d6d2d5760df981277427368525d634f4e2603ea192;
    /* struct User{
        address userAddr;
        uint256 amount;
        uint256 lockedUntil;
    } */

    event TransferReceived(address from, uint256 amount);
    event TransferSent(address from, address to, uint256 amount);

    mapping (uint256 => mapping(address => uint256)) balancesPerMonthPerWallet;
    mapping (uint256 => mapping(address => uint256)) rewardsPerMonthPerNFT;
    /* mapping (bytes32 => uint256) userStructs;
    mapping (bytes32 => User) userAddresses;
 */
    modifier onlyActivator() {
        require(
            hasRole(ACTIVATOR_ROLE, msg.sender),
            "SafeSwap: not an activator"
        );
        _;
    }

    constructor (address activator){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ACTIVATOR_ROLE, msg.sender);
        _setupRole(ACTIVATOR_ROLE, activator);
    }
    /* receive() payable external {
        balance += msg.value;
        addUserToContract(msg.sender, msg.value);
        emit TransferReceived(msg.sender, msg.value);
    } */

    /* function withdraw(uint amount, address payable to) public {
        require(msg.sender == owner, "Only owner can withdraw funds");
        require(amount <= balance, "insufficient funds");
        to.transfer(amount);
        balance -= amount;
        emit TransferSent(msg.sender, to, amount);
    } */
    function updateTimeBetweenKiroPriceUpdate(uint256 time) private onlyActivator {
        _timeBetweenKiroPriceUpdate = time;
        lastUpdateDateOfPrice = block.timestamp;
    }

    // calculate price based on pair reserves
   function getTokenPrice(address pairAddress, uint amount) public view returns(uint)
   {
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    ERC20 token1 = ERC20(pair.token1.address);
    (uint Res0, uint Res1,) = pair.getReserves();

    // decimals
    uint res0 = Res0*(10**token1.decimals());
    return((amount*res0)/Res1); // return amount of token0 needed to buy token1
   }


    function updateTimeInStaking(uint256 newTimeInStaking) private onlyActivator {
        _timeInStaking = newTimeInStaking;
    }

    function getTimeInStaking() public view returns(uint256 timeInStaking){
        timeInStaking= _timeInStaking;
    }


    function updateKiroPrice() private onlyActivator{
        _kiroPrice = getTokenPrice(_kiroEthPairAddress, 1);
    }

    function getKiroPrice() public view returns(uint256 kiroPrice){
        kiroPrice = _kiroPrice;
    }

    //gets a timestamp date that is made from the year, month and the first day of the month
    function getCurrentYearMonth() public view returns(uint256 yearMonth){
        uint8 day = 2;
        yearMonth = DateTime.toTimestamp(DateTime.getYear(block.timestamp), DateTime.getMonth(block.timestamp), day);
    }

    function updateStakingAmountNeeded(uint256 newStakingAmountNeeded) private onlyActivator {
        _stakingAmountNeeded = newStakingAmountNeeded;
    } 

    function getNFTRewardAmount(address nft) public view returns(uint256 NFTReward) {
        //need to get ID of nft
        //then call NFTReward = IKiroboNFT.getProps(ID)
    }

    function calcReward(uint256 yearMonth, address nft, uint256 amountOfGasInKiro) private onlyActivator returns(uint256 rewardInKiroToAdd){
        uint256 rewardOfNFT = getNFTRewardAmount(nft);
        uint256 curRewards = rewardsPerMonthPerNFT[yearMonth][nft];
        if(curRewards + amountOfGasInKiro >= rewardOfNFT){
            rewardsPerMonthPerNFT[yearMonth][nft] += amountOfGasInKiro;
            rewardInKiroToAdd = amountOfGasInKiro;
        }
        else{//amountOfGasInKiro is grater then the rewards left according to the NFT data
            rewardInKiroToAdd = rewardOfNFT - curRewards;
            rewardsPerMonthPerNFT[yearMonth][nft] += rewardInKiroToAdd;
        }
    }

    function gasReturnExecute(address to, uint256 value, bytes calldata data) public onlyActiveOwner returns(bytes memory res){
        address wallet = Factory.getWallet(msg.sender);
        address nft = Factory.getNft(msg.sender);
        uint256 yearMonth = getCurrentYearMonth();
        uint256 staking = Factory.getStaking(msg.sender);
        require(staking >= _stakingAmountNeeded);
        res = wallet.execute2(to, value, data);
        if( block.timestamp > lastUpdateDateOfPrice + _timeBetweenKiroPriceUpdate )
        {
            updateKiroPrice();
        }
        uint256 toPayInKiro =  res.gas * _kiroPrice;
        uint256 updatedAmountToPay = calcReward(yearMonth, nft, toPayInKiro);
        balancesPerMonthPerWallet[yearMonth][wallet] += updatedAmountToPay;
        totalBalance -= updatedAmountToPay;
    }

    function isMonthOver(uint256 yearMonth) public view returns(bool){
        uint256 currentYearMonth = getCurrentYearMonth();
        if(currentYearMonth > yearMonth)
            return true;
        else 
            return false;
    }

    /* function gasLeft() public view returns(uint256 gas){
        gas = 0;
    } */

    /* function transferGasRewards(uint256 rewardsMonth) public {
        require(isMonthOver(rewardsMonth), "reward month not over yet");
        address wallet = Factory.getWallet(msg.sender);
        uint256 amount = balances[rewardsMonth][wallet];

        delete balances[rewardsMonth][wallet];
        IERC20(kiroTokenAddress).safeTransferFrom(owner, wallet, amount);
        emit TransferSent(msg.sender, wallet, amount);
    } */

    /* function transferERC20(IERC20 kiroTokenAddress, address to, uint256 amount) public {
        bytes32 id = keccak256(abi.encode(to, amount));
        uint256 tr = userStructs[id];
        require(tr > 0, "SafeTransfer: request not exist");
        User memory user = userAddresses[id];
        require(user.lockedUntil <= block.timestamp, "too early");
        delete userStructs[id];
        delete userAddresses[id];

        uint256 erc20balance = token.balanceOf(address(this));
        require(user.amount <= erc20balance, "balance in contract is too low");
        balance -= user.amount;
        IERC20(kiroTokenAddress).safeTransferFrom(owner, user.userAddr, user.amount);
        emit TransferSent(msg.sender, user.userAddr, user.amount);
    } */

    /* function addUserToContract(address _from,uint256 _amount) public {
        User memory user;
        user.userAddr = _from;
        user.amount = _amount;
        user.lockedUntil = block.timestamp + _timeInStaking;

        bytes32 id = keccak256(abi.encode(user.userAddr, user.amount));
        userStructs[id] = 0xffffffffffffffff;
        userAddresses[id] = user;
    } */

    function supportsInterface(bytes4 interfaceId) public pure virtual override(Interface, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
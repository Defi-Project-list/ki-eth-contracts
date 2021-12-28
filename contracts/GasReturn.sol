// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "./lib/DateTime.sol";

interface IFactory {
    function getWallet(address account) external view returns (address);
}

interface IWallet {
    function getBackupState() external view returns (uint8);
    function execute2(address to, uint256 value, bytes calldata data) external returns(bytes memory);
    function getStaking() external view returns(uint256);
}

interface INFT {
    function getId() external view returns (uint256);
    function getMintInfo() external view returns (uint256 nftPrice,uint256 startPrice,uint256 endPrice,uint256 startTime,uint256 endTime);
    function getProperties(uint256 i_id) external view returns (uint128 stakingBenefit, uint128 gasReturnBenefit); 
    function getGasReturnBaseValue() external view returns (uint256);
}

contract GasReturn is AccessControl, DateTime
    {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 public s_totalBalance;
    uint256 public s_kiroPrice;
    uint256 public s_kiroPriceInUSD;
    uint256 private s_stakingAmountNeeded;
    uint256 private s_timeInStaking = 31556926; //180 days
    address private s_kiroEthPairAddress = 0x5CD136E8197Be513B06d39730dc674b1E0F6b7da;
    address private s_EthUSDCPairAddress = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    uint256 private s_timeBetweenKiroPriceUpdate;
    uint256 public s_lastUpdateDateOfPrice;
    address public s_nft;
    address private s_factory;
    
    // keccak256("ACTIVATOR_ROLE");
    bytes32 public constant ACTIVATOR_ROLE = 0xec5aad7bdface20c35bc02d6d2d5760df981277427368525d634f4e2603ea192;
    address public constant KIRO_ADDRESS = 0xB1191F691A355b43542Bea9B8847bc73e7Abb137;
    uint8 private constant BACKUP_STATE_ACTIVATED = 3;

    event TransferReceived(address from, uint256 amount);
    event TransferSent(address from, address to, uint256 amount);

    mapping (uint256 => mapping(address => uint256)) balancesPerMonthPerWallet;
    mapping (uint256 => mapping(uint256 => uint256)) rewardsPerMonthPerNFT;
 
    modifier onlyActivator() {
        require(
            hasRole(ACTIVATOR_ROLE, msg.sender),
            "SafeSwap: not an activator"
        );
        _;
    }

    constructor (address activator, address factory, address nft){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ACTIVATOR_ROLE, msg.sender);
        _setupRole(ACTIVATOR_ROLE, activator);

        s_factory = factory;
        s_nft = nft;
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
        s_timeBetweenKiroPriceUpdate = time;
        s_lastUpdateDateOfPrice = block.timestamp;
    }

    // calculate price based on pair reserves
    function getTokenPrice(address pairAddress, uint amount) public view returns(uint)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        ERC20 token1 = ERC20(pair.token1.address);
        (uint Res0, uint Res1,) = pair.getReserves();
        uint res0 = Res0*(10**token1.decimals());
        return((amount*res0)/Res1); // return amount of token0 needed to buy token1
    }

    function updateKiroPrice() private onlyActivator{
        s_kiroPrice = getTokenPrice(s_kiroEthPairAddress, 1);
        s_kiroPriceInUSD = s_kiroPrice * getTokenPrice(s_EthUSDCPairAddress, 1);
    }

    function updateTimeInStaking(uint256 newTimeInStaking) private onlyActivator {
        s_timeInStaking = newTimeInStaking;
    }

    function getTimeInStaking() public view returns(uint256 timeInStaking){
        timeInStaking= s_timeInStaking;
    }

    function getKiroPrice() public view returns(uint256 kiroPrice){
        kiroPrice = s_kiroPrice;
    }

    //gets a timestamp date that is made from the year, month and the first day of the month
    function getCurrentYearMonth() public view returns(uint256 yearMonth){
        uint8 day = 2;
        yearMonth = DateTime.toTimestamp(DateTime.getYear(block.timestamp), DateTime.getMonth(block.timestamp), day);
    }

    function updateStakingAmountNeeded(uint256 newStakingAmountNeeded) private onlyActivator {
        s_stakingAmountNeeded = newStakingAmountNeeded;
    } 

    function calcReward(uint256 yearMonth, uint256 amountOfGasInKiro) private onlyActivator returns(uint256 rewardInKiroToAdd){
        /* uint256 id = INFT(s_nft).getId();
        uint256 gasReturnBaseValue = INFT(s_nft).getGasReturnBaseValue();
        (uint128 stakingBenefit, uint128 gasReturnBenefit) = INFT(s_nft).getProperties(id);
        uint256 kiroPriceInUSD ;
        uint256 totalGasReturnInKiro = (s_kiroPriceInUSD * gasReturnBaseValue * gasReturnBenefit) / 100;
        uint256 curRewards = rewardsPerMonthPerNFT[yearMonth][id];
        if(curRewards + amountOfGasInKiro <= totalGasReturnInKiro){
            rewardsPerMonthPerNFT[yearMonth][id] += amountOfGasInKiro;
            rewardInKiroToAdd = amountOfGasInKiro;
        }
        else{//amountOfGasInKiro is grater then the rewards left according to the NFT data
            rewardInKiroToAdd = totalGasReturnInKiro - curRewards;
            rewardsPerMonthPerNFT[yearMonth][id] += rewardInKiroToAdd;
        } */
        rewardInKiroToAdd = 1;
    }

    function gasReturnExecute(address to, uint256 value, bytes calldata data) public returns(bytes memory res){
        uint256 gasStart = gasleft();
        address wallet = IFactory(s_factory).getWallet(msg.sender);
        require(wallet != address(0), "wallet address doesn't exist");
        require(IWallet(wallet).getBackupState() != BACKUP_STATE_ACTIVATED,"wallet owner is not in active state");
        uint256 yearMonth = getCurrentYearMonth();

        uint256 staking = IERC20(KIRO_ADDRESS).balanceOf(wallet);
        require(staking >= s_stakingAmountNeeded, "Wallet must hold Kiro in order to make this action");

        res = IWallet(wallet).execute2(to, value, data);
        if( block.timestamp > s_lastUpdateDateOfPrice + s_timeBetweenKiroPriceUpdate )
        {
            updateKiroPrice();
        }
        uint256 totalGas = gasStart - gasleft();
        uint256 toPayInKiro =  totalGas * tx.gasprice * s_kiroPrice;
        uint256 updatedAmountToPay = calcReward(yearMonth, toPayInKiro);
        balancesPerMonthPerWallet[yearMonth][wallet] += updatedAmountToPay;
        s_totalBalance -= updatedAmountToPay;
    }

    function isMonthOver(uint256 yearMonth) public view returns(bool){
        uint256 currentYearMonth = getCurrentYearMonth();
        if(currentYearMonth > yearMonth)
            return true;
        else 
            return false;
    }

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
}
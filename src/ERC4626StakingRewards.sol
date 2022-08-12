// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import {ERC4626}         from "solmate/mixins/ERC4626.sol";
import {ERC20}           from "solmate/tokens/ERC20.sol";
import {Owned}           from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {RemcoMathLib}    from "RemcoMath/RemcoMathLib.sol";


/// @notice Curve style staking gauge.
/// @author 0xBoredRetard
abstract contract ERC4626StakingRewards is Owned, ERC4626 {
    using SafeTransferLib for ERC20;
    using RemcoMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Harvest(address indexed account, uint256 rewards);

    event RewardAdded(uint256 rewards);

    /// -----------------------------------------------------------------------
    /// Mutables
    /// -----------------------------------------------------------------------

    // struct EpochInfo {
    //     uint32 periodFinish;
    //     uint32 rewardsDuration;
    //     uint96 rewardRate;
    //     uint96 lastUpdateTime;
    // }

    // address public rewardsDistribution;

    uint256 public periodFinish;

    uint256 public rewardRate; 

    uint256 public rewardsDuration;

    uint256 public lastUpdateTime;

    uint256 public rewardPerTokenStored; 

    mapping(address => uint256) public pending; // renamed from 'rewards'

    mapping(address => uint256) public userRewardPerTokenPaid;

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    ERC20 public immutable reward;

    constructor(
        ERC20 _asset,
        ERC20 _reward, 
        string memory _name, 
        string memory _symbol,
        uint256 _rewardsDuration
    ) ERC4626(_asset, _name, _symbol) Owned(msg.sender) {
        reward = _reward;

        rewardsDuration = _rewardsDuration;
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier updateRewards() {

        rewardPerTokenStored = rewardPerToken();
        
        lastUpdateTime = lastTimeRewardApplicable();

        pending[msg.sender] = earned(msg.sender);
        
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;

        _;
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function deposit(
        uint256 assets, 
        address receiver
    ) public virtual override updateRewards returns (uint256 shares) {
        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares, 
        address receiver
    ) public virtual override updateRewards returns (uint256 assets) {
        return super.deposit(shares, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override updateRewards returns (uint256 shares) {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override updateRewards returns (uint256 assets) {
        return super.redeem(shares, receiver, owner);
    }

    function exit() external updateRewards {
        
        // withdraw entire balance
        redeem(balanceOf[msg.sender], msg.sender, msg.sender);

        // then collect rewards (if any)
        getReward();
    }

    function getReward() public updateRewards returns (uint256 pendingRewards) {
        
        // cache pending rewards first to avoid sloads
        pendingRewards = pending[msg.sender];
        
        if (pendingRewards > 0) {
            
            // delete for gas refund
            delete pending[msg.sender];
            
            // send user pending rewards
            reward.safeTransfer(msg.sender, pendingRewards);
            
            emit Harvest(msg.sender, pendingRewards);
        }
    }

    /// -----------------------------------------------------------------------
    /// 
    /// -----------------------------------------------------------------------

    function notifyRewardAmount(uint256 rewards) external {
        // require(msg.sender == rewardsDistribution, "Caller is not RewardsDistribution contract");
        
        rewardPerTokenStored = rewardPerToken();

        reward.safeTransferFrom(msg.sender, address(this), rewards);

        rewardRate = block.timestamp < periodFinish ? 
            (rewards + ((periodFinish - block.timestamp) * rewardRate)) / rewardsDuration :
            rewards / rewardsDuration;


        lastUpdateTime = block.timestamp;

        periodFinish = block.timestamp + rewardsDuration;
        
        emit RewardAdded(rewards);
    }

    // // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    // function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
    //     require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
    //     IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
    //     emit Recovered(tokenAddress, tokenAmount);
    // }

    // function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    //     require(
    //         block.timestamp > periodFinish,
    //         "Previous rewards period must be complete before changing the duration for the new period"
    //     );
    //     rewardsDuration = _rewardsDuration;
    //     emit RewardsDurationUpdated(rewardsDuration);
    // }

    /// -----------------------------------------------------------------------
    /// Viewables
    /// -----------------------------------------------------------------------

    // not sure if this is correct
    function totalAssets() public override virtual view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function lastTimeRewardApplicable() public virtual view returns (uint256) {
        uint256 end = periodFinish;
        return block.timestamp < end ? block.timestamp : end;
    }

    function rewardPerToken() public virtual view returns (uint256) {
        if (totalSupply == 0) return rewardPerTokenStored;
        // 1e18 should be replaced to account for other token decimals
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate).mulDiv(1e18, totalSupply);
    }

    function earned(address account) public virtual view returns (uint256) {
        // 1e18 should be replaced to account for other token decimals
        return balanceOf[account].mulDiv(rewardPerToken() - userRewardPerTokenPaid[account], 1e18) + pending[account];
    }
    
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }
}
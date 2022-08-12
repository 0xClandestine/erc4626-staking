// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import {ERC20}             from "solmate/tokens/ERC20.sol";
import {ERC4626}           from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib}   from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";


contract ERC4626Gauge is ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256; // remco math lib broke af

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    
    event Update();

    event EmergencyWithdraw(address indexed owner, uint256 assets);

    /// -----------------------------------------------------------------------
    /// Mutables
    /// -----------------------------------------------------------------------

    ERC20 public reward;

    uint256 public accRewardsPerShare;
    uint256 public rewardsPerSecond;
    uint256 public lastRewardTime = block.timestamp;

    mapping(address => uint256) public rewardDebtOf;
    mapping(address => uint256) public rewardCreditsOf;

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    uint256 internal constant WAD = 1e12;

    constructor(
        ERC20 _asset,
        ERC20 _reward,
        uint256 _rewardsPerSecond
    ) ERC4626(_asset, "", "") {
        require(_asset != _reward);
        reward = _reward;
        rewardsPerSecond = _rewardsPerSecond;
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public  returns (uint256 rewardsPerShare) {
        
        if (block.timestamp <= lastRewardTime) return accRewardsPerShare;

        uint256 supply = totalSupply;
        
        if (supply == 0) {
            lastRewardTime = block.timestamp;
            return accRewardsPerShare;
        }

        rewardsPerShare = accRewardsPerShare + rewardsPerSecond * WAD / supply;
        
        accRewardsPerShare = rewardsPerShare;

        lastRewardTime = block.timestamp;
    }

    // TODO override(ERC4626) transfer and transferFrom
    function _transferRewardDebt(
        address from, 
        address to, 
        uint256 amount
    ) internal virtual {
        if (from != to) {
            // avoid sloads
            uint256 fromRewardDebt = rewardDebtOf[from];

            // calculate amount of reward debt that should be transfered from sender
            uint256 rewardDebtAmount = FixedPointMathLib.mulDivDown(amount, fromRewardDebt, balanceOf[from]);

            // subtract reward debt from sender
            rewardDebtOf[from] = fromRewardDebt - rewardDebtAmount;

            // safe because total reward debt cannot exceed 2**256
            unchecked {

                // add reward debt to recipient
                rewardDebtOf[to] += rewardDebtAmount;
            }
        }
    }

    // Safe reward transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeRewardTransfer(address _to, uint256 _amount) internal virtual {
        rewardCreditsOf[_to] += _amount;
    }

    function deposit(
        uint256 assets, 
        address receiver
    ) public virtual override(ERC4626) returns (uint256 shares) {
        uint256 rewardsPerShare = updatePool();
        uint256 userBal = balanceOf[msg.sender];
        shares = super.deposit(assets, receiver);

        // Short-circuit reward payout when user doesn't already have tokens staked.
        if (userBal > 0) {
            uint256 pending = FixedPointMathLib.mulDivDown(userBal, rewardsPerShare, WAD) - rewardDebtOf[msg.sender];
            safeRewardTransfer(msg.sender, pending);
        }

        // unchecked because addition will checked on super.redeem()
        unchecked {
            rewardDebtOf[msg.sender] = FixedPointMathLib.mulDivDown(userBal + assets, rewardsPerShare, WAD);
        }

        _transferRewardDebt(msg.sender, receiver, assets);
    }

    // function mint(
    //     uint256 shares,
    //     address receiver
    // ) public virtual override(ERC4626) returns (uint256 assets) {
    //     uint256 rewardsPerShare = updatePool();
    //     uint256 userBal = balanceOf[msg.sender];
    //     assets = super.mint(shares, receiver);

    //     // Short-circuit reward payout when user doesn't already have tokens staked.
    //     if (userBal > 0) {
    //         uint256 pending = FixedPointMathLib.mulDivDown(userBal, rewardsPerShare, WAD) - rewardDebtOf[msg.sender];
    //         safeRewardTransfer(receiver, pending);
    //     }

    //     // unchecked because addition will checked on super.redeem()
    //     unchecked {
    //         rewardDebtOf[msg.sender] = FixedPointMathLib.mulDivDown(userBal + shares, rewardsPerShare, WAD);
    //     }

    //     _transferRewardDebt(msg.sender, receiver, shares);
    // }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override(ERC4626) returns (uint256 shares) {
        uint256 rewardsPerShare = updatePool();
        uint256 userBal = balanceOf[owner];
        uint256 pending = FixedPointMathLib.mulDivDown(userBal, rewardsPerShare, WAD) - rewardDebtOf[owner];

        // unchecked because subtraction will be checked on super.redeem()
        unchecked {
            rewardDebtOf[owner] = FixedPointMathLib.mulDivDown(userBal - shares, rewardsPerShare, WAD);
        }
        
        safeRewardTransfer(owner, pending);
        shares = super.withdraw(assets, receiver, owner);
        _transferRewardDebt(msg.sender, receiver, assets);
    }

    // function redeem(
    //     uint256 shares,
    //     address receiver,
    //     address owner
    // ) public virtual override(ERC4626) returns (uint256 assets) {
    //     uint256 rewardsPerShare = updatePool();
    //     uint256 userBal = balanceOf[owner];
    //     uint256 pending = FixedPointMathLib.mulDivDown(userBal, rewardsPerShare, WAD) - rewardDebtOf[owner];
        
    //     // unchecked because subtraction will be checked on super.redeem()
    //     unchecked {
    //         rewardDebtOf[owner] = FixedPointMathLib.mulDivDown(userBal - shares, rewardsPerShare, WAD);
    //     }

    //     safeRewardTransfer(receiver, pending);
    //     assets = super.redeem(shares, receiver, owner);
    //     _transferRewardDebt(msg.sender, receiver, shares);
    // }

    /// -----------------------------------------------------------------------
    /// User Viewables
    /// -----------------------------------------------------------------------

    // // External calls avoided, woot woot!
    // function pendingReward(address _user) external view returns (uint256) {
    //     uint256 supply = totalSupply;

    //     uint256 rewardsPerShare = block.timestamp > lastRewardTime && supply != 0 ?
    //         accRewardsPerShare + FixedPointMathLib.mulDivDown(rewardsPerSecond, WAD, supply) : 
    //         accRewardsPerShare;

    //     return FixedPointMathLib.mulDivDown(balanceOf[msg.sender], rewardsPerShare, WAD) - rewardDebtOf[_user];
    // }

    // View function to see pending SUSHIs on frontend.
    function pendingReward(address _user) external view returns (uint256) {

        uint256 rewardsPerShare = accRewardsPerShare;
        uint256 supply = asset.balanceOf(address(this));
        
        if (block.number > lastRewardTime && supply != 0) {
            uint256 totalPending = (block.timestamp - lastRewardTime) * rewardsPerSecond;
            rewardsPerShare += totalPending * WAD / supply;
        }

        return balanceOf[_user] * rewardsPerShare / WAD - rewardDebtOf[_user];
    }
    
    /// -----------------------------------------------------------------------
    /// Accounting Viewables
    /// -----------------------------------------------------------------------
    
    function totalAssets() public override(ERC4626) virtual view returns (uint256) {
        return totalSupply; // deposits are backed 1:1
    }

    function convertToShares(uint256 assets) public override(ERC4626) view virtual returns (uint256) {
        return assets; // deposits are backed 1:1
    }

    function convertToAssets(uint256 shares) public override(ERC4626) view virtual returns (uint256) {
        return shares; // deposits are backed 1:1
    }

    function previewDeposit(uint256 assets) public override(ERC4626) view virtual returns (uint256) {
        return assets; // deposits are backed 1:1
    }

    function previewMint(uint256 shares) public override(ERC4626) view virtual returns (uint256) {
        return shares; // deposits are backed 1:1
    }

    function previewWithdraw(uint256 assets) public override(ERC4626) view virtual returns (uint256) {
        return assets; // deposits are backed 1:1
    }

    function previewRedeem(uint256 shares) public override(ERC4626) view virtual returns (uint256) {
        return shares; // deposits are backed 1:1
    }
}
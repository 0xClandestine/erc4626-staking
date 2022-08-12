// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

// import "forge-std/Test.sol";
// import "../ERC4626StakingRewards.sol";

// contract MockERC20 is ERC20("", "", 18) {
//     constructor() {_mint(msg.sender, type(uint).max);}
// }

// contract Staking is ERC4626StakingRewards {
//     constructor(
//         ERC20 asset, 
//         ERC20 reward, 
//         string memory _name, 
//         string memory _symbol
//     ) ERC4626StakingRewards(asset, reward, _name, _symbol, 1 days) {
//         owner = msg.sender;
//     }
// }

// contract ERC4626StakingRewardsTest is Test {
    
//     MockERC20 asset;
//     MockERC20 reward;
//     ERC4626StakingRewards stakingRewards;

//     function setUp() public {
//         asset = new MockERC20();
//         reward = new MockERC20();
//         stakingRewards = new Staking(ERC20(address(asset)), ERC20(address(reward)), "", "");
//         reward.approve(address(stakingRewards), 1000 ether);
//         stakingRewards.notifyRewardAmount(1000 ether);
//     }

//     function testExample() public {
//         asset.approve(address(stakingRewards), 10 ether);
//         stakingRewards.deposit(10 ether, address(this));

//         uint beforeBal = reward.balanceOf(address(this));

//         assertEq(beforeBal, type(uint).max - 1000 ether);

//         vm.warp(block.timestamp + 1 days);

//         reward.approve(address(stakingRewards), 1000 ether);
//         stakingRewards.notifyRewardAmount(1000 ether);

//         stakingRewards.withdraw(10 ether, address(this), address(this));


//         emit log_uint(stakingRewards.pending(address(this)));

//         // stakingRewards.getReward();

        
//         // uint afterBal = reward.balanceOf(address(this));
    
//         // assertGt(afterBal, beforeBal);
//     }
// }

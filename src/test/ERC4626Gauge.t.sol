// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../ERC4626Gauge.sol";

contract MockERC20 is ERC20("", "", 18) {
    function mint(address who, uint256 amount) public {
        _mint(who, amount);
    }
}

contract MockGauge is ERC4626Gauge {
    constructor(ERC20 asset, ERC20 reward) ERC4626Gauge(asset, reward, 1 ether) {}
}

contract ERC4626GaugeTest is Test {
    
    MockERC20 asset;
    MockERC20 reward;
    MockGauge gauge;

    address alice;
    uint256 aliceKey;

    address bob;
    uint256 bobKey;

    function setUp() public {
        (alice, aliceKey) = makeAddrAndKey("Alice");
        (bob, bobKey) = makeAddrAndKey("Bob");

        asset = new MockERC20();
        vm.label(address(asset), "asset");

        reward = new MockERC20();
        vm.label(address(reward), "reward");

        gauge = new MockGauge(ERC20(address(asset)), ERC20(address(reward)));
        vm.label(address(gauge), "gauge");
    }

    // function testBasic() public {
    
    //     // alice participates 100% for 10 seconds
    //     asset.mint(alice, 80 ether);

    //     vm.prank(alice); asset.approve(address(gauge), 80 ether);
    //     vm.prank(alice); gauge.deposit(80 ether, alice);

    //     vm.warp(109); gauge.updatePool();
        
    //     assertEq(gauge.rewardCreditsOf(alice), 10 ether);
    //     assertEq(gauge.pendingReward(alice), 10 ether);
    // }
}

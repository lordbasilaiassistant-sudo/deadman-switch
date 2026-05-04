// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {DeadManSwitch} from "../src/DeadManSwitch.sol";

contract DeadManSwitchTest is Test {
    DeadManSwitch public dms;

    address public treasury = address(0xBEEF);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);
    address public triggerer = address(0x7716660);

    uint256 constant REGISTER_FEE_BPS = 50;     // 0.5%
    uint256 constant TRIGGER_BOUNTY_BPS = 50;   // 0.5%
    uint256 constant MAX_REGISTER_FEE_BPS = 500;    // 5%
    uint256 constant MAX_TRIGGER_BOUNTY_BPS = 500;  // 5%
    uint64 constant MIN_INTERVAL = 1 minutes;
    uint64 constant MAX_INTERVAL = 3650 days;

    function setUp() public {
        dms = new DeadManSwitch(
            treasury,
            uint16(REGISTER_FEE_BPS),
            uint16(TRIGGER_BOUNTY_BPS),
            uint16(MAX_REGISTER_FEE_BPS),
            uint16(MAX_TRIGGER_BOUNTY_BPS),
            MIN_INTERVAL,
            MAX_INTERVAL
        );
        vm.deal(alice, 100 ether);
        vm.deal(bob, 10 ether);
        vm.deal(triggerer, 1 ether);
    }

    // ------- register -------

    function test_register_routesFeeToTreasury() public {
        uint256 deposit = 1 ether;
        uint256 expectedFee = (deposit * REGISTER_FEE_BPS) / 10_000;
        uint256 expectedLocked = deposit - expectedFee;

        vm.prank(alice);
        uint256 id = dms.register{value: deposit}(bob, 30 days);

        assertEq(treasury.balance, expectedFee, "treasury fee");
        assertEq(address(dms).balance, expectedLocked, "contract holds locked");
        assertEq(id, 0, "first id");
        assertEq(dms.totalSwitches(), 1);

        (address dep, address ben, uint256 amt, uint64 interval, uint64 lastPing, bool claimed) = dms.switches(id);
        assertEq(dep, alice);
        assertEq(ben, bob);
        assertEq(amt, expectedLocked);
        assertEq(interval, 30 days);
        assertEq(lastPing, uint64(block.timestamp));
        assertFalse(claimed);
    }

    function test_register_revertsOnZeroValue() public {
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.ZeroValue.selector);
        dms.register{value: 0}(bob, 30 days);
    }

    function test_register_revertsOnZeroBeneficiary() public {
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.ZeroAddress.selector);
        dms.register{value: 1 ether}(address(0), 30 days);
    }

    function test_register_revertsOnIntervalTooShort() public {
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.IntervalOutOfRange.selector);
        dms.register{value: 1 ether}(bob, 30 seconds);
    }

    function test_register_revertsOnIntervalTooLong() public {
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.IntervalOutOfRange.selector);
        dms.register{value: 1 ether}(bob, MAX_INTERVAL + 1);
    }

    // ------- ping -------

    function test_ping_resetsTimer() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.warp(block.timestamp + 29 days);
        vm.prank(alice);
        dms.ping(id);

        (, , , , uint64 lastPing, ) = dms.switches(id);
        assertEq(lastPing, uint64(block.timestamp));

        // Still alive 29 days later
        vm.warp(block.timestamp + 29 days);
        assertTrue(dms.isAlive(id));
    }

    function test_ping_revertsOnNonDepositor() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);
        vm.prank(bob);
        vm.expectRevert(DeadManSwitch.NotDepositor.selector);
        dms.ping(id);
    }

    // ------- topUp -------

    function test_topUp_addsAmountAndResetsTimer() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.warp(block.timestamp + 15 days);

        vm.prank(alice);
        dms.topUp{value: 0.5 ether}(id);

        uint256 expectedFirstLocked = 1 ether - (1 ether * REGISTER_FEE_BPS) / 10_000;
        uint256 expectedTopUpAdded = 0.5 ether - (0.5 ether * REGISTER_FEE_BPS) / 10_000;
        (, , uint256 amt, , uint64 lastPing, ) = dms.switches(id);
        assertEq(amt, expectedFirstLocked + expectedTopUpAdded);
        assertEq(lastPing, uint64(block.timestamp));
    }

    // ------- cancel -------

    function test_cancel_refundsDepositor() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);
        uint256 lockedAmt = 1 ether - (1 ether * REGISTER_FEE_BPS) / 10_000;

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        dms.cancel(id);

        assertEq(alice.balance, aliceBefore + lockedAmt, "alice refunded");
        (, , uint256 amt, , , bool claimed) = dms.switches(id);
        assertEq(amt, 0);
        assertTrue(claimed);
    }

    function test_cancel_revertsOnSecondCall() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);
        vm.prank(alice);
        dms.cancel(id);
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.AlreadyClaimed.selector);
        dms.cancel(id);
    }

    // ------- trigger -------

    function test_trigger_paysBountyAndBeneficiary() public {
        uint256 deposit = 1 ether;
        vm.prank(alice);
        uint256 id = dms.register{value: deposit}(bob, 30 days);

        uint256 locked = deposit - (deposit * REGISTER_FEE_BPS) / 10_000;
        uint256 expectedBounty = (locked * TRIGGER_BOUNTY_BPS) / 10_000;
        uint256 expectedToBob = locked - expectedBounty;

        vm.warp(block.timestamp + 30 days + 1);

        uint256 triggererBefore = triggerer.balance;
        uint256 bobBefore = bob.balance;

        vm.prank(triggerer);
        dms.trigger(id);

        assertEq(triggerer.balance, triggererBefore + expectedBounty, "bounty paid");
        assertEq(bob.balance, bobBefore + expectedToBob, "beneficiary paid");

        (, , uint256 amt, , , bool claimed) = dms.switches(id);
        assertEq(amt, 0);
        assertTrue(claimed);
    }

    function test_trigger_revertsBeforeDeadline() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.warp(block.timestamp + 30 days);

        vm.prank(triggerer);
        vm.expectRevert(DeadManSwitch.StillAlive.selector);
        dms.trigger(id);
    }

    function test_trigger_succeedsExactlyOneSecondAfterDeadline() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.warp(block.timestamp + 30 days + 1);

        vm.prank(triggerer);
        dms.trigger(id);

        (, , , , , bool claimed) = dms.switches(id);
        assertTrue(claimed);
    }

    function test_trigger_revertsOnDoubleTrigger() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.warp(block.timestamp + 30 days + 1);

        vm.prank(triggerer);
        dms.trigger(id);

        vm.prank(triggerer);
        vm.expectRevert(DeadManSwitch.AlreadyClaimed.selector);
        dms.trigger(id);
    }

    function test_pingAfterDeadline_doesNotRescue() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.warp(block.timestamp + 30 days + 1);

        // Alice can technically ping after deadline (resets timer for future)
        // but if triggerer beats her in the same block window, her switch fires
        vm.prank(triggerer);
        dms.trigger(id);

        // After trigger, ping reverts
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.AlreadyClaimed.selector);
        dms.ping(id);
    }

    // ------- setBeneficiary -------

    function test_setBeneficiary_changesPayout() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);

        vm.prank(alice);
        dms.setBeneficiary(id, carol);

        vm.warp(block.timestamp + 30 days + 1);

        uint256 carolBefore = carol.balance;
        uint256 bobBefore = bob.balance;
        vm.prank(triggerer);
        dms.trigger(id);

        assertGt(carol.balance, carolBefore, "carol got paid");
        assertEq(bob.balance, bobBefore, "bob got nothing");
    }

    // ------- setFees -------

    function test_setFees_treasuryCanLower() public {
        vm.prank(treasury);
        dms.setFees(10, 10);
        assertEq(dms.registerFeeBps(), 10);
        assertEq(dms.triggerBountyBps(), 10);
    }

    function test_setFees_revertsAboveCap() public {
        vm.prank(treasury);
        vm.expectRevert(DeadManSwitch.FeeAboveCap.selector);
        dms.setFees(uint16(MAX_REGISTER_FEE_BPS) + 1, 10);
    }

    function test_setFees_revertsNonTreasury() public {
        vm.prank(alice);
        vm.expectRevert(DeadManSwitch.NotTreasury.selector);
        dms.setFees(10, 10);
    }

    // ------- setTreasury -------

    function test_setTreasury_handsOff() public {
        vm.prank(treasury);
        dms.setTreasury(carol);
        assertEq(dms.treasury(), carol);

        // Old treasury can no longer set fees
        vm.prank(treasury);
        vm.expectRevert(DeadManSwitch.NotTreasury.selector);
        dms.setFees(10, 10);
    }

    // ------- views -------

    function test_isAlive_trueBeforeDeadline_falseAfter() public {
        vm.prank(alice);
        uint256 id = dms.register{value: 1 ether}(bob, 30 days);
        assertTrue(dms.isAlive(id));
        vm.warp(block.timestamp + 30 days + 1);
        assertFalse(dms.isAlive(id));
    }

    function test_switchesByDepositor_returnsAll() public {
        vm.startPrank(alice);
        dms.register{value: 1 ether}(bob, 30 days);
        dms.register{value: 1 ether}(carol, 60 days);
        vm.stopPrank();

        uint256[] memory ids = dms.switchesByDepositor(alice);
        assertEq(ids.length, 2);
        assertEq(ids[0], 0);
        assertEq(ids[1], 1);
    }
}

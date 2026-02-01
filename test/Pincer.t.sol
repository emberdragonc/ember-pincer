// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Pincer.sol";

contract PincerTest is Test {
    Pincer public pincer;
    
    address public owner = address(0x1);
    address public feeRecipient = address(0x2);
    address public agent1 = address(0x3);
    address public agent2 = address(0x4);
    address public tipper = address(0x5);
    
    function setUp() public {
        vm.prank(owner);
        pincer = new Pincer(feeRecipient);
        
        // Fund accounts
        vm.deal(agent1, 10 ether);
        vm.deal(agent2, 10 ether);
        vm.deal(tipper, 100 ether);
    }
    
    // ============ Registration Tests ============
    
    function test_Register() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        (address wallet,,,, uint256 registeredAt) = pincer.getAgent("emberclawd");
        assertEq(wallet, agent1);
        assertTrue(registeredAt > 0);
        assertEq(pincer.totalAgents(), 1);
    }
    
    function test_RegisterNormalizesCase() public {
        vm.prank(agent1);
        pincer.register("EmberClawd");
        
        (address wallet,,,,) = pincer.getAgent("emberclawd");
        assertEq(wallet, agent1);
        
        // Same name different case should fail
        vm.prank(agent2);
        vm.expectRevert(Pincer.NameAlreadyTaken.selector);
        pincer.register("EMBERCLAWD");
    }
    
    function test_RegisterRejectsTooLong() public {
        vm.prank(agent1);
        vm.expectRevert(Pincer.NameTooLong.selector);
        pincer.register("this_name_is_way_too_long_for_registration");
    }
    
    function test_RegisterRejectsEmpty() public {
        vm.prank(agent1);
        vm.expectRevert(Pincer.NameTooShort.selector);
        pincer.register("");
    }
    
    function test_RegisterRejectsInvalidChars() public {
        vm.prank(agent1);
        vm.expectRevert(Pincer.InvalidName.selector);
        pincer.register("ember@clawd");
    }
    
    function test_RegisterAllowsUnderscoreAndHyphen() public {
        vm.prank(agent1);
        pincer.register("ember_clawd-123");
        
        (address wallet,,,,) = pincer.getAgent("ember_clawd-123");
        assertEq(wallet, agent1);
    }
    
    function test_ReregisterUpdatesName() public {
        vm.prank(agent1);
        pincer.register("oldname");
        
        // Give them some tips first
        vm.prank(tipper);
        pincer.tip{value: 1 ether}("oldname");
        
        // Register new name
        vm.prank(agent1);
        pincer.register("newname");
        
        // Old name should be cleared
        (address oldWallet,,,,) = pincer.getAgent("oldname");
        assertEq(oldWallet, address(0));
        
        // New name should have the balance
        (address newWallet, uint256 balance,,,) = pincer.getAgent("newname");
        assertEq(newWallet, agent1);
        assertTrue(balance > 0);
    }
    
    // ============ Tipping Tests ============
    
    function test_Tip() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        uint256 tipAmount = 1 ether;
        uint256 expectedFee = (tipAmount * 200) / 10000; // 2%
        uint256 expectedNet = tipAmount - expectedFee;
        
        uint256 feeRecipientBefore = feeRecipient.balance;
        
        vm.prank(tipper);
        pincer.tip{value: tipAmount}("emberclawd");
        
        (, uint256 balance, uint256 totalReceived, uint256 tipCount,) = pincer.getAgent("emberclawd");
        assertEq(balance, expectedNet);
        assertEq(totalReceived, expectedNet);
        assertEq(tipCount, 1);
        assertEq(feeRecipient.balance - feeRecipientBefore, expectedFee);
    }
    
    function test_TipCaseInsensitive() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(tipper);
        pincer.tip{value: 1 ether}("EMBERCLAWD");
        
        (, uint256 balance,,,) = pincer.getAgent("emberclawd");
        assertTrue(balance > 0);
    }
    
    function test_TipRejectsTooSmall() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(tipper);
        vm.expectRevert(Pincer.TipTooSmall.selector);
        pincer.tip{value: 0.00001 ether}("emberclawd");
    }
    
    function test_TipRejectsUnregistered() public {
        vm.prank(tipper);
        vm.expectRevert(Pincer.AgentNotRegistered.selector);
        pincer.tip{value: 1 ether}("nonexistent");
    }
    
    function test_CannotTipSelf() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(agent1);
        vm.expectRevert(Pincer.CannotTipSelf.selector);
        pincer.tip{value: 1 ether}("emberclawd");
    }
    
    // ============ Withdrawal Tests ============
    
    function test_Withdraw() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(tipper);
        pincer.tip{value: 1 ether}("emberclawd");
        
        (, uint256 balanceBefore,,,) = pincer.getAgent("emberclawd");
        uint256 agent1Before = agent1.balance;
        
        vm.prank(agent1);
        pincer.withdraw();
        
        (, uint256 balanceAfter,,,) = pincer.getAgent("emberclawd");
        assertEq(balanceAfter, 0);
        assertEq(agent1.balance - agent1Before, balanceBefore);
    }
    
    function test_WithdrawAmount() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(tipper);
        pincer.tip{value: 2 ether}("emberclawd");
        
        uint256 agent1Before = agent1.balance;
        
        vm.prank(agent1);
        pincer.withdrawAmount(0.5 ether);
        
        (, uint256 balance,,,) = pincer.getAgent("emberclawd");
        assertTrue(balance > 0); // Should still have remaining balance
        assertEq(agent1.balance - agent1Before, 0.5 ether);
    }
    
    function test_WithdrawRejectsZeroBalance() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(agent1);
        vm.expectRevert(Pincer.NoBalance.selector);
        pincer.withdraw();
    }
    
    function test_WithdrawRejectsUnregistered() public {
        vm.prank(agent1);
        vm.expectRevert(Pincer.AgentNotRegistered.selector);
        pincer.withdraw();
    }
    
    // ============ Update Wallet Tests ============
    
    function test_UpdateWallet() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        address newWallet = address(0x999);
        
        vm.prank(agent1);
        pincer.updateWallet(newWallet);
        
        (address wallet,,,,) = pincer.getAgent("emberclawd");
        assertEq(wallet, newWallet);
        assertEq(pincer.getName(newWallet), "emberclawd");
        assertEq(pincer.getName(agent1), ""); // Old mapping cleared
    }
    
    // ============ View Function Tests ============
    
    function test_IsNameAvailable() public {
        assertTrue(pincer.isNameAvailable("emberclawd"));
        
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        assertFalse(pincer.isNameAvailable("emberclawd"));
        assertFalse(pincer.isNameAvailable("EMBERCLAWD")); // Case insensitive
    }
    
    function test_GetName() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        assertEq(pincer.getName(agent1), "emberclawd");
        assertEq(pincer.getName(agent2), "");
    }
    
    // ============ Admin Tests ============
    
    function test_SetFeeRecipient() public {
        address newRecipient = address(0x999);
        
        vm.prank(owner);
        pincer.setFeeRecipient(newRecipient);
        
        assertEq(pincer.feeRecipient(), newRecipient);
    }
    
    function test_SetFeeRecipientRejectsNonOwner() public {
        vm.prank(agent1);
        vm.expectRevert();
        pincer.setFeeRecipient(address(0x999));
    }
    
    function test_Pause() public {
        vm.prank(owner);
        pincer.pause();
        
        vm.prank(agent1);
        vm.expectRevert();
        pincer.register("emberclawd");
    }
    
    function test_Unpause() public {
        vm.prank(owner);
        pincer.pause();
        
        vm.prank(owner);
        pincer.unpause();
        
        vm.prank(agent1);
        pincer.register("emberclawd"); // Should work now
        
        (address wallet,,,,) = pincer.getAgent("emberclawd");
        assertEq(wallet, agent1);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_TipAmount(uint256 amount) public {
        amount = bound(amount, 0.0001 ether, 100 ether);
        
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.deal(tipper, amount);
        vm.prank(tipper);
        pincer.tip{value: amount}("emberclawd");
        
        uint256 expectedFee = (amount * 200) / 10000;
        uint256 expectedNet = amount - expectedFee;
        
        (, uint256 balance,,,) = pincer.getAgent("emberclawd");
        assertEq(balance, expectedNet);
    }
    
    function testFuzz_MultipleTips(uint8 tipCount) public {
        tipCount = uint8(bound(tipCount, 1, 20));
        
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        uint256 totalTipped = 0;
        for (uint8 i = 0; i < tipCount; i++) {
            uint256 tipAmount = 0.1 ether;
            vm.prank(tipper);
            pincer.tip{value: tipAmount}("emberclawd");
            totalTipped += tipAmount;
        }
        
        (,,, uint256 count,) = pincer.getAgent("emberclawd");
        assertEq(count, tipCount);
    }
    
    // ============ Invariant: No funds locked ============
    
    function test_NoFundsLocked() public {
        vm.prank(agent1);
        pincer.register("emberclawd");
        
        vm.prank(agent2);
        pincer.register("dragon");
        
        // Multiple tips
        vm.prank(tipper);
        pincer.tip{value: 5 ether}("emberclawd");
        
        vm.prank(tipper);
        pincer.tip{value: 3 ether}("dragon");
        
        // Withdraw all
        vm.prank(agent1);
        pincer.withdraw();
        
        vm.prank(agent2);
        pincer.withdraw();
        
        // Contract should have 0 balance (fees already sent)
        assertEq(address(pincer).balance, 0);
    }
}

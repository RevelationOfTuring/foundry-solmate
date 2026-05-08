// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {WETH} from "lib/solmate/src/tokens/WETH.sol";

contract WETHTest is Test {
    WETH weth;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        weth = new WETH();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // 正向：deposit 铸造等量 WETH，触发 Deposit + Transfer 事件
    function testDeposit() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), alice, 1 ether);

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 1 ether);

        vm.prank(alice);
        weth.deposit{value: 1 ether}();

        assertEq(weth.balanceOf(alice), 1 ether);
        assertEq(weth.totalSupply(), 1 ether);
        assertEq(address(weth).balance, 1 ether);
    }

    // 正向：多次 deposit 叠加余额
    function testDepositMultipleTimes() public {
        vm.startPrank(alice);
        weth.deposit{value: 1 ether}();
        weth.deposit{value: 2 ether}();
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.totalSupply(), 3 ether);
    }

    // 正向：不同用户 deposit 独立
    function testDepositDifferentUsers() public {
        vm.prank(alice);
        weth.deposit{value: 1 ether}();

        vm.prank(bob);
        weth.deposit{value: 2 ether}();

        assertEq(weth.balanceOf(alice), 1 ether);
        assertEq(weth.balanceOf(bob), 2 ether);
        assertEq(weth.totalSupply(), 3 ether);
    }

    // 边界：deposit 0 ETH
    function testDepositZero() public {
        vm.prank(alice);
        weth.deposit{value: 0}();

        assertEq(weth.balanceOf(alice), 0);
        assertEq(weth.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                             WITHDRAW
    //////////////////////////////////////////////////////////////*/

    // 正向：withdraw 销毁 WETH，返回 ETH，触发 Withdrawal + Transfer 事件
    function testWithdraw() public {
        vm.prank(alice);
        weth.deposit{value: 5 ether}();

        uint256 balanceBefore = alice.balance;

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, address(0), 2 ether);

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, 2 ether);

        vm.prank(alice);
        weth.withdraw(2 ether);

        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.totalSupply(), 3 ether);
        assertEq(alice.balance, balanceBefore + 2 ether);
    }

    // 正向：withdraw 全部余额
    function testWithdrawEntireBalance() public {
        vm.startPrank(alice);
        weth.deposit{value: 5 ether}();

        uint256 balanceBefore = alice.balance;
        weth.withdraw(5 ether);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), 0);
        assertEq(weth.totalSupply(), 0);
        assertEq(alice.balance, balanceBefore + 5 ether);
    }

    // 边界：withdraw 0
    function testWithdrawZero() public {
        vm.startPrank(alice);
        weth.deposit{value: 1 ether}();
        weth.withdraw(0);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), 1 ether);
    }

    // 反向：withdraw 超过余额 revert
    function testWithdrawInsufficientBalanceReverts() public {
        vm.startPrank(alice);
        weth.deposit{value: 1 ether}();

        vm.expectRevert();
        weth.withdraw(2 ether);
        vm.stopPrank();
    }

    // 反向：无余额 withdraw revert
    function testWithdrawNoBalanceReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        weth.withdraw(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE
    //////////////////////////////////////////////////////////////*/

    // 正向：直接转 ETH 触发 receive → deposit，铸造 WETH，触发 Deposit 事件
    function testReceiveDepositsWETH() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), alice, 3 ether);

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 3 ether);

        vm.prank(alice);
        (bool ok,) = address(weth).call{value: 3 ether}("");
        assertTrue(ok);

        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.totalSupply(), 3 ether);
        assertEq(address(weth).balance, 3 ether);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC20 BEHAVIOR
    //////////////////////////////////////////////////////////////*/

    // 正向：name、symbol、decimals 正确
    function testMetadata() public view {
        assertEq(weth.name(), "Wrapped Ether");
        assertEq(weth.symbol(), "WETH");
        assertEq(weth.decimals(), 18);
    }

    // 正向：transfer WETH
    function testTransfer() public {
        vm.startPrank(alice);
        weth.deposit{value: 5 ether}();
        assertTrue(weth.transfer(bob, 2 ether));
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.balanceOf(bob), 2 ether);
    }

    // 正向：approve + transferFrom
    function testApproveAndTransferFrom() public {
        vm.prank(alice);
        weth.deposit{value: 5 ether}();

        vm.prank(alice);
        weth.approve(bob, 3 ether);
        assertEq(weth.allowance(alice, bob), 3 ether);

        vm.prank(bob);
        assertTrue(weth.transferFrom(alice, bob, 2 ether));

        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.balanceOf(bob), 2 ether);
        assertEq(weth.allowance(alice, bob), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            INVARIANT CHECK
    //////////////////////////////////////////////////////////////*/

    // 不变量：address(weth).balance == totalSupply
    function testInvariantBalanceEqualsTotalSupply() public {
        vm.prank(alice);
        weth.deposit{value: 10 ether}();

        vm.prank(bob);
        weth.deposit{value: 5 ether}();

        // transfer 不影响不变量
        vm.prank(alice);
        weth.transfer(bob, 3 ether);

        assertEq(address(weth).balance, weth.totalSupply());

        // withdraw 后仍然成立
        vm.prank(bob);
        weth.withdraw(4 ether);

        assertEq(address(weth).balance, weth.totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                          FULL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    // 完整生命周期：deposit → transfer → approve → transferFrom → withdraw
    function testFullLifecycle() public {
        // 1. alice deposit
        vm.prank(alice);
        weth.deposit{value: 10 ether}();
        assertEq(weth.balanceOf(alice), 10 ether);

        // 2. alice transfer 给 bob
        vm.prank(alice);
        weth.transfer(bob, 3 ether);
        assertEq(weth.balanceOf(alice), 7 ether);
        assertEq(weth.balanceOf(bob), 3 ether);

        // 3. bob approve alice
        vm.prank(bob);
        weth.approve(alice, 2 ether);

        // 4. alice transferFrom bob
        vm.prank(alice);
        weth.transferFrom(bob, alice, 2 ether);
        assertEq(weth.balanceOf(alice), 9 ether);
        assertEq(weth.balanceOf(bob), 1 ether);

        // 5. alice withdraw
        uint256 aliceBalBefore = alice.balance;
        vm.prank(alice);
        weth.withdraw(9 ether);
        assertEq(weth.balanceOf(alice), 0);
        assertEq(alice.balance, aliceBalBefore + 9 ether);

        // 6. bob withdraw 剩余
        uint256 bobBalBefore = bob.balance;
        vm.prank(bob);
        weth.withdraw(1 ether);
        assertEq(weth.balanceOf(bob), 0);
        assertEq(bob.balance, bobBalBefore + 1 ether);

        // 7. 不变量：合约余额清零
        assertEq(address(weth).balance, 0);
        assertEq(weth.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // fuzz：deposit 后余额正确
    function testFuzzDeposit(uint256 amount) public {
        amount = bound(amount, 0, 100 ether);

        vm.prank(alice);
        weth.deposit{value: amount}();

        assertEq(weth.balanceOf(alice), amount);
        assertEq(address(weth).balance, amount);
    }

    // fuzz：deposit 后全部 withdraw
    function testFuzzDepositAndWithdraw(uint256 amount) public {
        amount = bound(amount, 0, 100 ether);

        vm.startPrank(alice);
        weth.deposit{value: amount}();

        uint256 balanceBefore = alice.balance;
        weth.withdraw(amount);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), 0);
        assertEq(alice.balance, balanceBefore + amount);
        assertEq(address(weth).balance, 0);
    }

    // fuzz：部分 withdraw
    function testFuzzPartialWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 0, 100 ether);
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);

        vm.startPrank(alice);
        weth.deposit{value: depositAmount}();
        weth.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), depositAmount - withdrawAmount);
        assertEq(address(weth).balance, depositAmount - withdrawAmount);
    }

    // fuzz：receive 等价于 deposit
    function testFuzzReceive(uint256 amount) public {
        amount = bound(amount, 0, 100 ether);

        vm.prank(alice);
        (bool ok,) = address(weth).call{value: amount}("");
        assertTrue(ok);

        assertEq(weth.balanceOf(alice), amount);
        assertEq(address(weth).balance, amount);
    }
}

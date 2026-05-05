// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC6909} from "src/tokens/MockERC6909.sol";

contract ERC6909Test is Test {
    MockERC6909 token;

    address alice = address(0xA);
    address bob = address(0xB);
    address carol = address(0xC);

    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    function setUp() public {
        token = new MockERC6909();
    }

    /*//////////////////////////////////////////////////////////////
                              MINT
    //////////////////////////////////////////////////////////////*/

    // 正向：mint 更新 balanceOf，触发 Transfer 事件
    function testMint() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), address(0), alice, 1, 100);
        token.mint(alice, 1, 100);

        assertEq(token.balanceOf(alice, 1), 100);
    }

    // 正向：同一地址、同一 id 多次 mint 叠加余额
    function testMintSameIdAccumulates() public {
        token.mint(alice, 1, 100);
        token.mint(alice, 1, 50);

        assertEq(token.balanceOf(alice, 1), 150);
    }

    // 正向：同一地址 mint 不同 id
    function testMintDifferentIds() public {
        token.mint(alice, 1, 100);
        token.mint(alice, 2, 200);

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(alice, 2), 200);
    }

    // 正向：不同地址 mint 同一 id
    function testMintSameIdDifferentAddresses() public {
        token.mint(alice, 1, 100);
        token.mint(bob, 1, 200);

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(bob, 1), 200);
    }

    // 边界：mint amount = 0
    function testMintZeroAmount() public {
        token.mint(alice, 1, 0);
        assertEq(token.balanceOf(alice, 1), 0);
    }

    // 边界：mint id = 0
    function testMintIdZero() public {
        token.mint(alice, 0, 100);
        assertEq(token.balanceOf(alice, 0), 100);
    }

    // 边界：mint id = type(uint256).max
    function testMintMaxId() public {
        token.mint(alice, type(uint256).max, 100);
        assertEq(token.balanceOf(alice, type(uint256).max), 100);
    }

    /*//////////////////////////////////////////////////////////////
                              BURN
    //////////////////////////////////////////////////////////////*/

    // 正向：burn 扣减余额，触发 Transfer 事件（to = address(0)）
    function testBurn() public {
        token.mint(alice, 1, 100);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), alice, address(0), 1, 30);
        token.burn(alice, 1, 30);

        assertEq(token.balanceOf(alice, 1), 70);
    }

    // 正向：burn 全部余额
    function testBurnEntireBalance() public {
        token.mint(alice, 1, 100);
        token.burn(alice, 1, 100);

        assertEq(token.balanceOf(alice, 1), 0);
    }

    // 边界：burn amount = 0
    function testBurnZeroAmount() public {
        token.mint(alice, 1, 100);
        token.burn(alice, 1, 0);

        assertEq(token.balanceOf(alice, 1), 100);
    }

    // 反向：burn 超过余额 revert（underflow）
    function testBurnInsufficientBalanceReverts() public {
        token.mint(alice, 1, 100);

        vm.expectRevert();
        token.burn(alice, 1, 101);
    }

    // 反向：burn 无余额 revert
    function testBurnNoBalanceReverts() public {
        vm.expectRevert();
        token.burn(alice, 1, 1);
    }

    // 正向：burn 只影响指定 id，不影响其他 id
    function testBurnDoesNotAffectOtherId() public {
        token.mint(alice, 1, 100);
        token.mint(alice, 2, 200);
        token.burn(alice, 1, 50);

        assertEq(token.balanceOf(alice, 1), 50);
        assertEq(token.balanceOf(alice, 2), 200);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER
    //////////////////////////////////////////////////////////////*/

    // 正向：transfer 扣减发送方、增加接收方，触发事件
    function testTransfer() public {
        token.mint(alice, 1, 100);

        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, alice, bob, 1, 30);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 1, 30));

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(bob, 1), 30);
    }

    // 正向：transfer 全部余额
    function testTransferEntireBalance() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        token.transfer(bob, 1, 100);

        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(token.balanceOf(bob, 1), 100);
    }

    // 边界：transfer amount = 0
    function testTransferZeroAmount() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 1, 0));

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(bob, 1), 0);
    }

    // 正向：transfer 给自己
    function testTransferToSelf() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        token.transfer(alice, 1, 30);

        assertEq(token.balanceOf(alice, 1), 100);
    }

    // 反向：transfer 超过余额 revert
    function testTransferInsufficientBalanceReverts() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1, 101);
    }

    // 正向：transfer 不影响其他 id
    function testTransferDoesNotAffectOtherId() public {
        token.mint(alice, 1, 100);
        token.mint(alice, 2, 200);

        vm.prank(alice);
        token.transfer(bob, 1, 50);

        assertEq(token.balanceOf(alice, 1), 50);
        assertEq(token.balanceOf(alice, 2), 200);
        assertEq(token.balanceOf(bob, 1), 50);
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER FROM
    //////////////////////////////////////////////////////////////*/

    // 正向：transferFrom 由本人调用（跳过授权检查）
    function testTransferFromBySender() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        assertTrue(token.transferFrom(alice, bob, 1, 30));

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(bob, 1), 30);
    }

    // 正向：transferFrom 由 operator 调用（跳过 allowance 检查）
    function testTransferFromByOperator() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        token.setOperator(bob, true);

        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, carol, 1, 30);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, 1, 30));

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(carol, 1), 30);
    }

    // 正向：transferFrom 由被授权 spender 调用，扣减 allowance
    function testTransferFromByApprovedSpender() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        token.approve(bob, 1, 50);

        // caller 是 bob，from 是 alice（验证事件中 caller != from）
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, carol, 1, 30);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, 1, 30));

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(carol, 1), 30);
        // allowance 从 50 扣减到 20
        assertEq(token.allowance(alice, bob, 1), 20);
    }

    // 正向：transferFrom 无限授权不扣减 allowance
    function testTransferFromInfiniteAllowanceNotDecremented() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        token.approve(bob, 1, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, carol, 1, 30);

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(carol, 1), 30);
        // 无限授权不扣减
        assertEq(token.allowance(alice, bob, 1), type(uint256).max);
    }

    // 正向：operator 不消耗 allowance
    function testTransferFromOperatorDoesNotConsumeAllowance() public {
        token.mint(alice, 1, 100);

        vm.startPrank(alice);
        token.setOperator(bob, true);
        token.approve(bob, 1, 50);
        vm.stopPrank();

        vm.prank(bob);
        token.transferFrom(alice, carol, 1, 30);

        // operator 不走 allowance 逻辑，allowance 保持不变
        assertEq(token.allowance(alice, bob, 1), 50);
    }

    // 反向：transferFrom 授权额度不足 revert
    function testTransferFromInsufficientAllowanceReverts() public {
        token.mint(alice, 1, 100);

        vm.prank(alice);
        token.approve(bob, 1, 20);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, carol, 1, 21);
    }

    // 反向：transferFrom 无授权 revert
    function testTransferFromNoAllowanceReverts() public {
        token.mint(alice, 1, 100);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, carol, 1, 30);
    }

    // 反向：transferFrom 余额不足 revert（即使有授权）
    function testTransferFromInsufficientBalanceReverts() public {
        token.mint(alice, 1, 50);

        vm.prank(alice);
        token.approve(bob, 1, 100);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, carol, 1, 51);
    }

    // 正向：transferFrom 只消耗对应 id 的 allowance
    function testTransferFromDoesNotAffectOtherIdAllowance() public {
        token.mint(alice, 1, 100);
        token.mint(alice, 2, 100);

        vm.startPrank(alice);
        token.approve(bob, 1, 50);
        token.approve(bob, 2, 80);
        vm.stopPrank();

        vm.prank(bob);
        token.transferFrom(alice, carol, 1, 30);

        assertEq(token.allowance(alice, bob, 1), 20);
        assertEq(token.allowance(alice, bob, 2), 80); // 不受影响
    }

    /*//////////////////////////////////////////////////////////////
                            APPROVE
    //////////////////////////////////////////////////////////////*/

    // 正向：approve 设置 allowance，触发事件
    function testApprove() public {
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 1, 100);

        vm.prank(alice);
        assertTrue(token.approve(bob, 1, 100));

        assertEq(token.allowance(alice, bob, 1), 100);
    }

    // 正向：approve 覆盖式写入（非增量）
    function testApproveOverwritesPreviousValue() public {
        vm.startPrank(alice);
        token.approve(bob, 1, 100);
        token.approve(bob, 1, 200);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob, 1), 200);
    }

    // 正向：approve 归零
    function testApproveToZero() public {
        vm.startPrank(alice);
        token.approve(bob, 1, 100);
        token.approve(bob, 1, 0);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob, 1), 0);
    }

    // 正向：approve 无限授权
    function testApproveMaxValue() public {
        vm.prank(alice);
        token.approve(bob, 1, type(uint256).max);

        assertEq(token.allowance(alice, bob, 1), type(uint256).max);
    }

    // 正向：不同 id 的 allowance 独立
    function testApproveDifferentIdsIndependent() public {
        vm.startPrank(alice);
        token.approve(bob, 1, 100);
        token.approve(bob, 2, 200);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob, 1), 100);
        assertEq(token.allowance(alice, bob, 2), 200);
    }

    // 正向：不同 spender 的 allowance 独立
    function testApproveDifferentSpendersIndependent() public {
        vm.startPrank(alice);
        token.approve(bob, 1, 100);
        token.approve(carol, 1, 200);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob, 1), 100);
        assertEq(token.allowance(alice, carol, 1), 200);
    }

    /*//////////////////////////////////////////////////////////////
                          SET OPERATOR
    //////////////////////////////////////////////////////////////*/

    // 正向：setOperator 授权，触发事件
    function testSetOperator() public {
        vm.expectEmit(true, true, false, true);
        emit OperatorSet(alice, bob, true);

        vm.prank(alice);
        assertTrue(token.setOperator(bob, true));
        assertTrue(token.isOperator(alice, bob));
    }

    // 正向：setOperator 撤销
    function testSetOperatorRevoke() public {
        vm.startPrank(alice);
        token.setOperator(bob, true);

        vm.expectEmit(true, true, false, true);
        emit OperatorSet(alice, bob, false);

        token.setOperator(bob, false);
        vm.stopPrank();

        assertFalse(token.isOperator(alice, bob));
    }

    // 正向：不同 owner 的 operator 独立
    function testSetOperatorDifferentOwnersIndependent() public {
        vm.prank(alice);
        token.setOperator(carol, true);

        vm.prank(bob);
        token.setOperator(carol, false);

        assertTrue(token.isOperator(alice, carol));
        assertFalse(token.isOperator(bob, carol));
    }

    // 正向：isOperator 默认为 false
    function testIsOperatorDefaultFalse() public view {
        assertFalse(token.isOperator(alice, bob));
    }

    // 正向：operator 对所有 id 生效（不按 id 隔离）
    function testOperatorWorksForAllIds() public {
        token.mint(alice, 1, 100);
        token.mint(alice, 2, 200);
        token.mint(alice, 3, 300);

        vm.prank(alice);
        token.setOperator(bob, true);

        vm.startPrank(bob);
        token.transferFrom(alice, carol, 1, 10);
        token.transferFrom(alice, carol, 2, 20);
        token.transferFrom(alice, carol, 3, 30);
        vm.stopPrank();

        assertEq(token.balanceOf(alice, 1), 90);
        assertEq(token.balanceOf(alice, 2), 180);
        assertEq(token.balanceOf(alice, 3), 270);
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPORTS INTERFACE
    //////////////////////////////////////////////////////////////*/

    // 正向：支持 ERC165（0x01ffc9a7）
    function testSupportsERC165Interface() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7));
    }

    // 正向：支持 ERC6909（0x0f632fb3）
    function testSupportsERC6909Interface() public view {
        assertTrue(token.supportsInterface(0x0f632fb3));
    }

    // 反向：不支持的接口返回 false
    function testDoesNotSupportUnknownInterface() public view {
        assertFalse(token.supportsInterface(0xDEADBEEF));
    }

    // 边界：0xFFFFFFFF 返回 false
    function testDoesNotSupportMaxInterface() public view {
        assertFalse(token.supportsInterface(0xFFFFFFFF));
    }

    /*//////////////////////////////////////////////////////////////
                          FULL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    // 完整生命周期：mint → approve → transferFrom → burn
    function testFullLifecycle() public {
        // 1. mint
        token.mint(alice, 1, 1000);
        assertEq(token.balanceOf(alice, 1), 1000);

        // 2. approve
        vm.prank(alice);
        token.approve(bob, 1, 500);
        assertEq(token.allowance(alice, bob, 1), 500);

        // 3. transferFrom（消耗 allowance）
        vm.prank(bob);
        token.transferFrom(alice, carol, 1, 300);
        assertEq(token.balanceOf(alice, 1), 700);
        assertEq(token.balanceOf(carol, 1), 300);
        assertEq(token.allowance(alice, bob, 1), 200);

        // 4. carol 直接 transfer
        vm.prank(carol);
        token.transfer(alice, 1, 100);
        assertEq(token.balanceOf(carol, 1), 200);
        assertEq(token.balanceOf(alice, 1), 800);

        // 5. burn
        token.burn(alice, 1, 800);
        assertEq(token.balanceOf(alice, 1), 0);
    }

    // 完整生命周期：operator 模式
    function testFullLifecycleWithOperator() public {
        // 1. mint
        token.mint(alice, 1, 1000);

        // 2. setOperator
        vm.prank(alice);
        token.setOperator(bob, true);

        // 3. operator transferFrom（不消耗 allowance）
        vm.prank(bob);
        token.transferFrom(alice, carol, 1, 500);
        assertEq(token.balanceOf(alice, 1), 500);
        assertEq(token.balanceOf(carol, 1), 500);

        // 4. 撤销 operator
        vm.prank(alice);
        token.setOperator(bob, false);

        // 5. 撤销后 transferFrom revert
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, carol, 1, 100);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // fuzz：mint 后余额正确
    function testFuzzMint(address to, uint256 id, uint256 amount) public {
        token.mint(to, id, amount);
        assertEq(token.balanceOf(to, id), amount);
    }

    // fuzz：mint 后全部 burn
    function testFuzzMintAndBurn(address to, uint256 id, uint256 amount) public {
        token.mint(to, id, amount);
        token.burn(to, id, amount);
        assertEq(token.balanceOf(to, id), 0);
    }

    // fuzz：transfer 余额守恒
    function testFuzzTransfer(uint256 id, uint256 mintAmount, uint256 transferAmount) public {
        transferAmount = bound(transferAmount, 0, mintAmount);

        token.mint(alice, id, mintAmount);

        vm.prank(alice);
        token.transfer(bob, id, transferAmount);

        assertEq(token.balanceOf(alice, id), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob, id), transferAmount);
    }

    // fuzz：approve + transferFrom
    function testFuzzApproveAndTransferFrom(
        uint256 id,
        uint256 mintAmount,
        uint256 approveAmount,
        uint256 transferAmount
    ) public {
        approveAmount = bound(approveAmount, 0, mintAmount);
        transferAmount = bound(transferAmount, 0, approveAmount);

        token.mint(alice, id, mintAmount);

        vm.prank(alice);
        token.approve(bob, id, approveAmount);

        vm.prank(bob);
        token.transferFrom(alice, carol, id, transferAmount);

        assertEq(token.balanceOf(alice, id), mintAmount - transferAmount);
        assertEq(token.balanceOf(carol, id), transferAmount);
        assertEq(token.allowance(alice, bob, id), approveAmount - transferAmount);
    }

    // fuzz：setOperator + transferFrom
    function testFuzzOperatorTransferFrom(uint256 id, uint256 mintAmount, uint256 transferAmount) public {
        transferAmount = bound(transferAmount, 0, mintAmount);

        token.mint(alice, id, mintAmount);

        vm.prank(alice);
        token.setOperator(bob, true);

        vm.prank(bob);
        token.transferFrom(alice, carol, id, transferAmount);

        assertEq(token.balanceOf(alice, id), mintAmount - transferAmount);
        assertEq(token.balanceOf(carol, id), transferAmount);
    }
}

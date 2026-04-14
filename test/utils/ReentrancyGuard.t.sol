// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    MockReentrancyGuard,
    ReentrancyAttacker,
    SafeCallback,
    CrossFunctionAttacker,
    UnprotectedAttacker
} from "src/utils/MockReentrancyGuard.sol";

contract ReentrancyGuardTest is Test {
    MockReentrancyGuard mock;
    ReentrancyAttacker attacker;
    SafeCallback safeCallback;

    function setUp() public {
        mock = new MockReentrancyGuard();
        attacker = new ReentrancyAttacker(mock);
        safeCallback = new SafeCallback();
    }

    /*//////////////////////////////////////////////////////////////
                          protectedCall
    //////////////////////////////////////////////////////////////*/

    // 正向：正常调用通过
    function testProtectedCall() public {
        assertEq(mock.counter(), 0);
        mock.protectedCall();
        assertEq(mock.counter(), 1);
    }

    // 正向：多次独立调用通过（锁正确释放）
    function testProtectedCallMultipleTimes() public {
        mock.protectedCall();
        mock.protectedCall();
        mock.protectedCall();
        assertEq(mock.counter(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                    protectedCallWithCallback
    //////////////////////////////////////////////////////////////*/

    // 正向：带安全回调的调用通过
    function testProtectedCallWithSafeCallback() public {
        mock.protectedCallWithCallback(address(safeCallback));
        assertEq(mock.counter(), 1);
        assertEq(safeCallback.callbackCount(), 1);
    }

    // 反向：重入攻击被阻止
    function testReentrancyAttackReverts() public {
        vm.expectRevert("REENTRANCY");
        attacker.attack();
    }

    // 反向：重入攻击时 counter 不会被多次增加
    function testReentrancyAttackCounterUnchanged() public {
        // 攻击失败，整个交易回滚，counter 保持 0
        vm.expectRevert("REENTRANCY");
        attacker.attack();
        assertEq(mock.counter(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        unprotectedCall
    //////////////////////////////////////////////////////////////*/

    // 正向：未保护的函数被重入成功（counter 被增加两次）
    // 与 testReentrancyAttackReverts 形成对比：有 nonReentrant → revert，无 nonReentrant → 重入成功
    function testUnprotectedCallReentrySucceeds() public {
        UnprotectedAttacker unprotectedAttacker = new UnprotectedAttacker(mock);
        unprotectedAttacker.attack();
        // unprotectedCallWithCallback 中 counter++ 一次，回调 unprotectedCall 中 counter++ 一次
        assertEq(mock.counter(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                          跨函数重入
    //////////////////////////////////////////////////////////////*/

    // 反向：从 protectedCallWithCallback 重入 protectedCall 也会被阻止
    function testCrossFunctionReentrancy() public {
        CrossFunctionAttacker crossAttacker = new CrossFunctionAttacker(mock);
        vm.expectRevert("REENTRANCY");
        crossAttacker.attack();
    }

    /*//////////////////////////////////////////////////////////////
                          Fuzz Tests
    //////////////////////////////////////////////////////////////*/

    // Fuzz：多次调用后 counter 正确
    function testFuzzMultipleCalls(uint8 times) public {
        for (uint256 i = 0; i < times; i++) {
            mock.protectedCall();
        }
        assertEq(mock.counter(), times);
    }
}

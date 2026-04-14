// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// ReentrancyGuard 是 abstract contract，nonReentrant 是 modifier。
// 需要这个 Mock 合约继承并暴露 external 函数，使测试可以验证：
// 1. 正常调用通过
// 2. 重入调用被阻止（revert "REENTRANCY"）
contract MockReentrancyGuard is ReentrancyGuard {
    uint256 public counter;

    function protectedCall() external nonReentrant {
        counter++;
    }

    function protectedCallWithCallback(address target) external nonReentrant {
        counter++;
        (bool success, bytes memory retData) = target.call("");
        if (!success) {
            assembly {
                revert(add(retData, 0x20), mload(retData))
            }
        }
    }

    function unprotectedCall() external {
        counter++;
    }

    function unprotectedCallWithCallback(address target) external {
        counter++;
        (bool success, bytes memory retData) = target.call("");
        if (!success) {
            assembly {
                revert(add(retData, 0x20), mload(retData))
            }
        }
    }
}

// 攻击者合约：尝试重入 protectedCallWithCallback
contract ReentrancyAttacker {
    MockReentrancyGuard public target;

    constructor(MockReentrancyGuard _target) {
        target = _target;
    }

    function attack() external {
        target.protectedCallWithCallback(address(this));
    }

    fallback() external {
        target.protectedCallWithCallback(address(this));
    }
}

// 正常回调合约：不尝试重入
contract SafeCallback {
    uint256 public callbackCount;

    fallback() external {
        callbackCount++;
    }
}

// 跨函数重入攻击者：在回调中调用另一个 nonReentrant 函数
contract CrossFunctionAttacker {
    MockReentrancyGuard public target;

    constructor(MockReentrancyGuard _target) {
        target = _target;
    }

    function attack() external {
        target.protectedCallWithCallback(address(this));
    }

    fallback() external {
        target.protectedCall();
    }
}

// 未保护函数的重入攻击者：在回调中调用 unprotectedCall（会成功）
contract UnprotectedAttacker {
    MockReentrancyGuard public target;

    constructor(MockReentrancyGuard _target) {
        target = _target;
    }

    function attack() external {
        target.unprotectedCallWithCallback(address(this));
    }

    fallback() external {
        target.unprotectedCall();
    }
}

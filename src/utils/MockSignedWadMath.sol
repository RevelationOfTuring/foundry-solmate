// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {wadMul, wadDiv, wadExp, wadLn, wadPow} from "solmate/utils/SignedWadMath.sol";

// SignedWadMath 的所有函数都是 free function，编译时内联到调用合约中。
// vm.expectRevert 只能捕获外部调用的 revert，无法捕获内联函数的 revert。
// 因此需要这个 Mock 合约将 free function 包装为 external 调用，使测试中的 revert 可被捕获。
contract MockSignedWadMath {
    function callWadMul(int256 x, int256 y) external pure returns (int256) {
        return wadMul(x, y);
    }

    function callWadDiv(int256 x, int256 y) external pure returns (int256) {
        return wadDiv(x, y);
    }

    function callWadExp(int256 x) external pure returns (int256) {
        return wadExp(x);
    }

    function callWadLn(int256 x) external pure returns (int256) {
        return wadLn(x);
    }

    function callWadPow(int256 x, int256 y) external pure returns (int256) {
        return wadPow(x, y);
    }
}

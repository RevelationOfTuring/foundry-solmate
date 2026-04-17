// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {LibString} from "solmate/utils/LibString.sol";

contract LibStringTest is Test {
    using LibString for uint256;
    using LibString for int256;

    /*//////////////////////////////////////////////////////////////
                    toString(uint256)：基础值
    //////////////////////////////////////////////////////////////*/

    // 零
    function testToStringZero() public pure {
        assertEq(uint256(0).toString(), "0");
    }

    // 个位数
    function testToStringSingleDigit() public pure {
        assertEq(uint256(1).toString(), "1");
        assertEq(uint256(9).toString(), "9");
    }

    // 多位数
    function testToStringMultiDigit() public pure {
        assertEq(uint256(10).toString(), "10");
        assertEq(uint256(123).toString(), "123");
        assertEq(uint256(1000000).toString(), "1000000");
    }

    // uint256 最大值（78 位十进制）
    function testToStringUint256Max() public pure {
        assertEq(
            type(uint256).max.toString(),
            "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        );
    }

    // 2 的幂次
    function testToStringPowersOfTwo() public pure {
        assertEq(uint256(256).toString(), "256");
        assertEq(uint256(1024).toString(), "1024");
        assertEq(uint256(2 ** 128).toString(), "340282366920938463463374607431768211456");
    }

    /*//////////////////////////////////////////////////////////////
                    toString(int256)
    //////////////////////////////////////////////////////////////*/

    // 正数直接委托给 uint256 版本
    function testToStringIntPositive() public pure {
        assertEq(int256(0).toString(), "0");
        assertEq(int256(1).toString(), "1");
        assertEq(int256(123).toString(), "123");
    }

    // 个位负数
    function testToStringIntNegativeSingleDigit() public pure {
        assertEq(int256(-1).toString(), "-1");
        assertEq(int256(-9).toString(), "-9");
    }

    // 多位负数
    function testToStringIntNegativeMultiDigit() public pure {
        assertEq(int256(-123).toString(), "-123");
        assertEq(int256(-1000000).toString(), "-1000000");
    }

    // int256 最小值（unchecked 保证不 revert）
    function testToStringInt256Min() public pure {
        assertEq(
            type(int256).min.toString(),
            "-57896044618658097711785492504343953926634992332820282019728792003956564819968"
        );
    }

    // int256 最大值
    function testToStringInt256Max() public pure {
        assertEq(
            type(int256).max.toString(), "57896044618658097711785492504343953926634992332820282019728792003956564819967"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          Fuzz Tests
    //////////////////////////////////////////////////////////////*/

    // Fuzz：uint256 转字符串，与 vm.toString 对比验证正确性
    function testFuzzToStringUint256(uint256 value) public pure {
        assertEq(value.toString(), vm.toString(value));
    }

    // Fuzz：int256 转字符串，与 vm.toString 对比验证正确性
    function testFuzzToStringInt256(int256 value) public pure {
        assertEq(value.toString(), vm.toString(value));
    }
}

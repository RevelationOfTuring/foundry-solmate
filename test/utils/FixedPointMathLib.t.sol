// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MockFixedPointMathLib} from "src/utils/MockFixedPointMathLib.sol";

contract FixedPointMathLibTest is Test {
    using FixedPointMathLib for uint256;

    MockFixedPointMathLib mock = new MockFixedPointMathLib();

    uint256 constant WAD = 1e18;
    uint256 constant MAX = type(uint256).max;

    /*//////////////////////////////////////////////////////////////
                    mulWadDown — WAD 定点乘法（向下取整）
    //////////////////////////////////////////////////////////////*/

    // 正向：1 wad × 1 wad = 1 wad
    function testMulWadDownOneByOne() public pure {
        assertEq(uint256(1e18).mulWadDown(1e18), 1e18);
    }

    // 正向：0 × 任何数 = 0
    function testMulWadDownByZero() public pure {
        assertEq(uint256(0).mulWadDown(1e18), 0);
        assertEq(uint256(1e18).mulWadDown(0), 0);
    }

    // 正向：1.5 × 2.0 = 3.0
    function testMulWadDownFractional() public pure {
        assertEq(uint256(1.5e18).mulWadDown(2e18), 3e18);
    }

    // 正向：0.5 × 0.5 = 0.25
    function testMulWadDownHalfByHalf() public pure {
        assertEq(uint256(0.5e18).mulWadDown(0.5e18), 0.25e18);
    }

    // 正向：向下取整验证 — 1 × 1 / WAD = 0（最小精度丢失）
    function testMulWadDownRoundsDown() public pure {
        // 1 × 1 = 1，1 / 1e18 = 0（向下取整）
        assertEq(uint256(1).mulWadDown(1), 0);
    }

    // 反向：溢出 → revert
    function testRevertMulWadDownOverflow() public {
        vm.expectRevert();
        mock.callMulWadDown(MAX, 2);
    }

    // Fuzz：mulWadDown(x, WAD) == x（乘以 1 等于自身）
    function testFuzzMulWadDownIdentity(uint256 x) public pure {
        // x * WAD 不能溢出（mulDivDown 的溢出检查：x <= MAX / y）
        vm.assume(x <= MAX / WAD);
        assertEq(x.mulWadDown(WAD), x);
    }

    // Fuzz：交换律 mulWadDown(x, y) == mulWadDown(y, x)
    function testFuzzMulWadDownCommutative(uint256 x, uint256 y) public pure {
        // 确保 x * y 不溢出
        if (x != 0) y = bound(y, 0, MAX / x);
        assertEq(x.mulWadDown(y), y.mulWadDown(x));
    }

    /*//////////////////////////////////////////////////////////////
                    mulWadUp — WAD 定点乘法（向上取整）
    //////////////////////////////////////////////////////////////*/

    // 正向：1 wad × 1 wad = 1 wad
    function testMulWadUpOneByOne() public pure {
        assertEq(uint256(1e18).mulWadUp(1e18), 1e18);
    }

    // 正向：0 × 任何数 = 0
    function testMulWadUpByZero() public pure {
        assertEq(uint256(0).mulWadUp(1e18), 0);
        assertEq(uint256(1e18).mulWadUp(0), 0);
    }

    // 正向：向上取整验证 — 1 × 1 / WAD 向上取整 = 1
    function testMulWadUpRoundsUp() public pure {
        // 1 × 1 = 1，1 / 1e18 向上取整 = 1（而不是 0）
        assertEq(uint256(1).mulWadUp(1), 1);
    }

    // 正向：整除时 Up == Down
    function testMulWadUpEqualToDownWhenExact() public pure {
        assertEq(uint256(2e18).mulWadUp(3e18), uint256(2e18).mulWadDown(3e18));
    }

    // 正向：非整除时 Up > Down
    function testMulWadUpGreaterThanDownWhenNotExact() public pure {
        // 1 × 1：Down=0，Up=1
        assertGt(uint256(1).mulWadUp(1), uint256(1).mulWadDown(1));
    }

    // 反向：溢出 → revert
    function testRevertMulWadUpOverflow() public {
        vm.expectRevert();
        mock.callMulWadUp(MAX, 2);
    }

    // Fuzz：mulWadUp(x, y) >= mulWadDown(x, y)
    function testFuzzMulWadUpGeMulWadDown(uint256 x, uint256 y) public pure {
        // 确保 x * y 不溢出
        if (x != 0) y = bound(y, 0, MAX / x);
        assertGe(x.mulWadUp(y), x.mulWadDown(y));
    }

    /*//////////////////////////////////////////////////////////////
                    divWadDown — WAD 定点除法（向下取整）
    //////////////////////////////////////////////////////////////*/

    // 正向：3 wad / 2 wad = 1.5 wad
    function testDivWadDownBasic() public pure {
        assertEq(uint256(3e18).divWadDown(2e18), 1.5e18);
    }

    // 正向：1 wad / 1 wad = 1 wad
    function testDivWadDownOneByOne() public pure {
        assertEq(uint256(1e18).divWadDown(1e18), 1e18);
    }

    // 正向：0 / 任何数 = 0
    function testDivWadDownZeroDividend() public pure {
        assertEq(uint256(0).divWadDown(1e18), 0);
    }

    // 正向：向下取整验证
    function testDivWadDownRoundsDown() public pure {
        // 1 / 3e18：(1 × 1e18) / 3e18 = 1e18 / 3e18 = 0（向下取整）
        assertEq(uint256(1).divWadDown(3e18), 0);
    }

    // 反向：除以 0 → revert
    function testRevertDivWadDownByZero() public {
        vm.expectRevert();
        mock.callDivWadDown(1e18, 0);
    }

    // 反向：x * WAD 溢出 → revert
    function testRevertDivWadDownOverflow() public {
        vm.expectRevert();
        mock.callDivWadDown(MAX, 1);
    }

    // Fuzz：divWadDown(x, WAD) == x（除以 1 等于自身）
    function testFuzzDivWadDownIdentity(uint256 x) public pure {
        // x * WAD 不能溢出
        vm.assume(x <= MAX / WAD);
        assertEq(x.divWadDown(WAD), x);
    }

    /*//////////////////////////////////////////////////////////////
                    divWadUp — WAD 定点除法（向上取整）
    //////////////////////////////////////////////////////////////*/

    // 正向：整除时 Up == Down
    function testDivWadUpEqualToDownWhenExact() public pure {
        assertEq(uint256(3e18).divWadUp(1.5e18), uint256(3e18).divWadDown(1.5e18));
    }

    // 正向：向上取整验证
    function testDivWadUpRoundsUp() public pure {
        // 1 / 3e18：(1 × 1e18) / 3e18 向上取整 = 1（而不是 0）
        assertEq(uint256(1).divWadUp(3e18), 1);
    }

    // 反向：除以 0 → revert
    function testRevertDivWadUpByZero() public {
        vm.expectRevert();
        mock.callDivWadUp(1e18, 0);
    }

    // Fuzz：divWadUp(x, y) >= divWadDown(x, y)
    function testFuzzDivWadUpGeDivWadDown(uint256 x, uint256 y) public pure {
        vm.assume(y > 0);
        // 确保 x * WAD 不溢出
        x = bound(x, 0, MAX / WAD);
        assertGe(x.divWadUp(y), x.divWadDown(y));
    }

    /*//////////////////////////////////////////////////////////////
                    mulDivDown — 通用 mulDiv（向下取整）
    //////////////////////////////////////////////////////////////*/

    // 正向：(2 × 3) / 2 = 3
    function testMulDivDownBasic() public pure {
        assertEq(FixedPointMathLib.mulDivDown(2, 3, 2), 3);
    }

    // 正向：y == 0 不 revert，返回 0
    function testMulDivDownYZero() public pure {
        assertEq(FixedPointMathLib.mulDivDown(1e18, 0, 1e18), 0);
    }

    // 正向：x == 0 不 revert，返回 0
    function testMulDivDownXZero() public pure {
        assertEq(FixedPointMathLib.mulDivDown(0, 1e18, 1e18), 0);
    }

    // 正向：向下取整 (10 × 10) / 3 = 33
    function testMulDivDownRoundsDown() public pure {
        assertEq(FixedPointMathLib.mulDivDown(10, 10, 3), 33);
    }

    // 反向：denominator == 0 → revert
    function testRevertMulDivDownDenominatorZero() public {
        vm.expectRevert();
        mock.callMulDivDown(1, 1, 0);
    }

    // 反向：x * y 溢出 → revert
    function testRevertMulDivDownOverflow() public {
        vm.expectRevert();
        mock.callMulDivDown(MAX, 2, 1);
    }

    // 边界：MAX × 1 / 1 = MAX（不溢出）
    function testMulDivDownMaxTimesOne() public pure {
        assertEq(FixedPointMathLib.mulDivDown(MAX, 1, 1), MAX);
    }

    // Fuzz：mulDivDown(x, d, d) == x（乘除同一个数等于自身）
    function testFuzzMulDivDownCancelOut(uint256 x, uint256 d) public pure {
        vm.assume(d > 0);
        vm.assume(x <= MAX / d);
        assertEq(FixedPointMathLib.mulDivDown(x, d, d), x);
    }

    /*//////////////////////////////////////////////////////////////
                    mulDivUp — 通用 mulDiv（向上取整）
    //////////////////////////////////////////////////////////////*/

    // 正向：整除时 Up == Down
    function testMulDivUpEqualToDownWhenExact() public pure {
        assertEq(FixedPointMathLib.mulDivUp(10, 10, 5), FixedPointMathLib.mulDivDown(10, 10, 5));
    }

    // 正向：向上取整 (10 × 10) / 3 = 34
    function testMulDivUpRoundsUp() public pure {
        assertEq(FixedPointMathLib.mulDivUp(10, 10, 3), 34);
    }

    // 正向：y == 0 不 revert，返回 0
    function testMulDivUpYZero() public pure {
        assertEq(FixedPointMathLib.mulDivUp(1e18, 0, 1e18), 0);
    }

    // 反向：denominator == 0 → revert
    function testRevertMulDivUpDenominatorZero() public {
        vm.expectRevert();
        mock.callMulDivUp(1, 1, 0);
    }

    // 反向：x * y 溢出 → revert
    function testRevertMulDivUpOverflow() public {
        vm.expectRevert();
        mock.callMulDivUp(MAX, 2, 1);
    }

    // Fuzz：mulDivUp - mulDivDown <= 1（隐含 up >= down）
    function testFuzzMulDivUpMinusDownAtMostOne(uint256 x, uint256 y, uint256 d) public pure {
        vm.assume(d > 0);
        // 确保 x * y 不溢出
        if (x != 0) y = bound(y, 0, MAX / x);
        uint256 up = FixedPointMathLib.mulDivUp(x, y, d);
        uint256 down = FixedPointMathLib.mulDivDown(x, y, d);
        assertLe(up - down, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    rpow — 定点数快速幂
    //////////////////////////////////////////////////////////////*/

    // 正向：0^0 = 1（即 scalar）
    function testRpowZeroToZero() public pure {
        assertEq(FixedPointMathLib.rpow(0, 0, WAD), WAD);
    }

    // 正向：0^n = 0（n > 0）
    function testRpowZeroToPositive() public pure {
        assertEq(FixedPointMathLib.rpow(0, 5, WAD), 0);
    }

    // 正向：x^0 = scalar
    function testRpowAnyToZero() public pure {
        assertEq(FixedPointMathLib.rpow(2e18, 0, WAD), WAD);
    }

    // 正向：x^1 = x
    function testRpowAnyToOne() public pure {
        assertEq(FixedPointMathLib.rpow(2e18, 1, WAD), 2e18);
    }

    // 正向：(2 wad)^2 = 4 wad
    function testRpowTwoSquared() public pure {
        assertEq(FixedPointMathLib.rpow(2e18, 2, WAD), 4e18);
    }

    // 正向：(2 wad)^10 = 1024 wad
    function testRpowTwoToTen() public pure {
        assertEq(FixedPointMathLib.rpow(2e18, 10, WAD), 1024e18);
    }

    // 正向：纯整数快速幂 scalar=1，2^3 = 8
    function testRpowPureInteger() public pure {
        assertEq(FixedPointMathLib.rpow(2, 3, 1), 8);
    }

    // 正向：scalar=1，3^5 = 243
    function testRpowPureIntegerThreeToFive() public pure {
        assertEq(FixedPointMathLib.rpow(3, 5, 1), 243);
    }

    // 正向：scalar=1e27（RAY），(1.5 RAY)^2 = 2.25 RAY
    function testRpowWithRayScalar() public pure {
        uint256 ray = 1e27;
        assertEq(FixedPointMathLib.rpow(1.5e27, 2, ray), 2.25e27);
    }

    // 正向：DeFi 复利 — 年利率 5%，按秒复利，1 年 = 31536000 秒
    // 离散复利：(1 + 0.05/31536000)^31536000 ≈ 连续复利 e^0.05 ≈ 1.051271...
    function testRpowCompoundInterest() public pure {
        uint256 ratePerSecond = 1000000001585489599; // ≈ 1 + 0.05/31536000
        uint256 result = FixedPointMathLib.rpow(ratePerSecond, 31536000, WAD);
        // 验证结果在合理范围内：大于 1.051271 且小于 1.0512712
        assertGt(result, 1.051271e18);
        assertLt(result, 1.051272e18);
    }

    // 反向：x >= 2^128 → revert（x² 溢出）
    function testRevertRpowXTooLarge() public {
        vm.expectRevert();
        mock.callRpow(uint256(1) << 128, 2, WAD);
    }

    // 边界：(1 wad)^n = 1 wad（任意 n）
    function testRpowOneToAny() public pure {
        assertEq(FixedPointMathLib.rpow(WAD, 0, WAD), WAD);
        assertEq(FixedPointMathLib.rpow(WAD, 1, WAD), WAD);
        assertEq(FixedPointMathLib.rpow(WAD, 100, WAD), WAD);
        assertEq(FixedPointMathLib.rpow(WAD, 1000000, WAD), WAD);
    }

    // Fuzz：rpow(x, 1, scalar) == x
    function testFuzzRpowExponentOne(uint128 x) public pure {
        assertEq(FixedPointMathLib.rpow(uint256(x), 1, WAD), uint256(x));
    }

    // Fuzz：rpow(x, 0, scalar) == scalar
    function testFuzzRpowExponentZero(uint256 x, uint256 scalar) public pure {
        vm.assume(scalar > 0);
        assertEq(FixedPointMathLib.rpow(x, 0, scalar), scalar);
    }

    // 边界：scalar == 0 时不 revert，静默返回错误结果 0
    // half = 0（四舍五入失效），div(xxRound, 0) 在 EVM 中返回 0 而非 revert
    function testFuzzRpowScalarZeroSilentError(uint128 x, uint256 n) public pure {
        // x > 0：排除 x==0 的情况，因为 0^n = 0 本身就是正确结果，不算静默错误
        // n > 1：n==0 时走 switch 直接返回 scalar(=0)，n==1 时不进循环直接返回 x，
        //        都不会执行 div(xxRound, scalar)，触发不了静默错误
        vm.assume(x > 0 && n > 1);
        assertEq(FixedPointMathLib.rpow(uint256(x), n, 0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    sqrt — 整数平方根
    //////////////////////////////////////////////////////////////*/

    // 正向：sqrt(0) = 0
    function testSqrtZero() public pure {
        assertEq(FixedPointMathLib.sqrt(0), 0);
    }

    // 正向：sqrt(1) = 1
    function testSqrtOne() public pure {
        assertEq(FixedPointMathLib.sqrt(1), 1);
    }

    // 正向：sqrt(4) = 2
    function testSqrtFour() public pure {
        assertEq(FixedPointMathLib.sqrt(4), 2);
    }

    // 正向：sqrt(100) = 10
    function testSqrtHundred() public pure {
        assertEq(FixedPointMathLib.sqrt(100), 10);
    }

    // 正向：非完全平方数 → 向下取整 sqrt(8) = 2
    function testSqrtEight() public pure {
        assertEq(FixedPointMathLib.sqrt(8), 2);
    }

    // 正向：非完全平方数 sqrt(2) = 1
    function testSqrtTwo() public pure {
        assertEq(FixedPointMathLib.sqrt(2), 1);
    }

    // 边界：floor(sqrt(2^256 - 1)) = 2^128 - 1
    function testSqrtMax() public pure {
        uint256 result = FixedPointMathLib.sqrt(MAX);
        // floor(sqrt(2^256 - 1)) = 2^128 - 1，即 uint128 最大值
        assertEq(result, type(uint128).max);
        // 验证 floor 性质：result² <= MAX
        assertLe(result * result, MAX);
    }

    // 边界：x < 2^24 时 4 个 if 分支都不命中，此处抽样最小的 [3, 255] 验证牛顿迭代对极小值仍能收敛
    function testSqrtSmallValues() public pure {
        // 在 [3, 255] 范围内均匀抽 8 个值（间隔 36）
        assertEq(FixedPointMathLib.sqrt(3), 1);
        assertEq(FixedPointMathLib.sqrt(39), 6);
        assertEq(FixedPointMathLib.sqrt(75), 8);
        assertEq(FixedPointMathLib.sqrt(111), 10);
        assertEq(FixedPointMathLib.sqrt(147), 12);
        assertEq(FixedPointMathLib.sqrt(183), 13);
        assertEq(FixedPointMathLib.sqrt(219), 14);
        assertEq(FixedPointMathLib.sqrt(255), 15);
        // 边缘确认：x == 256
        assertEq(FixedPointMathLib.sqrt(256), 16);
    }

    // Fuzz：sqrt(x)² <= x < (sqrt(x)+1)²
    function testFuzzSqrtProperty(uint256 x) public pure {
        uint256 root = FixedPointMathLib.sqrt(x);
        // root² <= x
        assertLe(root * root, x);
        // (root+1)² > x，等价于 x / (root+1) < (root+1)，避免 (root+1)² 溢出
        assertLt(x / (root + 1), root + 1);
    }

    // Fuzz：完全平方数 sqrt(n²) == n
    function testFuzzSqrtPerfectSquare(uint128 n) public pure {
        assertEq(FixedPointMathLib.sqrt(uint256(n) * uint256(n)), uint256(n));
    }

    /*//////////////////////////////////////////////////////////////
                    unsafeMod — 不安全取模
    //////////////////////////////////////////////////////////////*/

    // 正向：10 % 3 = 1
    function testUnsafeModBasic() public pure {
        assertEq(FixedPointMathLib.unsafeMod(10, 3), 1);
    }

    // 正向：整除 6 % 3 = 0
    function testUnsafeModExact() public pure {
        assertEq(FixedPointMathLib.unsafeMod(6, 3), 0);
    }

    // 正向：0 % y = 0
    function testUnsafeModZeroDividend() public pure {
        assertEq(FixedPointMathLib.unsafeMod(0, 5), 0);
    }

    // 边界：y == 0 返回 0（不 revert）
    function testUnsafeModByZero() public pure {
        assertEq(FixedPointMathLib.unsafeMod(10, 0), 0);
    }

    // Fuzz：unsafeMod(x, y) < y（当 y > 0）
    function testFuzzUnsafeModLessThanDivisor(uint256 x, uint256 y) public pure {
        vm.assume(y > 0);
        assertLt(FixedPointMathLib.unsafeMod(x, y), y);
    }

    /*//////////////////////////////////////////////////////////////
                    unsafeDiv — 不安全除法
    //////////////////////////////////////////////////////////////*/

    // 正向：10 / 3 = 3
    function testUnsafeDivBasic() public pure {
        assertEq(FixedPointMathLib.unsafeDiv(10, 3), 3);
    }

    // 正向：整除 6 / 3 = 2
    function testUnsafeDivExact() public pure {
        assertEq(FixedPointMathLib.unsafeDiv(6, 3), 2);
    }

    // 正向：0 / y = 0
    function testUnsafeDivZeroDividend() public pure {
        assertEq(FixedPointMathLib.unsafeDiv(0, 5), 0);
    }

    // 边界：y == 0 返回 0（不 revert）
    function testUnsafeDivByZero() public pure {
        assertEq(FixedPointMathLib.unsafeDiv(10, 0), 0);
    }

    // Fuzz：unsafeDiv(x, 1) == x
    function testFuzzUnsafeDivByOne(uint256 x) public pure {
        assertEq(FixedPointMathLib.unsafeDiv(x, 1), x);
    }

    /*//////////////////////////////////////////////////////////////
                    unsafeDivUp — 不安全向上取整除法
    //////////////////////////////////////////////////////////////*/

    // 正向：整除 6 / 3 = 2
    function testUnsafeDivUpExact() public pure {
        assertEq(FixedPointMathLib.unsafeDivUp(6, 3), 2);
    }

    // 正向：向上取整 7 / 3 = 3
    function testUnsafeDivUpRoundsUp() public pure {
        assertEq(FixedPointMathLib.unsafeDivUp(7, 3), 3);
    }

    // 正向：0 / y = 0
    function testUnsafeDivUpZeroDividend() public pure {
        assertEq(FixedPointMathLib.unsafeDivUp(0, 5), 0);
    }

    // 边界：y == 0 返回 0（不 revert）
    function testUnsafeDivUpByZero() public pure {
        assertEq(FixedPointMathLib.unsafeDivUp(10, 0), 0);
    }

    // Fuzz：unsafeDivUp(x, y) - unsafeDiv(x, y) <= 1（隐含 up >= down）
    function testFuzzUnsafeDivUpMinusDivAtMostOne(uint256 x, uint256 y) public pure {
        vm.assume(y > 0);
        assertLe(FixedPointMathLib.unsafeDivUp(x, y) - FixedPointMathLib.unsafeDiv(x, y), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        跨函数集成测试
    //////////////////////////////////////////////////////////////*/

    // 集成：mulWadDown 和 divWadDown 互逆
    // 误差推导：
    //   step1: z = mulWadDown(x, y) = floor((x × y) / WAD)
    //          设截断余项为 err1（0 <= err1 < 1），则 z = (x × y / WAD - err1)
    //   step2: result = divWadDown(z, y) = floor((z × WAD) / y)
    //          代入 z：= floor(((x × y / WAD - err1) × WAD) / y)
    //                  = floor((x × y - err1 × WAD) / y)
    //                  = floor(x - err1 × WAD / y)
    //          设截断余项为 err2（0 <= err2 < 1），则 result = x - err1 × WAD / y - err2
    //   总误差 |result - x| = err1 × WAD / y + err2 < 1 × WAD / y + 1 = WAD / y + 1
    //   当 y >= 1e9 时：误差 < 1e18 / 1e9 + 1 = 1e9 + 1 ≈ 1e9
    function testIntegrationMulDivWadInverse() public pure {
        uint256 x = 123.456e18;
        uint256 y = 7.89e18;
        uint256 z = x.mulWadDown(y);
        uint256 result = z.divWadDown(y);
        assertApproxEqAbs(result, x, 1e9);
    }

    // 集成：rpow(x, 2, 1) 再 sqrt 应回到 x（纯整数平方再开方）
    function testFuzzIntegrationRpowSqrt(uint128 x) public pure {
        uint256 squared = FixedPointMathLib.rpow(uint256(x), 2, 1);
        assertEq(FixedPointMathLib.sqrt(squared), uint256(x));
    }
}

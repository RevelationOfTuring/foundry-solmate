// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    toWadUnsafe,
    toDaysWadUnsafe,
    fromDaysWadUnsafe,
    unsafeWadMul,
    unsafeWadDiv,
    wadMul,
    wadDiv,
    wadPow,
    wadExp,
    wadLn,
    unsafeDiv
} from "solmate/utils/SignedWadMath.sol";
import {MockSignedWadMath} from "src/utils/MockSignedWadMath.sol";

contract SignedWadMathTest is Test {
    MockSignedWadMath mock = new MockSignedWadMath();

    // wad 运算的误差容差：1e9 即实数 1e-9，对 DeFi 场景足够
    uint256 constant TOLERANCE = 1e9;

    // wadExp 输入截断阈值：x <= 此值时直接返回 0，因为 e^x 太小无法用 wad 表示
    int256 constant WADEXP_ZERO_CUTOFF = -42139678854452767551;
    // wadExp 输入上界：x >= 此值时 revert("EXP_OVERFLOW")，结果溢出 int256
    int256 constant WADEXP_MAX_INPUT = 135305999368893231589;

    // helper：集中抑制 unsafe-typecast lint warning
    // 截断安全性由调用方保证
    function toInt256(uint256 x) internal pure returns (int256) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return int256(x);
    }

    /*//////////////////////////////////////////////////////////////
                        toWadUnsafe — 整数转 wad
    //////////////////////////////////////////////////////////////*/

    // 正向：0 转 wad 得 0
    function testToWadUnsafeZero() public pure {
        assertEq(toWadUnsafe(0), 0);
    }

    // 正向：1 转 wad 得 1e18
    function testToWadUnsafeOne() public pure {
        assertEq(toWadUnsafe(1), 1e18);
    }

    // Fuzz：toWadUnsafe(x) == x * 1e18（在安全范围内）
    function testFuzzToWadUnsafe(uint256 x) public pure {
        // 限制范围避免溢出 int256
        vm.assume(x <= uint256(type(int256).max) / 1e18);
        assertEq(toWadUnsafe(x), toInt256(x) * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                     toDaysWadUnsafe — 秒转 wad 天数
    //////////////////////////////////////////////////////////////*/

    // 正向：0 秒 → 0 wad 天
    function testToDaysWadUnsafeZero() public pure {
        assertEq(toDaysWadUnsafe(0), 0);
    }

    // 正向：1 分钟 = 1/1440 天
    function testToDaysWadUnsafeOneMinute() public pure {
        // 1e18 / 1440 = 694444444444444（截断）
        assertEq(toDaysWadUnsafe(1 minutes), 694444444444444);
    }

    // 正向：1 小时 = 1/24 天
    function testToDaysWadUnsafeOneHour() public pure {
        // 1e18 / 24 = 41666666666666666（截断）
        assertEq(toDaysWadUnsafe(1 hours), 41666666666666666);
    }

    // 正向：86400 秒 = 1 天
    function testToDaysWadUnsafeOneDay() public pure {
        assertEq(toDaysWadUnsafe(1 days), 1e18);
    }

    // 正向：1 周 = 7 天
    function testToDaysWadUnsafeOneWeek() public pure {
        assertEq(toDaysWadUnsafe(1 weeks), 7e18);
    }

    /*//////////////////////////////////////////////////////////////
                    fromDaysWadUnsafe — wad 天数转秒
    //////////////////////////////////////////////////////////////*/

    // 正向：0 wad 天 → 0 秒
    function testFromDaysWadUnsafeZero() public pure {
        assertEq(fromDaysWadUnsafe(0), 0);
    }

    // 正向：1/1440 wad 天 → 1 分钟
    function testFromDaysWadUnsafeOneMinute() public pure {
        // 694444444444444 = 1e18 / 1440（截断）
        assertEq(fromDaysWadUnsafe(694444444444444), 1 minutes - 1); // 截断误差：实际 59.999...
    }

    // 正向：1/24 wad 天 → 1 小时
    function testFromDaysWadUnsafeOneHour() public pure {
        // 41666666666666666 = 1e18 / 24（截断）
        assertEq(fromDaysWadUnsafe(41666666666666666), 1 hours - 1); // 截断误差：实际 3599.999...
    }

    // 正向：1 wad 天 → 1 天
    function testFromDaysWadUnsafeOneDay() public pure {
        assertEq(fromDaysWadUnsafe(1e18), 1 days);
    }

    // 正向：7 wad 天 → 1 周
    function testFromDaysWadUnsafeOneWeek() public pure {
        assertEq(fromDaysWadUnsafe(7e18), 1 weeks);
    }

    // 正向：toDaysWadUnsafe 和 fromDaysWadUnsafe 互逆（整天数）
    function testToDaysFromDaysRoundTrip() public pure {
        assertEq(fromDaysWadUnsafe(toDaysWadUnsafe(30 days)), 30 days);
    }

    // Fuzz：整天数的往返转换
    function testFuzzToDaysFromDaysRoundTrip(uint256 days_) public pure {
        // days_ × 86400 × 1e18 不能溢出 uint256
        vm.assume(days_ <= type(uint256).max / 1e18 / 1 days);
        uint256 seconds_ = days_ * 1 days;
        assertEq(fromDaysWadUnsafe(toDaysWadUnsafe(seconds_)), seconds_);
    }

    /*//////////////////////////////////////////////////////////////
                    unsafeWadMul — wad 乘法（不检查溢出）
    //////////////////////////////////////////////////////////////*/

    // 正向：1 wad × 1 wad = 1 wad
    function testUnsafeWadMulOneByOne() public pure {
        assertEq(unsafeWadMul(1e18, 1e18), 1e18);
    }

    // 正向：0 × 任何数 = 0
    function testUnsafeWadMulByZero() public pure {
        assertEq(unsafeWadMul(0, 1e18), 0);
        assertEq(unsafeWadMul(1e18, 0), 0);
    }

    // 正向：2 wad × 3 wad = 6 wad
    function testUnsafeWadMulTwoByThree() public pure {
        assertEq(unsafeWadMul(2e18, 3e18), 6e18);
    }

    // 正向：负数乘法
    function testUnsafeWadMulNegative() public pure {
        assertEq(unsafeWadMul(-1e18, 2e18), -2e18);
        assertEq(unsafeWadMul(-1e18, -1e18), 1e18);
    }

    // 正向：小数乘法 0.5 × 0.5 = 0.25
    function testUnsafeWadMulFractional() public pure {
        assertEq(unsafeWadMul(0.5e18, 0.5e18), 0.25e18);
    }

    /*//////////////////////////////////////////////////////////////
                    unsafeWadDiv — wad 除法（不检查溢出/除零）
    //////////////////////////////////////////////////////////////*/

    // 正向：6 wad / 2 wad = 3 wad
    function testUnsafeWadDivSixByTwo() public pure {
        assertEq(unsafeWadDiv(6e18, 2e18), 3e18);
    }

    // 正向：1 wad / 1 wad = 1 wad
    function testUnsafeWadDivOneByOne() public pure {
        assertEq(unsafeWadDiv(1e18, 1e18), 1e18);
    }

    // 正向：负数除法
    function testUnsafeWadDivNegative() public pure {
        assertEq(unsafeWadDiv(-6e18, 2e18), -3e18);
        assertEq(unsafeWadDiv(-6e18, -2e18), 3e18);
    }

    // 边界：除以 0 返回 0（sdiv 除零行为）
    function testUnsafeWadDivByZero() public pure {
        assertEq(unsafeWadDiv(1e18, 0), 0);
    }

    // 正向：小数除法 0.1 wad / 0.4 wad = 0.25 wad
    function testUnsafeWadDivFractional() public pure {
        assertEq(unsafeWadDiv(0.1e18, 0.4e18), 0.25e18);
    }

    /*//////////////////////////////////////////////////////////////
                  wadMul — wad 乘法（带溢出检查）
    //////////////////////////////////////////////////////////////*/

    // 正向：1 wad × 1 wad = 1 wad
    function testWadMulOneByOne() public pure {
        assertEq(wadMul(1e18, 1e18), 1e18);
    }

    // 正向：0 × 任何数 = 0
    function testWadMulByZero() public pure {
        assertEq(wadMul(0, 1e18), 0);
        assertEq(wadMul(1e18, 0), 0);
    }

    // 正向：2 wad × 3 wad = 6 wad
    function testWadMulTwoByThree() public pure {
        assertEq(wadMul(2e18, 3e18), 6e18);
    }

    // 正向：负数乘法
    function testWadMulNegative() public pure {
        assertEq(wadMul(-1e18, 2e18), -2e18);
        assertEq(wadMul(-1e18, -1e18), 1e18);
    }

    // 正向：小数乘法 0.5 × 0.5 = 0.25
    function testWadMulFractional() public pure {
        assertEq(wadMul(0.5e18, 0.5e18), 0.25e18);
    }

    // 反向：大数溢出 → revert（通过外部合约调用，vm.expectRevert 才能捕获）
    function testRevertWadMulOverflow() public {
        vm.expectRevert();
        mock.callWadMul(type(int256).max, 2e18);
    }

    // 反向：二补码陷阱 x=-1, y=type(int256).min → revert
    function testRevertWadMulTwosComplementTrap() public {
        vm.expectRevert();
        mock.callWadMul(-1, type(int256).min);
    }

    // 边界：x=-1, y=type(int256).max → 不溢出，正常返回
    function testWadMulNegOneTimesMaxDoesNotRevert() public pure {
        // (-1) × type(int256).max = -type(int256).max，在 int256 范围内
        int256 result = wadMul(-1, type(int256).max);
        // wadMul 还要 / 1e18，所以结果 = -type(int256).max / 1e18
        assertEq(result, -type(int256).max / 1e18);
    }

    // Fuzz：wadMul(x, 1e18) == x（乘以 1 等于自身）
    function testFuzzWadMulIdentity(int256 x) public pure {
        // 限制范围：x * 1e18 不能溢出
        vm.assume(x >= type(int256).min / 1e18 && x <= type(int256).max / 1e18);
        assertEq(wadMul(x, 1e18), x);
    }

    // Fuzz：wadMul 交换律 wadMul(x, y) == wadMul(y, x)
    function testFuzzWadMulCommutative(int128 x, int128 y) public pure {
        // x 和 y 用 int128 是为了避免乘法溢出
        assertEq(wadMul(int256(x), int256(y)), wadMul(int256(y), int256(x)));
    }

    /*//////////////////////////////////////////////////////////////
                  wadDiv — wad 除法（带溢出检查）
    //////////////////////////////////////////////////////////////*/

    // 正向：6 wad / 2 wad = 3 wad
    function testWadDivSixByTwo() public pure {
        assertEq(wadDiv(6e18, 2e18), 3e18);
    }

    // 正向：1 wad / 1 wad = 1 wad
    function testWadDivOneByOne() public pure {
        assertEq(wadDiv(1e18, 1e18), 1e18);
    }

    // 正向：负数除法
    function testWadDivNegative() public pure {
        assertEq(wadDiv(-6e18, 2e18), -3e18);
        assertEq(wadDiv(-6e18, -2e18), 3e18);
    }

    // 正向：小数除法 0.01 wad / 0.2 wad = 0.05 wad
    function testWadDivFractional() public pure {
        assertEq(wadDiv(0.01e18, 0.2e18), 0.05e18);
    }

    // 反向：除以 0 → revert
    function testRevertWadDivByZero() public {
        vm.expectRevert();
        mock.callWadDiv(1e18, 0);
    }

    // 反向：x * 1e18 溢出 → revert
    function testRevertWadDivOverflow() public {
        vm.expectRevert();
        mock.callWadDiv(type(int256).max, 1);
    }

    // Fuzz：wadDiv(x, 1e18) == x（除以 1 等于自身）
    function testFuzzWadDivIdentity(int256 x) public pure {
        // 限制范围：x * 1e18 不能溢出
        vm.assume(x >= type(int256).min / 1e18 && x <= type(int256).max / 1e18);
        assertEq(wadDiv(x, 1e18), x);
    }

    // Fuzz：wadMul 和 wadDiv 互逆（在安全范围内）
    // 误差推导：
    //   step1: z = wadMul(x, y) = x * y / 1e18，截断余项 err1，0 <= err1 < 1
    //   step2: result = wadDiv(z, y) = (z_real - err1) * 1e18 / y，截断余项 err2，0 <= err2 < 1
    //   总误差 = 被err放大的误差 + err2 = err1 * 1e18 / |y| + err2 < 1e18 / |y| + 1
    //   当 |y| > 1e9 时：1e18 / 1e9 + 1 = 1000000001 ≈ 1e9
    // 选 1e9 而非更大值（如 1e15）：fuzz 覆盖范围更大，1e-9 实数精度对 DeFi 场景已足够
    function testFuzzWadMulDivInverse(int128 x, int128 y) public pure {
        int256 x_ = int256(x);
        int256 y_ = int256(y);
        vm.assume(y_ > toInt256(1e18 / TOLERANCE) || y_ < -toInt256(1e18 / TOLERANCE));
        int256 result = wadDiv(wadMul(x_, y_), y_);
        assertApproxEqAbs(result, x_, TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                    wadExp — 自然指数函数 e^x
    //////////////////////////////////////////////////////////////*/

    // 正向：e^0 = 1
    function testWadExpZero() public pure {
        assertEq(wadExp(0), 1e18);
    }

    // 正向：e^1 ≈ 2.718281828...
    function testWadExpOne() public pure {
        int256 result = wadExp(1e18);
        // e = 2.718281828459045...e18
        assertApproxEqAbs(result, 2718281828459045235, TOLERANCE);
    }

    // 正向：e^2 ≈ 7.389056099...
    function testWadExpTwo() public pure {
        int256 result = wadExp(2e18);
        assertApproxEqAbs(result, 7389056098930650227, TOLERANCE);
    }

    // 正向：e^(-1) ≈ 0.367879441...
    function testWadExpNegOne() public pure {
        int256 result = wadExp(-1e18);
        assertApproxEqAbs(result, 367879441171442321, TOLERANCE);
    }

    // 边界：下界 — 结果太小直接返回 0
    function testWadExpLowerBound() public pure {
        // x <= WADEXP_ZERO_CUTOFF 时返回 0
        assertEq(wadExp(WADEXP_ZERO_CUTOFF), 0);
        assertEq(wadExp(WADEXP_ZERO_CUTOFF - 1), 0);
        assertEq(wadExp(type(int256).min), 0);
    }

    // 边界：下界 +1 — 不走截断分支，但正常计算结果也是 0（精度不足以表示）
    function testWadExpJustAboveLowerBound() public pure {
        assertEq(wadExp(WADEXP_ZERO_CUTOFF + 1), 0);
    }

    // 反向：上界溢出 → revert
    function testRevertWadExpOverflow() public {
        vm.expectRevert("EXP_OVERFLOW");
        mock.callWadExp(WADEXP_MAX_INPUT);
    }

    // 边界：接近上界但未溢出
    function testWadExpJustBelowUpperBound() public pure {
        assertTrue(wadExp(WADEXP_MAX_INPUT - 1) > 0);
    }

    // 正向：e^x × e^(-x) ≈ 1（互为倒数）
    function testWadExpTimesExpNeg() public pure {
        int256 expPos = wadExp(3e18);
        int256 expNeg = wadExp(-3e18);
        // expPos × expNeg ≈ 1e18
        assertApproxEqAbs(wadMul(expPos, expNeg), 1e18, TOLERANCE);
    }

    // Fuzz：e^x 始终非负（在有效范围内）
    function testFuzzWadExpAlwaysNonNegative(int256 x) public pure {
        // 限制到有效范围内
        vm.assume(x > WADEXP_ZERO_CUTOFF && x < WADEXP_MAX_INPUT);
        assertTrue(wadExp(x) >= 0);
    }

    // Fuzz + FFI：wadExp 精度验证（期望值由 Python decimal 高精度计算）
    // 误差来源：Solidity 实现使用 Padé 近似 + 定点截断，与数学精确值有偏差
    function testFuzzWadExpAgainstPython(int256 x) public {
        // wadExp 有效范围：下界返回 0，上界 revert
        vm.assume(x > WADEXP_ZERO_CUTOFF && x < WADEXP_MAX_INPUT);

        int256 actual = wadExp(x);

        // 通过 ffi 调用 Python 脚本计算高精度期望值
        string[] memory args = new string[](4);
        args[0] = "python3";
        args[1] = "scripts/wad_exp_ln_reference.py";
        args[2] = "exp";
        args[3] = vm.toString(x);
        // forge-lint: disable-next-line(unsafe-cheatcode)
        bytes memory ret = vm.ffi(args);
        int256 expected = abi.decode(ret, (int256));

        assertApproxEqRel(actual, expected, TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                     wadLn — 自然对数 ln(x)
    //////////////////////////////////////////////////////////////*/

    // 正向：ln(1) = 0
    function testWadLnOne() public pure {
        assertEq(wadLn(1e18), 0);
    }

    // 正向：ln(e) ≈ 1
    function testWadLnE() public pure {
        // e ≈ 2.718281828459045e18
        assertApproxEqAbs(wadLn(2718281828459045235), 1e18, TOLERANCE);
    }

    // 正向：ln(e^2) ≈ 2
    function testWadLnESquared() public pure {
        assertApproxEqAbs(wadLn(wadExp(2e18)), 2e18, TOLERANCE);
    }

    // 正向：ln(2) ≈ 0.693147180...
    function testWadLnTwo() public pure {
        assertApproxEqAbs(wadLn(2e18), 693147180559945309, TOLERANCE);
    }

    // 正向：ln(0.5) ≈ -0.693147180...（小于 1 的数取 ln 为负）
    function testWadLnHalf() public pure {
        assertApproxEqAbs(wadLn(0.5e18), -693147180559945309, TOLERANCE);
    }

    // 反向：ln(0) → revert
    function testRevertWadLnZero() public {
        vm.expectRevert("UNDEFINED");
        mock.callWadLn(0);
    }

    // 反向：ln(负数) → revert
    function testRevertWadLnNegative() public {
        vm.expectRevert("UNDEFINED");
        mock.callWadLn(-1);
    }

    // 正向：wadLn 和 wadExp 互逆 — ln(e^x) ≈ x
    function testWadLnExpInverse() public pure {
        int256 x = 5e18;
        assertApproxEqAbs(wadLn(wadExp(x)), x, TOLERANCE);
    }

    // 正向：wadExp 和 wadLn 互逆 — e^(ln(x)) ≈ x
    function testWadExpLnInverse() public pure {
        int256 x = 10e18;
        assertApproxEqAbs(wadExp(wadLn(x)), x, TOLERANCE);
    }

    // 正向：ln(a × b) ≈ ln(a) + ln(b)
    function testWadLnProductRule() public pure {
        int256 a = 0.3e18;
        int256 b = 0.7e18;
        int256 lnProduct = wadLn(wadMul(a, b)); // ln(0.21)
        int256 sumLn = wadLn(a) + wadLn(b); // ln(0.3) + ln(0.7)
        assertApproxEqAbs(lnProduct, sumLn, TOLERANCE);
    }

    // 边界：ln(1)（最小的 wad 正数，代表实数 1e-18）
    function testWadLnMinPositive() public pure {
        // ln(1e-18) ≈ -41.446... × 1e18
        assertApproxEqAbs(wadLn(1), -41446531673892822312, TOLERANCE);
    }

    // Fuzz：ln(x) 在 x > 1e18 时为正，在 0 < x < 1e18 时为负
    function testFuzzWadLnSign(int256 x) public pure {
        vm.assume(x > 0);
        int256 result = wadLn(x);
        if (x > 1e18) {
            assertTrue(result > 0);
        } else if (x < 1e18) {
            assertTrue(result < 0);
        } else {
            assertEq(result, 0);
        }
    }

    // Fuzz + FFI：wadLn 精度验证（期望值由 Python decimal 高精度计算）
    function testFuzzWadLnAgainstPython(int256 x) public {
        vm.assume(x > 0);

        int256 actual = wadLn(x);

        string[] memory args = new string[](4);
        args[0] = "python3";
        args[1] = "scripts/wad_exp_ln_reference.py";
        args[2] = "ln";
        args[3] = vm.toString(x);
        // forge-lint: disable-next-line(unsafe-cheatcode)
        bytes memory ret = vm.ffi(args);
        int256 expected = abi.decode(ret, (int256));

        assertApproxEqAbs(actual, expected, TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                     wadPow — wad 幂运算
    //////////////////////////////////////////////////////////////*/

    // 正向：x^0 → wadExp(0) = 1
    // 注意：wadPow(x, 0) 内部会先调用 wadLn(x)，所以 x 必须 > 0
    function testWadPowZeroExponent() public pure {
        assertEq(wadPow(5e18, 0), 1e18);
    }

    // 正向：x^1 = x
    function testWadPowOneExponent() public pure {
        assertApproxEqAbs(wadPow(6e18, 1e18), 6e18, TOLERANCE);
    }

    // 正向：2^10 = 1024
    function testWadPowTwoToTen() public pure {
        assertApproxEqAbs(wadPow(2e18, 10e18), 1024e18, TOLERANCE);
    }

    // 正向：4^0.5 = 2（平方根）
    function testWadPowSquareRoot() public pure {
        assertApproxEqAbs(wadPow(4e18, 0.5e18), 2e18, TOLERANCE);
    }

    // 正向：8^(1/3) = 2（立方根）
    function testWadPowCubeRoot() public pure {
        // 1/3 ≈ 0.333333333333333333e18
        assertApproxEqAbs(wadPow(8e18, 333333333333333333), 2e18, TOLERANCE);
    }

    // 正向：负指数 2^(-1) = 0.5
    function testWadPowNegativeExponent() public pure {
        assertApproxEqAbs(wadPow(2e18, -1e18), 0.5e18, TOLERANCE);
    }

    // 反向：底数为 0 → revert（ln(0) 无定义）
    function testRevertWadPowZeroBase() public {
        vm.expectRevert("UNDEFINED");
        mock.callWadPow(0, 2e18);
    }

    // 反向：底数为负数 → revert（ln(负数) 无定义）
    function testRevertWadPowNegativeBase() public {
        vm.expectRevert("UNDEFINED");
        mock.callWadPow(-1e18, 2e18);
    }

    // Fuzz + FFI：wadPow 精度验证（期望值由 Python decimal 高精度计算）
    // wadPow(x, y) = e^(y * ln(x))，x 必须 > 0
    // 约束推导：wadExp 有效范围 (WADEXP_ZERO_CUTOFF, WADEXP_MAX_INPUT)
    //   需要 WADEXP_ZERO_CUTOFF < y * ln(x) < WADEXP_MAX_INPUT
    //   用动态约束：先 fuzz x，算出 ln(x)，再约束 y 的范围
    function testFuzzWadPowAgainstPython(int256 x, int256 y) public {
        vm.assume(x > 0);

        int256 lnX = wadLn(x);

        // y * lnX / 1e18 必须在 wadExp 有效范围内
        // safeExpMax 留安全边距 1e2：Solidity 整数截断与 Python 精确计算在边界处有偏差，
        // 上界方向结果极大，可能超出 int256，需要缩进避免 Python 端 to_bytes(32) 溢出
        // 下界方向结果趋近于 0，不会溢出，无需缩进
        int256 safeExpMax = WADEXP_MAX_INPUT - 1e2;
        int256 safeExpMin = WADEXP_ZERO_CUTOFF;

        if (lnX > 0) {
            // x > 1（实数），lnX > 0
            // 由 safeExpMin < y * lnX / 1e18 < safeExpMax 推导：
            //   y 的上界：y < safeExpMax * 1e18 / lnX
            //   y 的下界：y > safeExpMin * 1e18 / lnX
            int256 yMax = (safeExpMax * 1e18) / lnX;
            int256 yMin = (safeExpMin * 1e18) / lnX;
            y = bound(y, yMin, yMax);
        } else if (lnX < 0) {
            // 0 < x < 1（实数），lnX < 0，除以负数不等式反转
            // 由 safeExpMin < y * lnX / 1e18 < safeExpMax 推导：
            //   y 的上界：y < safeExpMin * 1e18 / lnX（负/负=正）
            //   y 的下界：y > safeExpMax * 1e18 / lnX（正/负=负）
            int256 yMax = (safeExpMin * 1e18) / lnX;
            int256 yMin = (safeExpMax * 1e18) / lnX;
            y = bound(y, yMin, yMax);
        } else {
            // lnX == 0 即 x == 1e18，1^y = 1 恒成立，无需调 Python
            assertEq(wadPow(x, y), 1e18);
            return;
        }

        int256 actual = wadPow(x, y);

        string[] memory args = new string[](5);
        args[0] = "python3";
        args[1] = "scripts/wad_exp_ln_reference.py";
        args[2] = "pow";
        args[3] = vm.toString(x);
        args[4] = vm.toString(y);
        // forge-lint: disable-next-line(unsafe-cheatcode)
        bytes memory ret = vm.ffi(args);
        int256 expected = abi.decode(ret, (int256));

        assertApproxEqRel(actual, expected, TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                unsafeDiv — 有符号整数除法（不检查除零）
    //////////////////////////////////////////////////////////////*/

    // 正向：6 / 2 = 3
    function testUnsafeDivBasic() public pure {
        assertEq(unsafeDiv(6, 2), 3);
    }

    // 正向：负数除法
    function testUnsafeDivNegative() public pure {
        assertEq(unsafeDiv(-6, 2), -3);
        assertEq(unsafeDiv(6, -2), -3);
        assertEq(unsafeDiv(-6, -2), 3);
    }

    // 正向：向零截断（不是向下取整）
    function testUnsafeDivTruncation() public pure {
        // 7 / 2 = 3（截断 0.5）
        assertEq(unsafeDiv(7, 2), 3);
        // -7 / 2 = -3（向零截断，不是 -4）
        assertEq(unsafeDiv(-7, 2), -3);
    }

    // 边界：除以 0 返回 0（sdiv 除零行为）
    function testUnsafeDivByZero() public pure {
        assertEq(unsafeDiv(1, 0), 0);
        assertEq(unsafeDiv(0, 0), 0);
        assertEq(unsafeDiv(-1, 0), 0);
    }

    // 边界：sdiv(-2^255, -1) = -2^255（EVM 硬编码特例）
    function testUnsafeDivMinByNegOne() public pure {
        assertEq(unsafeDiv(type(int256).min, -1), type(int256).min);
    }

    // 正向：这不是 wad 除法（不乘 1e18）
    function testUnsafeDivIsNotWadDiv() public pure {
        // unsafeDiv(1e18, 1e18) = 1（整数除法），不是 1e18
        assertEq(unsafeDiv(1e18, 1e18), 1);
    }

    // Fuzz：unsafeDiv(x, 1) == x
    function testFuzzUnsafeDivByOne(int256 x) public pure {
        assertEq(unsafeDiv(x, 1), x);
    }

    /*//////////////////////////////////////////////////////////////
    //                       跨函数集成测试
    //////////////////////////////////////////////////////////////*/

    // 集成：完整的时间转换 + wadExp 调用链
    // 模拟连续复利场景：A（本息和） = P × e^(r×t)
    // 本金 1000 wad，年利率 5%，365 天
    function testIntegrationContinuousCompounding() public pure {
        int256 principal = 1000e18; // 本金
        int256 rate = 0.05e18; // 5% 年利率

        // 时间：365 天 → wad 天数
        int256 timeDays = toDaysWadUnsafe(365 days);
        assertEq(timeDays, 365e18);

        // r × t（年利率 × 天数/365）= 0.05
        int256 rt = wadMul(rate, wadDiv(timeDays, 365e18));

        // e^(r×t) ≈ e^0.05 ≈ 1.05127...
        int256 expRt = wadExp(rt);
        assertApproxEqAbs(expRt, 1051271096376024039, TOLERANCE);

        // A = P × e^(r×t) ≈ 1051.271...
        int256 amount = wadMul(principal, expRt);
        assertEq(amount, 1051271096376024039000);
    }

    // 集成：wadPow(x, y) ≈ wadExp(wadMul(wadLn(x), y))
    // 验证 wadPow 不是黑盒——它的行为可以用 wadExp、wadLn、wadMul 三个基础函数完全复现，
    // 证明函数之间的数学一致性：x^y = e^(y × ln(x))
    // wadPow 内部用原生 * 和 / 1e18，wadMul 用 assembly mul 和 sdiv，编译结果一致，无误差
    function testIntegrationWadPowEquivalence() public pure {
        int256 x = 3e18;
        int256 y = 2.5e18;

        int256 fromPow = wadPow(x, y);
        int256 manual = wadExp(wadMul(wadLn(x), y));

        assertEq(fromPow, manual);
    }
}

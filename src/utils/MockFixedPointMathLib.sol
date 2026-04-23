// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// FixedPointMathLib 是 library，函数编译时内联到调用合约中。
// vm.expectRevert 只能捕获外部调用的 revert，无法捕获内联函数的 revert。
// 因此需要这个 Mock 合约将会 revert 的 internal 函数包装为 external 调用，使测试中的 revert 可被捕获。
contract MockFixedPointMathLib {
    using FixedPointMathLib for uint256;

    function callMulWadDown(uint256 x, uint256 y) external pure returns (uint256) {
        return x.mulWadDown(y);
    }

    function callMulWadUp(uint256 x, uint256 y) external pure returns (uint256) {
        return x.mulWadUp(y);
    }

    function callDivWadDown(uint256 x, uint256 y) external pure returns (uint256) {
        return x.divWadDown(y);
    }

    function callDivWadUp(uint256 x, uint256 y) external pure returns (uint256) {
        return x.divWadUp(y);
    }

    function callMulDivDown(uint256 x, uint256 y, uint256 d) external pure returns (uint256) {
        return FixedPointMathLib.mulDivDown(x, y, d);
    }

    function callMulDivUp(uint256 x, uint256 y, uint256 d) external pure returns (uint256) {
        return FixedPointMathLib.mulDivUp(x, y, d);
    }

    function callRpow(uint256 x, uint256 n, uint256 scalar) external pure returns (uint256) {
        return FixedPointMathLib.rpow(x, n, scalar);
    }
}

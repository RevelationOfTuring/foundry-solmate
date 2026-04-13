// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

// SafeCastLib 所有函数都是 internal pure，编译时内联到调用合约中。
// vm.expectRevert 只能捕获外部调用的 revert，无法捕获内联函数的 revert。
// 因此需要这个 Mock 合约将 internal 函数包装为 external 调用，使测试中的 revert 可被捕获。
contract MockSafeCastLib {
    using SafeCastLib for uint256;

    function safeCastTo248(uint256 x) external pure returns (uint248) {
        return x.safeCastTo248();
    }

    function safeCastTo240(uint256 x) external pure returns (uint240) {
        return x.safeCastTo240();
    }

    function safeCastTo232(uint256 x) external pure returns (uint232) {
        return x.safeCastTo232();
    }

    function safeCastTo224(uint256 x) external pure returns (uint224) {
        return x.safeCastTo224();
    }

    function safeCastTo216(uint256 x) external pure returns (uint216) {
        return x.safeCastTo216();
    }

    function safeCastTo208(uint256 x) external pure returns (uint208) {
        return x.safeCastTo208();
    }

    function safeCastTo200(uint256 x) external pure returns (uint200) {
        return x.safeCastTo200();
    }

    function safeCastTo192(uint256 x) external pure returns (uint192) {
        return x.safeCastTo192();
    }

    function safeCastTo184(uint256 x) external pure returns (uint184) {
        return x.safeCastTo184();
    }

    function safeCastTo176(uint256 x) external pure returns (uint176) {
        return x.safeCastTo176();
    }

    function safeCastTo168(uint256 x) external pure returns (uint168) {
        return x.safeCastTo168();
    }

    function safeCastTo160(uint256 x) external pure returns (uint160) {
        return x.safeCastTo160();
    }

    function safeCastTo152(uint256 x) external pure returns (uint152) {
        return x.safeCastTo152();
    }

    function safeCastTo144(uint256 x) external pure returns (uint144) {
        return x.safeCastTo144();
    }

    function safeCastTo136(uint256 x) external pure returns (uint136) {
        return x.safeCastTo136();
    }

    function safeCastTo128(uint256 x) external pure returns (uint128) {
        return x.safeCastTo128();
    }

    function safeCastTo120(uint256 x) external pure returns (uint120) {
        return x.safeCastTo120();
    }

    function safeCastTo112(uint256 x) external pure returns (uint112) {
        return x.safeCastTo112();
    }

    function safeCastTo104(uint256 x) external pure returns (uint104) {
        return x.safeCastTo104();
    }

    function safeCastTo96(uint256 x) external pure returns (uint96) {
        return x.safeCastTo96();
    }

    function safeCastTo88(uint256 x) external pure returns (uint88) {
        return x.safeCastTo88();
    }

    function safeCastTo80(uint256 x) external pure returns (uint80) {
        return x.safeCastTo80();
    }

    function safeCastTo72(uint256 x) external pure returns (uint72) {
        return x.safeCastTo72();
    }

    function safeCastTo64(uint256 x) external pure returns (uint64) {
        return x.safeCastTo64();
    }

    function safeCastTo56(uint256 x) external pure returns (uint56) {
        return x.safeCastTo56();
    }

    function safeCastTo48(uint256 x) external pure returns (uint48) {
        return x.safeCastTo48();
    }

    function safeCastTo40(uint256 x) external pure returns (uint40) {
        return x.safeCastTo40();
    }

    function safeCastTo32(uint256 x) external pure returns (uint32) {
        return x.safeCastTo32();
    }

    function safeCastTo24(uint256 x) external pure returns (uint24) {
        return x.safeCastTo24();
    }

    function safeCastTo16(uint256 x) external pure returns (uint16) {
        return x.safeCastTo16();
    }

    function safeCastTo8(uint256 x) external pure returns (uint8) {
        return x.safeCastTo8();
    }
}

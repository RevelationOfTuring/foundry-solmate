// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockSafeCastLib} from "src/utils/MockSafeCastLib.sol";

contract SafeCastLibTest is Test {
    MockSafeCastLib mock = new MockSafeCastLib();

    /*//////////////////////////////////////////////////////////////
                          safeCastTo248
    //////////////////////////////////////////////////////////////*/

    // 正向：0 → 成功
    function testSafeCastTo248Zero() public view {
        assertEq(mock.safeCastTo248(0), 0);
    }

    // 正向：最大值 → 成功
    function testSafeCastTo248Max() public view {
        uint256 maxVal = type(uint248).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo248(maxVal), uint248(maxVal));
    }

    // 反向：最大值 + 1 → revert
    function testSafeCastTo248Overflow() public {
        vm.expectRevert();
        mock.safeCastTo248(uint256(type(uint248).max) + 1);
    }

    // 反向：uint256 最大值 → revert
    function testSafeCastTo248MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo248(type(uint256).max);
    }

    // Fuzz：范围内任意值 → 成功
    function testFuzzSafeCastTo248(uint256 x) public view {
        x = bound(x, 0, type(uint248).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo248(x), uint248(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo240
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo240Zero() public view {
        assertEq(mock.safeCastTo240(0), 0);
    }

    function testSafeCastTo240Max() public view {
        uint256 maxVal = type(uint240).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo240(maxVal), uint240(maxVal));
    }

    function testSafeCastTo240Overflow() public {
        vm.expectRevert();
        mock.safeCastTo240(uint256(type(uint240).max) + 1);
    }

    function testSafeCastTo240MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo240(type(uint256).max);
    }

    function testFuzzSafeCastTo240(uint256 x) public view {
        x = bound(x, 0, type(uint240).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo240(x), uint240(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo232
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo232Zero() public view {
        assertEq(mock.safeCastTo232(0), 0);
    }

    function testSafeCastTo232Max() public view {
        uint256 maxVal = type(uint232).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo232(maxVal), uint232(maxVal));
    }

    function testSafeCastTo232Overflow() public {
        vm.expectRevert();
        mock.safeCastTo232(uint256(type(uint232).max) + 1);
    }

    function testSafeCastTo232MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo232(type(uint256).max);
    }

    function testFuzzSafeCastTo232(uint256 x) public view {
        x = bound(x, 0, type(uint232).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo232(x), uint232(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo224
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo224Zero() public view {
        assertEq(mock.safeCastTo224(0), 0);
    }

    function testSafeCastTo224Max() public view {
        uint256 maxVal = type(uint224).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo224(maxVal), uint224(maxVal));
    }

    function testSafeCastTo224Overflow() public {
        vm.expectRevert();
        mock.safeCastTo224(uint256(type(uint224).max) + 1);
    }

    function testSafeCastTo224MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo224(type(uint256).max);
    }

    function testFuzzSafeCastTo224(uint256 x) public view {
        x = bound(x, 0, type(uint224).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo224(x), uint224(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo216
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo216Zero() public view {
        assertEq(mock.safeCastTo216(0), 0);
    }

    function testSafeCastTo216Max() public view {
        uint256 maxVal = type(uint216).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo216(maxVal), uint216(maxVal));
    }

    function testSafeCastTo216Overflow() public {
        vm.expectRevert();
        mock.safeCastTo216(uint256(type(uint216).max) + 1);
    }

    function testSafeCastTo216MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo216(type(uint256).max);
    }

    function testFuzzSafeCastTo216(uint256 x) public view {
        x = bound(x, 0, type(uint216).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo216(x), uint216(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo208
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo208Zero() public view {
        assertEq(mock.safeCastTo208(0), 0);
    }

    function testSafeCastTo208Max() public view {
        uint256 maxVal = type(uint208).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo208(maxVal), uint208(maxVal));
    }

    function testSafeCastTo208Overflow() public {
        vm.expectRevert();
        mock.safeCastTo208(uint256(type(uint208).max) + 1);
    }

    function testSafeCastTo208MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo208(type(uint256).max);
    }

    function testFuzzSafeCastTo208(uint256 x) public view {
        x = bound(x, 0, type(uint208).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo208(x), uint208(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo200
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo200Zero() public view {
        assertEq(mock.safeCastTo200(0), 0);
    }

    function testSafeCastTo200Max() public view {
        uint256 maxVal = type(uint200).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo200(maxVal), uint200(maxVal));
    }

    function testSafeCastTo200Overflow() public {
        vm.expectRevert();
        mock.safeCastTo200(uint256(type(uint200).max) + 1);
    }

    function testSafeCastTo200MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo200(type(uint256).max);
    }

    function testFuzzSafeCastTo200(uint256 x) public view {
        x = bound(x, 0, type(uint200).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo200(x), uint200(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo192
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo192Zero() public view {
        assertEq(mock.safeCastTo192(0), 0);
    }

    function testSafeCastTo192Max() public view {
        uint256 maxVal = type(uint192).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo192(maxVal), uint192(maxVal));
    }

    function testSafeCastTo192Overflow() public {
        vm.expectRevert();
        mock.safeCastTo192(uint256(type(uint192).max) + 1);
    }

    function testSafeCastTo192MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo192(type(uint256).max);
    }

    function testFuzzSafeCastTo192(uint256 x) public view {
        x = bound(x, 0, type(uint192).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo192(x), uint192(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo184
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo184Zero() public view {
        assertEq(mock.safeCastTo184(0), 0);
    }

    function testSafeCastTo184Max() public view {
        uint256 maxVal = type(uint184).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo184(maxVal), uint184(maxVal));
    }

    function testSafeCastTo184Overflow() public {
        vm.expectRevert();
        mock.safeCastTo184(uint256(type(uint184).max) + 1);
    }

    function testSafeCastTo184MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo184(type(uint256).max);
    }

    function testFuzzSafeCastTo184(uint256 x) public view {
        x = bound(x, 0, type(uint184).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo184(x), uint184(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo176
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo176Zero() public view {
        assertEq(mock.safeCastTo176(0), 0);
    }

    function testSafeCastTo176Max() public view {
        uint256 maxVal = type(uint176).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo176(maxVal), uint176(maxVal));
    }

    function testSafeCastTo176Overflow() public {
        vm.expectRevert();
        mock.safeCastTo176(uint256(type(uint176).max) + 1);
    }

    function testSafeCastTo176MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo176(type(uint256).max);
    }

    function testFuzzSafeCastTo176(uint256 x) public view {
        x = bound(x, 0, type(uint176).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo176(x), uint176(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo168
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo168Zero() public view {
        assertEq(mock.safeCastTo168(0), 0);
    }

    function testSafeCastTo168Max() public view {
        uint256 maxVal = type(uint168).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo168(maxVal), uint168(maxVal));
    }

    function testSafeCastTo168Overflow() public {
        vm.expectRevert();
        mock.safeCastTo168(uint256(type(uint168).max) + 1);
    }

    function testSafeCastTo168MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo168(type(uint256).max);
    }

    function testFuzzSafeCastTo168(uint256 x) public view {
        x = bound(x, 0, type(uint168).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo168(x), uint168(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo160
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo160Zero() public view {
        assertEq(mock.safeCastTo160(0), 0);
    }

    function testSafeCastTo160Max() public view {
        uint256 maxVal = type(uint160).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo160(maxVal), uint160(maxVal));
    }

    function testSafeCastTo160Overflow() public {
        vm.expectRevert();
        mock.safeCastTo160(uint256(type(uint160).max) + 1);
    }

    function testSafeCastTo160MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo160(type(uint256).max);
    }

    function testFuzzSafeCastTo160(uint256 x) public view {
        x = bound(x, 0, type(uint160).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo160(x), uint160(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo152
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo152Zero() public view {
        assertEq(mock.safeCastTo152(0), 0);
    }

    function testSafeCastTo152Max() public view {
        uint256 maxVal = type(uint152).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo152(maxVal), uint152(maxVal));
    }

    function testSafeCastTo152Overflow() public {
        vm.expectRevert();
        mock.safeCastTo152(uint256(type(uint152).max) + 1);
    }

    function testSafeCastTo152MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo152(type(uint256).max);
    }

    function testFuzzSafeCastTo152(uint256 x) public view {
        x = bound(x, 0, type(uint152).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo152(x), uint152(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo144
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo144Zero() public view {
        assertEq(mock.safeCastTo144(0), 0);
    }

    function testSafeCastTo144Max() public view {
        uint256 maxVal = type(uint144).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo144(maxVal), uint144(maxVal));
    }

    function testSafeCastTo144Overflow() public {
        vm.expectRevert();
        mock.safeCastTo144(uint256(type(uint144).max) + 1);
    }

    function testSafeCastTo144MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo144(type(uint256).max);
    }

    function testFuzzSafeCastTo144(uint256 x) public view {
        x = bound(x, 0, type(uint144).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo144(x), uint144(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo136
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo136Zero() public view {
        assertEq(mock.safeCastTo136(0), 0);
    }

    function testSafeCastTo136Max() public view {
        uint256 maxVal = type(uint136).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo136(maxVal), uint136(maxVal));
    }

    function testSafeCastTo136Overflow() public {
        vm.expectRevert();
        mock.safeCastTo136(uint256(type(uint136).max) + 1);
    }

    function testSafeCastTo136MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo136(type(uint256).max);
    }

    function testFuzzSafeCastTo136(uint256 x) public view {
        x = bound(x, 0, type(uint136).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo136(x), uint136(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo128
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo128Zero() public view {
        assertEq(mock.safeCastTo128(0), 0);
    }

    function testSafeCastTo128Max() public view {
        uint256 maxVal = type(uint128).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo128(maxVal), uint128(maxVal));
    }

    function testSafeCastTo128Overflow() public {
        vm.expectRevert();
        mock.safeCastTo128(uint256(type(uint128).max) + 1);
    }

    function testSafeCastTo128MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo128(type(uint256).max);
    }

    function testFuzzSafeCastTo128(uint256 x) public view {
        x = bound(x, 0, type(uint128).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo128(x), uint128(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo120
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo120Zero() public view {
        assertEq(mock.safeCastTo120(0), 0);
    }

    function testSafeCastTo120Max() public view {
        uint256 maxVal = type(uint120).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo120(maxVal), uint120(maxVal));
    }

    function testSafeCastTo120Overflow() public {
        vm.expectRevert();
        mock.safeCastTo120(uint256(type(uint120).max) + 1);
    }

    function testSafeCastTo120MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo120(type(uint256).max);
    }

    function testFuzzSafeCastTo120(uint256 x) public view {
        x = bound(x, 0, type(uint120).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo120(x), uint120(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo112
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo112Zero() public view {
        assertEq(mock.safeCastTo112(0), 0);
    }

    function testSafeCastTo112Max() public view {
        uint256 maxVal = type(uint112).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo112(maxVal), uint112(maxVal));
    }

    function testSafeCastTo112Overflow() public {
        vm.expectRevert();
        mock.safeCastTo112(uint256(type(uint112).max) + 1);
    }

    function testSafeCastTo112MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo112(type(uint256).max);
    }

    function testFuzzSafeCastTo112(uint256 x) public view {
        x = bound(x, 0, type(uint112).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo112(x), uint112(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo104
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo104Zero() public view {
        assertEq(mock.safeCastTo104(0), 0);
    }

    function testSafeCastTo104Max() public view {
        uint256 maxVal = type(uint104).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo104(maxVal), uint104(maxVal));
    }

    function testSafeCastTo104Overflow() public {
        vm.expectRevert();
        mock.safeCastTo104(uint256(type(uint104).max) + 1);
    }

    function testSafeCastTo104MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo104(type(uint256).max);
    }

    function testFuzzSafeCastTo104(uint256 x) public view {
        x = bound(x, 0, type(uint104).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo104(x), uint104(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo96
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo96Zero() public view {
        assertEq(mock.safeCastTo96(0), 0);
    }

    function testSafeCastTo96Max() public view {
        uint256 maxVal = type(uint96).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo96(maxVal), uint96(maxVal));
    }

    function testSafeCastTo96Overflow() public {
        vm.expectRevert();
        mock.safeCastTo96(uint256(type(uint96).max) + 1);
    }

    function testSafeCastTo96MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo96(type(uint256).max);
    }

    function testFuzzSafeCastTo96(uint256 x) public view {
        x = bound(x, 0, type(uint96).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo96(x), uint96(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo88
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo88Zero() public view {
        assertEq(mock.safeCastTo88(0), 0);
    }

    function testSafeCastTo88Max() public view {
        uint256 maxVal = type(uint88).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo88(maxVal), uint88(maxVal));
    }

    function testSafeCastTo88Overflow() public {
        vm.expectRevert();
        mock.safeCastTo88(uint256(type(uint88).max) + 1);
    }

    function testSafeCastTo88MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo88(type(uint256).max);
    }

    function testFuzzSafeCastTo88(uint256 x) public view {
        x = bound(x, 0, type(uint88).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo88(x), uint88(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo80
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo80Zero() public view {
        assertEq(mock.safeCastTo80(0), 0);
    }

    function testSafeCastTo80Max() public view {
        uint256 maxVal = type(uint80).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo80(maxVal), uint80(maxVal));
    }

    function testSafeCastTo80Overflow() public {
        vm.expectRevert();
        mock.safeCastTo80(uint256(type(uint80).max) + 1);
    }

    function testSafeCastTo80MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo80(type(uint256).max);
    }

    function testFuzzSafeCastTo80(uint256 x) public view {
        x = bound(x, 0, type(uint80).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo80(x), uint80(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo72
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo72Zero() public view {
        assertEq(mock.safeCastTo72(0), 0);
    }

    function testSafeCastTo72Max() public view {
        uint256 maxVal = type(uint72).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo72(maxVal), uint72(maxVal));
    }

    function testSafeCastTo72Overflow() public {
        vm.expectRevert();
        mock.safeCastTo72(uint256(type(uint72).max) + 1);
    }

    function testSafeCastTo72MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo72(type(uint256).max);
    }

    function testFuzzSafeCastTo72(uint256 x) public view {
        x = bound(x, 0, type(uint72).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo72(x), uint72(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo64
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo64Zero() public view {
        assertEq(mock.safeCastTo64(0), 0);
    }

    function testSafeCastTo64Max() public view {
        uint256 maxVal = type(uint64).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo64(maxVal), uint64(maxVal));
    }

    function testSafeCastTo64Overflow() public {
        vm.expectRevert();
        mock.safeCastTo64(uint256(type(uint64).max) + 1);
    }

    function testSafeCastTo64MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo64(type(uint256).max);
    }

    function testFuzzSafeCastTo64(uint256 x) public view {
        x = bound(x, 0, type(uint64).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo64(x), uint64(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo56
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo56Zero() public view {
        assertEq(mock.safeCastTo56(0), 0);
    }

    function testSafeCastTo56Max() public view {
        uint256 maxVal = type(uint56).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo56(maxVal), uint56(maxVal));
    }

    function testSafeCastTo56Overflow() public {
        vm.expectRevert();
        mock.safeCastTo56(uint256(type(uint56).max) + 1);
    }

    function testSafeCastTo56MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo56(type(uint256).max);
    }

    function testFuzzSafeCastTo56(uint256 x) public view {
        x = bound(x, 0, type(uint56).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo56(x), uint56(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo48
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo48Zero() public view {
        assertEq(mock.safeCastTo48(0), 0);
    }

    function testSafeCastTo48Max() public view {
        uint256 maxVal = type(uint48).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo48(maxVal), uint48(maxVal));
    }

    function testSafeCastTo48Overflow() public {
        vm.expectRevert();
        mock.safeCastTo48(uint256(type(uint48).max) + 1);
    }

    function testSafeCastTo48MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo48(type(uint256).max);
    }

    function testFuzzSafeCastTo48(uint256 x) public view {
        x = bound(x, 0, type(uint48).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo48(x), uint48(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo40
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo40Zero() public view {
        assertEq(mock.safeCastTo40(0), 0);
    }

    function testSafeCastTo40Max() public view {
        uint256 maxVal = type(uint40).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo40(maxVal), uint40(maxVal));
    }

    function testSafeCastTo40Overflow() public {
        vm.expectRevert();
        mock.safeCastTo40(uint256(type(uint40).max) + 1);
    }

    function testSafeCastTo40MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo40(type(uint256).max);
    }

    function testFuzzSafeCastTo40(uint256 x) public view {
        x = bound(x, 0, type(uint40).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo40(x), uint40(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo32
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo32Zero() public view {
        assertEq(mock.safeCastTo32(0), 0);
    }

    function testSafeCastTo32Max() public view {
        uint256 maxVal = type(uint32).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo32(maxVal), uint32(maxVal));
    }

    function testSafeCastTo32Overflow() public {
        vm.expectRevert();
        mock.safeCastTo32(uint256(type(uint32).max) + 1);
    }

    function testSafeCastTo32MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo32(type(uint256).max);
    }

    function testFuzzSafeCastTo32(uint256 x) public view {
        x = bound(x, 0, type(uint32).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo32(x), uint32(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo24
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo24Zero() public view {
        assertEq(mock.safeCastTo24(0), 0);
    }

    function testSafeCastTo24Max() public view {
        uint256 maxVal = type(uint24).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo24(maxVal), uint24(maxVal));
    }

    function testSafeCastTo24Overflow() public {
        vm.expectRevert();
        mock.safeCastTo24(uint256(type(uint24).max) + 1);
    }

    function testSafeCastTo24MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo24(type(uint256).max);
    }

    function testFuzzSafeCastTo24(uint256 x) public view {
        x = bound(x, 0, type(uint24).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo24(x), uint24(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo16
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo16Zero() public view {
        assertEq(mock.safeCastTo16(0), 0);
    }

    function testSafeCastTo16Max() public view {
        uint256 maxVal = type(uint16).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo16(maxVal), uint16(maxVal));
    }

    function testSafeCastTo16Overflow() public {
        vm.expectRevert();
        mock.safeCastTo16(uint256(type(uint16).max) + 1);
    }

    function testSafeCastTo16MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo16(type(uint256).max);
    }

    function testFuzzSafeCastTo16(uint256 x) public view {
        x = bound(x, 0, type(uint16).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo16(x), uint16(x));
    }

    /*//////////////////////////////////////////////////////////////
                          safeCastTo8
    //////////////////////////////////////////////////////////////*/

    function testSafeCastTo8Zero() public view {
        assertEq(mock.safeCastTo8(0), 0);
    }

    function testSafeCastTo8Max() public view {
        uint256 maxVal = type(uint8).max;
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo8(maxVal), uint8(maxVal));
    }

    function testSafeCastTo8Overflow() public {
        vm.expectRevert();
        mock.safeCastTo8(uint256(type(uint8).max) + 1);
    }

    function testSafeCastTo8MaxUint256() public {
        vm.expectRevert();
        mock.safeCastTo8(type(uint256).max);
    }

    function testFuzzSafeCastTo8(uint256 x) public view {
        x = bound(x, 0, type(uint8).max);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(mock.safeCastTo8(x), uint8(x));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

contract Bytes32AddressLibTest is Test {
    using Bytes32AddressLib for bytes32;
    using Bytes32AddressLib for address;

    /*//////////////////////////////////////////////////////////////
                        FROM LAST 20 BYTES
    //////////////////////////////////////////////////////////////*/

    // 正向：从 bytes32 低 20 字节提取 address
    function testFromLast20Bytes() public pure {
        bytes32 input = 0x000000000000000000000000d8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        address expected = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        assertEq(input.fromLast20Bytes(), expected);
    }

    // 正向：高 12 字节非零时被正确丢弃
    function testFromLast20BytesDiscardsHighBytes() public pure {
        bytes32 input = 0xfeedfacecafebeeffeedfacecafebeeffeedfacecafebeeffeedfacecafebeef;
        address expected = 0xCAfeBeefFeedfAceCAFeBEEffEEDfaCecafEBeeF;
        assertEq(input.fromLast20Bytes(), expected);
    }

    // 边界：全零 bytes32 → address(0)
    function testFromLast20BytesZero() public pure {
        assertEq(bytes32(0).fromLast20Bytes(), address(0));
    }

    // 边界：全 ff → 地址为 0xffffffffffffffffffffffffffffffffffffffff
    function testFromLast20BytesAllOnes() public pure {
        bytes32 input = bytes32(type(uint256).max);
        assertEq(input.fromLast20Bytes(), address(type(uint160).max));
    }

    /*//////////////////////////////////////////////////////////////
                        FILL LAST 12 BYTES
    //////////////////////////////////////////////////////////////*/

    // 正向：address 左对齐填入 bytes32，低 12 字节补零
    function testFillLast12Bytes() public pure {
        address input = 0xfEEDFaCEcaFeBEEFfEEDFACecaFEBeeFfeEdfAce;
        bytes32 expected = 0xfeedfacecafebeeffeedfacecafebeeffeedface000000000000000000000000;
        assertEq(input.fillLast12Bytes(), expected);
    }

    // 边界：address(0) → bytes32(0)
    function testFillLast12BytesZero() public pure {
        assertEq(address(0).fillLast12Bytes(), bytes32(0));
    }

    // 边界：全 ff 地址
    function testFillLast12BytesAllOnes() public pure {
        address input = address(type(uint160).max);
        bytes32 expected = 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000;
        assertEq(input.fillLast12Bytes(), expected);
    }

    // 正向：低 12 字节确实为零
    function testFillLast12BytesLowBytesAreZero() public pure {
        address input = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        bytes32 result = input.fillLast12Bytes();

        // 将结果转为 uint256，低 96 位（12 字节）应全为零
        uint256 low96 = uint256(result) & type(uint96).max;
        assertEq(low96, 0);
    }

    // 正向：高 20 字节保留了正确的地址数据
    function testFillLast12BytesHighBytesPreserved() public pure {
        address input = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        bytes32 result = input.fillLast12Bytes();

        // 高 20 字节 = result >> 96
        address recovered = address(uint160(uint256(result) >> 96));
        assertEq(recovered, input);
    }

    /*//////////////////////////////////////////////////////////////
                     NON-INVERSE RELATIONSHIP
    //////////////////////////////////////////////////////////////*/

    // 验证两个函数不是互逆操作：fillLast12Bytes → fromLast20Bytes ≠ 原始 address
    function testFillThenFromIsNotInverse() public pure {
        address original = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

        bytes32 filled = original.fillLast12Bytes();
        address roundTrip = filled.fromLast20Bytes();

        assertTrue(roundTrip != original);
    }

    // 验证两个函数不是互逆操作：fromLast20Bytes → fillLast12Bytes ≠ 原始 bytes32
    function testFromThenFillIsNotInverse() public pure {
        bytes32 original = 0x000000000000000000000000d8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

        address extracted = original.fromLast20Bytes();
        bytes32 roundTrip = extracted.fillLast12Bytes();

        assertTrue(roundTrip != original);
    }
}

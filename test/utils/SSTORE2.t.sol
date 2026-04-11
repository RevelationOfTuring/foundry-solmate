// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test, stdError} from "forge-std/Test.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";
import {MockSSTORE2} from "src/utils/MockSSTORE2.sol";

contract SSTORE2Test is Test {
    MockSSTORE2 mock = new MockSSTORE2();

    /*//////////////////////////////////////////////////////////////
                          WRITE — HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    // 正向：写入数据后返回非零地址
    function testWriteReturnsNonZeroPointer() public {
        bytes memory data = hex"deadbeef";
        address pointer = SSTORE2.write(data);

        assertTrue(pointer != address(0));
    }

    // 正向：写入后 pointer 合约的字节码 = STOP(0x00) ++ data
    function testWriteStoresBytecodeCorrectly() public {
        bytes memory data = hex"deadbeef";
        address pointer = SSTORE2.write(data);

        // pointer 合约的字节码长度 = 1(STOP) + data.length
        assertEq(pointer.code.length, data.length + 1);
        // 第一个字节是 STOP(0x00)
        assertEq(pointer.code[0], bytes1(0x00));
    }

    // 正向：写入空 data，部署只有 1 字节 STOP 的合约
    function testWriteEmptyData() public {
        bytes memory data = "";
        address pointer = SSTORE2.write(data);

        assertEq(pointer.code.length, 1); // 只有 STOP
        assertEq(pointer.code[0], bytes1(0x00));
        assertEq(SSTORE2.read(pointer).length, 0);
    }

    // 正向：写入单个字节
    function testWriteSingleByte() public {
        bytes memory data = hex"ff";
        address pointer = SSTORE2.write(data);

        assertEq(pointer.code.length, 2); // 1(STOP) + 1
        assertEq(SSTORE2.read(pointer), data);
    }

    // 正向：写入大段数据（1024 字节）
    function testWriteLargeData() public {
        bytes memory data = new bytes(1024);
        for (uint256 i = 0; i < 1024; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data[i] = bytes1(uint8(i % 256));
        }
        address pointer = SSTORE2.write(data);

        assertEq(SSTORE2.read(pointer), data);
    }

    // 正向：验证临界值 24,575 字节可以正常写入和读取
    // EIP-170 合约大小上限 = 24,576 字节，减去 1 字节 STOP → 数据上限 = 24,575 字节
    // 注：Foundry 测试环境默认不强制 EIP-170 合约大小限制（节点层面的限制），
    // 因此无法在测试中直接触发超限 revert。这里仅验证临界值可以正常写入和读取
    function testWriteMaxSizeData() public {
        bytes memory data = new bytes(24575);
        data[0] = 0xAA;
        data[24574] = 0xBB;

        address pointer = SSTORE2.write(data);
        bytes memory result = SSTORE2.read(pointer);

        assertEq(result.length, 24575);
        assertEq(result[0], bytes1(0xAA));
        assertEq(result[24574], bytes1(0xBB));
    }

    /*//////////////////////////////////////////////////////////////
                          WRITE — REVERT CASES
    //////////////////////////////////////////////////////////////*/

    // 反向：nonce 溢出导致 CREATE 失败 → revert "DEPLOYMENT_FAILED"
    // EIP-2681：账户 nonce 上限为 2^64 - 1，达到上限时 CREATE 返回 address(0)
    // 注：通过 mock 合约外部调用，vm.expectRevert 才能捕获 library 内部的 require revert
    function testRevertWriteNonceOverflow() public {
        // 将 mock 合约的 nonce 设为 uint64 最大值
        vm.setNonce(address(mock), type(uint64).max);

        bytes memory data = hex"deadbeef";
        vm.expectRevert("DEPLOYMENT_FAILED");
        mock.write(data);
    }

    /*//////////////////////////////////////////////////////////////
                        READ（全量）— HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    // 正向：写入后读取，数据一致
    function testReadFullData() public {
        bytes memory data = hex"0102030405060708";
        address pointer = SSTORE2.write(data);

        bytes memory result = SSTORE2.read(pointer);
        assertEq(result, data);
    }

    // 正向：多次读取同一 pointer，结果一致（幂等性）
    function testReadIdempotent() public {
        bytes memory data = hex"cafebabe";
        address pointer = SSTORE2.write(data);

        assertEq(SSTORE2.read(pointer), SSTORE2.read(pointer));
    }

    // 正向：不同数据写入不同 pointer，读取各自正确
    function testReadDifferentPointers() public {
        bytes memory data1 = hex"aabb";
        bytes memory data2 = hex"ccdd";

        address pointer1 = SSTORE2.write(data1);
        address pointer2 = SSTORE2.write(data2);

        assertTrue(pointer1 != pointer2);
        assertEq(SSTORE2.read(pointer1), data1);
        assertEq(SSTORE2.read(pointer2), data2);
    }

    /*//////////////////////////////////////////////////////////////
                      READ（start）— 切片读取
    //////////////////////////////////////////////////////////////*/

    // 正向：从 start 开始读取到末尾
    function testReadWithStart() public {
        bytes memory data = hex"0102030405";
        address pointer = SSTORE2.write(data);

        // 从 start=2 开始读取 → 跳过 0x01, 0x02 → 返回 0x030405
        bytes memory result = SSTORE2.read(pointer, 2);
        assertEq(result, hex"030405");
    }

    // 正向：start=0 等价于全量读取
    function testReadWithStartZero() public {
        bytes memory data = hex"aabbccdd";
        address pointer = SSTORE2.write(data);

        assertEq(SSTORE2.read(pointer, 0), SSTORE2.read(pointer));
    }

    // 正向：start = data.length → 返回空 bytes
    function testReadWithStartAtEnd() public {
        bytes memory data = hex"aabb";
        address pointer = SSTORE2.write(data);

        bytes memory result = SSTORE2.read(pointer, data.length);
        assertEq(result.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    READ（start, end）— 范围切片读取
    //////////////////////////////////////////////////////////////*/

    // 正向：读取 [start, end) 范围
    function testReadWithStartAndEnd() public {
        bytes memory data = hex"0102030405";
        address pointer = SSTORE2.write(data);

        // 读取 [1, 4) → 0x020304
        bytes memory result = SSTORE2.read(pointer, 1, 4);
        assertEq(result, hex"020304");
    }

    // 正向：start=0, end=data.length 等价于全量读取
    function testReadWithFullRange() public {
        bytes memory data = hex"aabbccdd";
        address pointer = SSTORE2.write(data);

        assertEq(SSTORE2.read(pointer, 0, data.length), SSTORE2.read(pointer));
    }

    // 正向：start == end → 返回空 bytes
    function testReadWithStartEqualsEnd() public {
        bytes memory data = hex"aabbccdd";
        address pointer = SSTORE2.write(data);

        uint256 mid = data.length / 2;
        bytes memory result = SSTORE2.read(pointer, mid, mid);
        assertEq(result.length, 0);
    }

    // 正向：读取单个字节 [i, i+1)
    function testReadSingleByteSlice() public {
        bytes memory data = hex"0102030405";
        address pointer = SSTORE2.write(data);

        // 读取第 3 个字节（index=2）
        bytes memory result = SSTORE2.read(pointer, 2, 3);
        assertEq(result, hex"03");
    }

    /*//////////////////////////////////////////////////////////////
                          READ — REVERT CASES
    //////////////////////////////////////////////////////////////*/

    // 反向：read(pointer, start, end) end 超出范围 → revert "OUT_OF_BOUNDS"
    // 注：通过 mock 合约外部调用，vm.expectRevert 才能捕获 library 内部的 require revert
    function testRevertReadOutOfBounds() public {
        bytes memory data = hex"aabb";
        address pointer = SSTORE2.write(data);

        // data.length = 2，end = 3 超出范围
        vm.expectRevert("OUT_OF_BOUNDS");
        mock.read(pointer, 0, 3);
    }

    // 反向：read(pointer, start, end) start 和 end 都超出范围 → revert "OUT_OF_BOUNDS"
    function testRevertReadBothOutOfBounds() public {
        bytes memory data = hex"aabb";
        address pointer = SSTORE2.write(data);

        vm.expectRevert("OUT_OF_BOUNDS");
        mock.read(pointer, 5, 10);
    }

    // 反向：read(pointer, start, end) start > end → arithmetic underflow panic
    // 原因：end - start 下溢（Solidity 0.8+ checked arithmetic），panic code 0x11
    function testRevertReadStartGreaterThanEnd() public {
        bytes memory data = hex"aabbccdd";
        address pointer = SSTORE2.write(data);

        vm.expectRevert(stdError.arithmeticError);
        mock.read(pointer, 3, 1);
    }

    /*//////////////////////////////////////////////////////////////
                          POINTER SAFETY
    //////////////////////////////////////////////////////////////*/

    // 正向：pointer 合约的第一个字节是 STOP，call 不会执行任何逻辑
    function testPointerCannotBeCalledWithEffect() public {
        bytes memory data = hex"deadbeef";
        address pointer = SSTORE2.write(data);

        // call pointer → 遇到 STOP 立即停止，返回 success=true（STOP 不是 revert）
        // STOP 不会产生任何返回数据，所以 returnData 为空
        (bool success, bytes memory returnData) = pointer.call("");
        assertTrue(success);
        assertEq(returnData.length, 0);

        // 数据不会被改变（因为 STOP 之后的数据不会被执行）
        assertEq(SSTORE2.read(pointer), data);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // Fuzz：任意数据写入后读取一致
    function testFuzzWriteAndRead(bytes memory data) public {
        // 限制数据长度，避免超出合约大小上限导致部署失败
        vm.assume(data.length > 0 && data.length <= 24575);

        address pointer = SSTORE2.write(data);
        assertEq(SSTORE2.read(pointer), data);
    }

    // Fuzz：任意 start 切片读取
    function testFuzzReadWithStart(bytes memory data, uint256 start) public {
        vm.assume(data.length > 0 && data.length <= 24575);
        start = bound(start, 0, data.length);

        address pointer = SSTORE2.write(data);
        bytes memory result = SSTORE2.read(pointer, start);

        // 验证长度
        assertEq(result.length, data.length - start);

        // 验证内容：逐字节对比
        for (uint256 i = 0; i < result.length; i++) {
            assertEq(result[i], data[start + i]);
        }
    }

    // Fuzz：任意 [start, end) 范围切片读取
    function testFuzzReadWithStartAndEnd(bytes memory data, uint256 start, uint256 end) public {
        vm.assume(data.length > 0 && data.length <= 24575);
        end = bound(end, 0, data.length);
        start = bound(start, 0, end);

        address pointer = SSTORE2.write(data);
        bytes memory result = SSTORE2.read(pointer, start, end);

        // 验证长度
        assertEq(result.length, end - start);

        // 验证内容：逐字节对比
        for (uint256 i = 0; i < result.length; i++) {
            assertEq(result[i], data[start + i]);
        }
    }
}

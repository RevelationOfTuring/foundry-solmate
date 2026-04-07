// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SSTORE2} from "solmate/utils/SSTORE2.sol";

// SSTORE2 library 的所有函数都是 internal，编译时内联到调用合约中。
// vm.expectRevert 只能捕获外部调用的 revert，无法捕获内联函数的 revert。
// 因此需要这个 Mock 合约将 internal 函数包装为 external 调用，使测试中的 revert 可被捕获。
contract MockSSTORE2 {
    function write(bytes memory data) external returns (address) {
        return SSTORE2.write(data);
    }

    function read(address pointer, uint256 start, uint256 end) external view returns (bytes memory) {
        return SSTORE2.read(pointer, start, end);
    }
}

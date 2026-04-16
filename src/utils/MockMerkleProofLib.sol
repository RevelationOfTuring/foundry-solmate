// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";

// MerkleProofLib.verify 的 proof 参数是 calldata 类型，
// 测试中构建的数组是 memory 类型，memory 无法隐式转换为 calldata。
// 通过这个 external 函数做中转：调用时 memory 数组经 ABI 编码后，
// 在被调用端以 calldata 形式接收，完成 memory → calldata 的转换。
contract MockMerkleProofLib {
    function verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf) external pure returns (bool) {
        return MerkleProofLib.verify(proof, root, leaf);
    }
}

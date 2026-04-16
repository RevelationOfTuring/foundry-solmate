// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockMerkleProofLib} from "src/utils/MockMerkleProofLib.sol";

contract MerkleProofLibTest is Test {
    // 构建一棵 7 叶子的 Merkle Tree 用于测试
    // 采用 @openzeppelin/merkle-tree 的完全二叉树数组表示：
    // 叶子倒序填入数组末端，奇数叶子提升到更高层级
    //
    // 数组索引布局（size = 2*7-1 = 13）：
    //   tree[12]=leaves[0], tree[11]=leaves[1], ..., tree[6]=leaves[6]
    //   tree[5]=hash(tree[11],tree[12]), tree[4]=hash(tree[9],tree[10])
    //   tree[3]=hash(tree[7],tree[8]),   tree[2]=hash(tree[5],tree[6])
    //   tree[1]=hash(tree[3],tree[4]),   tree[0]=hash(tree[1],tree[2]) = root
    //
    // 树结构：
    //                 root [0]
    //               /          \
    //           [1]              [2]
    //          /    \           /    \
    //       [3]     [4]      [5]     G [6] ← 叶子提升
    //       / \     / \      / \
    //      E   F   C   D    A   B
    //     [7] [8] [9] [10] [11] [12]
    //
    // 注意：叶子倒序填入，所以 leaves[0]=A 在 tree[12]，leaves[6]=G 在 tree[6]

    MockMerkleProofLib mock = new MockMerkleProofLib();

    // 7 个叶子节点（leaves[0]~[6]，倒序填入 tree[12]~[6]）
    bytes32 leafA = keccak256(abi.encode(address(0xA), uint256(100)));
    bytes32 leafB = keccak256(abi.encode(address(0xB), uint256(200)));
    bytes32 leafC = keccak256(abi.encode(address(0xC), uint256(300)));
    bytes32 leafD = keccak256(abi.encode(address(0xD), uint256(400)));
    bytes32 leafE = keccak256(abi.encode(address(0xE), uint256(500)));
    bytes32 leafF = keccak256(abi.encode(address(0xF), uint256(600)));
    // leaves[6] → tree[6]（提升到更高层级）
    bytes32 leafG = keccak256(abi.encode(address(0x10), uint256(700)));

    // 自底向上排序后哈希构建中间节点
    // tree[5] = hash(tree[11], tree[12])
    bytes32 hashAb = _sortedHash(leafB, leafA);
    // tree[4] = hash(tree[9], tree[10])
    bytes32 hashCd = _sortedHash(leafD, leafC);
    // tree[3] = hash(tree[7], tree[8])
    bytes32 hashEf = _sortedHash(leafF, leafE);
    // tree[2] = hash(tree[5], tree[6])
    bytes32 hashAbG = _sortedHash(hashAb, leafG);
    // tree[1] = hash(tree[3], tree[4])
    bytes32 hashEfCd = _sortedHash(hashEf, hashCd);
    // tree[0] = hash(tree[1], tree[2]) = root
    bytes32 root = _sortedHash(hashEfCd, hashAbG);

    function _sortedHash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    /*//////////////////////////////////////////////////////////////
                   正向：有效证明（3 层 proof）
    //////////////////////////////////////////////////////////////*/

    // 正向：验证 leafA（tree[12]），proof = [B, G, hashEfCd]
    // 路径：A → hash(B,A)=hashAb → hash(hashAb,G)=hashAbG → hash(hashEfCd,hashAbG)=root
    function testVerifyLeafA() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafB;
        proof[1] = leafG;
        proof[2] = hashEfCd;
        assertTrue(mock.verify(proof, root, leafA));
    }

    // 正向：验证 leafB（tree[11]），proof = [A, G, hashEfCd]
    function testVerifyLeafB() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafA;
        proof[1] = leafG;
        proof[2] = hashEfCd;
        assertTrue(mock.verify(proof, root, leafB));
    }

    // 正向：验证 leafC（tree[10]），proof = [D, hashEf, hashAbG]
    function testVerifyLeafC() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafD;
        proof[1] = hashEf;
        proof[2] = hashAbG;
        assertTrue(mock.verify(proof, root, leafC));
    }

    // 正向：验证 leafD（tree[9]），proof = [C, hashEf, hashAbG]
    function testVerifyLeafD() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafC;
        proof[1] = hashEf;
        proof[2] = hashAbG;
        assertTrue(mock.verify(proof, root, leafD));
    }

    // 正向：验证 leafE（tree[8]），proof = [F, hashCd, hashAbG]
    function testVerifyLeafE() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafF;
        proof[1] = hashCd;
        proof[2] = hashAbG;
        assertTrue(mock.verify(proof, root, leafE));
    }

    // 正向：验证 leafF（tree[7]），proof = [E, hashCd, hashAbG]
    function testVerifyLeafF() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafE;
        proof[1] = hashCd;
        proof[2] = hashAbG;
        assertTrue(mock.verify(proof, root, leafF));
    }

    /*//////////////////////////////////////////////////////////////
              正向：有效证明（2 层 proof，提升叶子）
    //////////////////////////////////////////////////////////////*/

    // 正向：验证 leafG（tree[6]，被提升的叶子），proof = [hashAb, hashEfCd]
    // 路径：G → hash(hashAb,G)=hashAbG → hash(hashEfCd,hashAbG)=root
    // proof 只需 2 层，而其他叶子（如 leafA）需要 3 层
    // 这是非 2^n 叶子树（非满二叉树）的特点：不同叶子的 proof 长度不同
    function testVerifyLeafG() public view {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = hashAb;
        proof[1] = hashEfCd;
        assertTrue(mock.verify(proof, root, leafG));
    }

    /*//////////////////////////////////////////////////////////////
                        正向：空 proof
    //////////////////////////////////////////////////////////////*/

    // 正向：空 proof + leaf == root → true（单节点树）
    function testEmptyProofLeafEqualsRoot() public view {
        bytes32[] memory proof = new bytes32[](0);
        assertTrue(mock.verify(proof, root, root));
    }

    // 反向：空 proof + leaf != root → false
    function testEmptyProofLeafNotRoot() public view {
        bytes32[] memory proof = new bytes32[](0);
        assertFalse(mock.verify(proof, root, leafA));
    }

    /*//////////////////////////////////////////////////////////////
                        反向：无效证明
    //////////////////////////////////////////////////////////////*/

    // 反向：错误的 root
    function testWrongRoot() public view {
        // leafA 的正确 proof
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafB;
        proof[1] = leafG;
        proof[2] = hashEfCd;
        bytes32 wrongRoot = keccak256("wrong");
        assertFalse(mock.verify(proof, wrongRoot, leafA));
    }

    // 反向：错误的 leaf（不在树中的值）
    function testWrongLeaf() public view {
        // leafA 的正确 proof
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafB;
        proof[1] = leafG;
        proof[2] = hashEfCd;
        bytes32 fakeLeaf = keccak256(abi.encode(address(0xFF), uint256(999)));
        assertFalse(mock.verify(proof, root, fakeLeaf));
    }

    // 反向：proof 元素顺序错误
    function testWrongProofOrder() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafG;
        proof[1] = leafB;
        proof[2] = hashEfCd;
        assertFalse(mock.verify(proof, root, leafA));
    }

    // 反向：proof 长度不足（leafA 需要 3 层 proof，只传 2 个）
    function testIncompleteProof() public view {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leafB;
        proof[1] = leafG;
        assertFalse(mock.verify(proof, root, leafA));
    }

    // 反向：proof 长度过多（多一个无关元素）
    function testExtraProofElement() public view {
        bytes32[] memory proof = new bytes32[](4);
        proof[0] = leafB;
        proof[1] = leafG;
        proof[2] = hashEfCd;
        proof[3] = keccak256("extra");
        assertFalse(mock.verify(proof, root, leafA));
    }

    // 反向：用 leafA 的 proof 去验证 leafC（proof 和 leaf 不匹配）
    function testMismatchedProofAndLeaf() public view {
        // leafA 的正确 proof
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leafB;
        proof[1] = leafG;
        proof[2] = hashEfCd;
        assertFalse(mock.verify(proof, root, leafC));
    }

    /*//////////////////////////////////////////////////////////////
                    中间节点冒充叶子
    //////////////////////////////////////////////////////////////*/

    // 用中间节点 hashAbG 作为 leaf，proof=[hashEfCd] 可以算出 root
    // 说明 verify 本身不区分叶子和中间节点，调用方必须现场计算 leaf 来防范
    function testIntermediateNodeAsLeaf() public view {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = hashEfCd;
        assertTrue(mock.verify(proof, root, hashAbG));
    }

    /*//////////////////////////////////////////////////////////////
                        排序对称性
    //////////////////////////////////////////////////////////////*/

    // 正向：leafA 和 leafB 互为兄弟，proof 中交换兄弟节点后各自都能通过
    function testSortedHashSymmetry() public view {
        bytes32[] memory proofForA = new bytes32[](3);
        proofForA[0] = leafB;
        proofForA[1] = leafG;
        proofForA[2] = hashEfCd;

        bytes32[] memory proofForB = new bytes32[](3);
        proofForB[0] = leafA;
        proofForB[1] = leafG;
        proofForB[2] = hashEfCd;

        assertTrue(mock.verify(proofForA, root, leafA));
        assertTrue(mock.verify(proofForB, root, leafB));
    }

    /*//////////////////////////////////////////////////////////////
                          Fuzz Tests
    //////////////////////////////////////////////////////////////*/

    // Fuzz：随机 leaf 构建 2 叶子单层树，验证两个叶子都能通过
    function testFuzzSingleLayerTree(bytes32 a, bytes32 b) public view {
        bytes32 fuzzRoot = _sortedHash(a, b);

        bytes32[] memory proof = new bytes32[](1);

        // 验证 a：proof = [b]
        proof[0] = b;
        assertTrue(mock.verify(proof, fuzzRoot, a));

        // 验证 b：proof = [a]
        proof[0] = a;
        assertTrue(mock.verify(proof, fuzzRoot, b));
    }

    // Fuzz：随机 leaf 和 proof 几乎不可能碰撞出正确 root
    function testFuzzRandomProofFails(bytes32 randomLeaf, bytes32 randomProofElement) public view {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = randomProofElement;
        // 随机 leaf + 随机 proof 几乎不可能等于固定的 root（碰撞概率 2^-256）
        if (mock.verify(proof, root, randomLeaf)) {
            bytes32 computed = _sortedHash(randomLeaf, randomProofElement);
            assertEq(computed, root);
        }
    }
}

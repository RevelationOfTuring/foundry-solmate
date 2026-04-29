// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC1155} from "src/tokens/MockERC1155.sol";
import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

// 正确实现两个回调的接收合约
contract ERC1155Recipient is ERC1155TokenReceiver {
    // 单个回调记录
    address public lastOperator;
    address public lastFrom;
    uint256 public lastId;
    uint256 public lastAmount;
    bytes public lastData;

    // 批量回调记录
    address public lastBatchOperator;
    address public lastBatchFrom;
    uint256[] public lastBatchIds;
    uint256[] public lastBatchAmounts;
    bytes public lastBatchData;

    function onERC1155Received(address operator, address from, uint256 id, uint256 amount, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        lastOperator = operator;
        lastFrom = from;
        lastId = id;
        lastAmount = amount;
        lastData = data;
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override returns (bytes4) {
        lastBatchOperator = operator;
        lastBatchFrom = from;
        lastBatchIds = ids;
        lastBatchAmounts = amounts;
        lastBatchData = data;
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

// 返回错误 selector 的接收合约
contract WrongReturnDataERC1155Recipient {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xDEADBEEF;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return 0xDEADBEEF;
    }
}

// 没有实现回调的合约
contract NonERC1155Recipient {}

// 回调中 revert 的接收合约
contract RevertingERC1155Recipient {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        revert("NO_THANKS");
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert("NO_THANKS_BATCH");
    }
}

contract ERC1155Test is Test {
    MockERC1155 token;
    ERC1155Recipient receiver = new ERC1155Recipient();
    WrongReturnDataERC1155Recipient wrongReturnData = new WrongReturnDataERC1155Recipient();
    NonERC1155Recipient nonReceiver = new NonERC1155Recipient();
    RevertingERC1155Recipient reverting = new RevertingERC1155Recipient();

    address alice = address(0xA);
    address bob = address(0xB);
    address carol = address(0xC);

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function setUp() public {
        token = new MockERC1155();
    }

    // ==================== 辅助函数 ====================

    // 构造单元素数组
    function _single(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }

    // 构造双元素数组
    function _pair(uint256 a, uint256 b) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }

    // 构造三元素数组
    function _triple(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    /*//////////////////////////////////////////////////////////////
                              MINT
    //////////////////////////////////////////////////////////////*/

    // 正向：mint 更新 balanceOf，触发 TransferSingle 事件
    function testMint() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, 1, 100);
        token.mint(alice, 1, 100, "");

        assertEq(token.balanceOf(alice, 1), 100);
    }

    // 正向：同一地址、同一 id 多次 mint 叠加余额
    function testMintSameIdAccumulates() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 1, 50, "");

        assertEq(token.balanceOf(alice, 1), 150);
    }

    // 正向：同一地址 mint 不同 id
    function testMintDifferentIds() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(alice, 2), 200);
    }

    // 正向：不同地址 mint 同一 id
    function testMintSameIdDifferentAddresses() public {
        token.mint(alice, 1, 100, "");
        token.mint(bob, 1, 200, "");

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(bob, 1), 200);
    }

    // 正向：mint 到正确实现的合约，回调参数正确
    function testMintToReceiver() public {
        token.mint(address(receiver), 1, 100, "hello");

        assertEq(token.balanceOf(address(receiver), 1), 100);
        assertEq(receiver.lastOperator(), address(this));
        assertEq(receiver.lastFrom(), address(0));
        assertEq(receiver.lastId(), 1);
        assertEq(receiver.lastAmount(), 100);
        assertEq(receiver.lastData(), "hello");
    }

    // 正向：mint amount = 0（不 revert，余额不变）
    function testMintZeroAmount() public {
        token.mint(alice, 1, 0, "");
        assertEq(token.balanceOf(alice, 1), 0);
    }

    // 反向：mint 到零地址 revert
    function testMintToZeroAddressReverts() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.mint(address(0), 1, 100, "");
    }

    // 反向：mint 到返回错误 selector 的合约 revert
    function testMintToWrongReturnDataReverts() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.mint(address(wrongReturnData), 1, 100, "");
    }

    // 反向：mint 到未实现接口的合约 revert
    function testMintToNonReceiverReverts() public {
        vm.expectRevert();
        token.mint(address(nonReceiver), 1, 100, "");
    }

    // 反向：mint 到 revert 的合约 revert
    function testMintToRevertingReceiverReverts() public {
        vm.expectRevert("NO_THANKS");
        token.mint(address(reverting), 1, 100, "");
    }

    // Fuzz：任意地址、id、amount 的 mint
    function testFuzzMint(address to, uint256 id, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);

        token.mint(to, id, amount, "");
        assertEq(token.balanceOf(to, id), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            BATCHMINT
    //////////////////////////////////////////////////////////////*/

    // 正向：batchMint 更新多个 id 的余额，触发 TransferBatch 事件
    function testBatchMint() public {
        uint256[] memory ids = _pair(1, 2);
        uint256[] memory amounts = _pair(100, 200);

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), alice, ids, amounts);
        token.batchMint(alice, ids, amounts, "");

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(alice, 2), 200);
    }

    // 正向：batchMint 到正确实现的合约，批量回调参数正确
    function testBatchMintToReceiver() public {
        uint256[] memory ids = _pair(1, 2);
        uint256[] memory amounts = _pair(100, 200);

        token.batchMint(address(receiver), ids, amounts, "batch");

        assertEq(token.balanceOf(address(receiver), 1), 100);
        assertEq(token.balanceOf(address(receiver), 2), 200);
        assertEq(receiver.lastBatchOperator(), address(this));
        assertEq(receiver.lastBatchFrom(), address(0));
        assertEq(receiver.lastBatchIds(0), 1);
        assertEq(receiver.lastBatchIds(1), 2);
        assertEq(receiver.lastBatchAmounts(0), 100);
        assertEq(receiver.lastBatchAmounts(1), 200);
        assertEq(receiver.lastBatchData(), "batch");
    }

    // 正向：batchMint 空数组不 revert
    function testBatchMintEmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        token.batchMint(alice, ids, amounts, "");
    }

    // 反向：batchMint ids 和 amounts 长度不匹配 revert
    function testBatchMintLengthMismatchReverts() public {
        uint256[] memory ids = _pair(1, 2);
        uint256[] memory amounts = _single(100);

        vm.expectRevert("LENGTH_MISMATCH");
        token.batchMint(alice, ids, amounts, "");
    }

    // 反向：batchMint 到零地址 revert
    function testBatchMintToZeroAddressReverts() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.batchMint(address(0), _single(1), _single(100), "");
    }

    // 反向：batchMint 到返回错误 selector 的合约 revert
    function testBatchMintToWrongReturnDataReverts() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.batchMint(address(wrongReturnData), _single(1), _single(100), "");
    }

    // 反向：batchMint 到未实现接口的合约 revert
    function testBatchMintToNonReceiverReverts() public {
        vm.expectRevert();
        token.batchMint(address(nonReceiver), _single(1), _single(100), "");
    }

    // 反向：batchMint 到 revert 的合约 revert
    function testBatchMintToRevertingReceiverReverts() public {
        vm.expectRevert("NO_THANKS_BATCH");
        token.batchMint(address(reverting), _single(1), _single(100), "");
    }

    /*//////////////////////////////////////////////////////////////
                              BURN
    //////////////////////////////////////////////////////////////*/

    // 正向：burn 减少余额，触发 TransferSingle 事件
    function testBurn() public {
        token.mint(alice, 1, 100, "");

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), 1, 30);
        token.burn(alice, 1, 30);

        assertEq(token.balanceOf(alice, 1), 70);
    }

    // 正向：burn 全部余额
    function testBurnEntireBalance() public {
        token.mint(alice, 1, 100, "");
        token.burn(alice, 1, 100);

        assertEq(token.balanceOf(alice, 1), 0);
    }

    // 正向：burn amount = 0 不 revert
    function testBurnZeroAmount() public {
        token.mint(alice, 1, 100, "");
        token.burn(alice, 1, 0);

        assertEq(token.balanceOf(alice, 1), 100);
    }

    // 反向：burn 超过余额 revert（checked 算术下溢）
    function testBurnExceedsBalanceReverts() public {
        token.mint(alice, 1, 100, "");

        vm.expectRevert();
        token.burn(alice, 1, 101);
    }

    // 反向：burn 未铸造的 id revert（余额为 0，-= amount 下溢）
    function testBurnNonExistentReverts() public {
        vm.expectRevert();
        token.burn(alice, 1, 1);
    }

    /*//////////////////////////////////////////////////////////////
                            BATCHBURN
    //////////////////////////////////////////////////////////////*/

    // 正向：batchBurn 减少多个 id 的余额，触发 TransferBatch 事件
    function testBatchBurn() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        uint256[] memory ids = _pair(1, 2);
        uint256[] memory amounts = _pair(30, 50);

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), alice, address(0), ids, amounts);
        token.batchBurn(alice, ids, amounts);

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(alice, 2), 150);
    }

    // 正向：batchBurn 空数组不 revert
    function testBatchBurnEmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        token.batchBurn(alice, ids, amounts);
    }

    // 反向：batchBurn 长度不匹配 revert
    function testBatchBurnLengthMismatchReverts() public {
        token.mint(alice, 1, 100, "");

        vm.expectRevert("LENGTH_MISMATCH");
        token.batchBurn(alice, _pair(1, 2), _single(30));
    }

    // 反向：batchBurn 超过余额 revert
    function testBatchBurnExceedsBalanceReverts() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        vm.expectRevert();
        token.batchBurn(alice, _pair(1, 2), _pair(101, 50));
    }

    /*//////////////////////////////////////////////////////////////
                            BALANCEOF
    //////////////////////////////////////////////////////////////*/

    // 正向：未铸造的 id 余额为 0
    function testBalanceOfInitiallyZero() public view {
        assertEq(token.balanceOf(alice, 1), 0);
    }

    // 正向：零地址的余额为 0（ERC1155 不像 ERC721 那样 revert）
    function testBalanceOfZeroAddress() public view {
        assertEq(token.balanceOf(address(0), 1), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          BALANCEOFBATCH
    //////////////////////////////////////////////////////////////*/

    // 正向：批量查询多个 (owner, id) 对的余额
    function testBalanceOfBatch() public {
        token.mint(alice, 1, 100, "");
        token.mint(bob, 2, 200, "");
        token.mint(alice, 3, 300, "");

        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = alice;

        uint256[] memory ids = _triple(1, 2, 3);

        uint256[] memory balances = token.balanceOfBatch(owners, ids);

        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
        assertEq(balances[2], 300);
    }

    // 正向：批量查询空数组
    function testBalanceOfBatchEmptyArrays() public view {
        address[] memory owners = new address[](0);
        uint256[] memory ids = new uint256[](0);

        uint256[] memory balances = token.balanceOfBatch(owners, ids);
        assertEq(balances.length, 0);
    }

    // 反向：owners 和 ids 长度不匹配 revert
    function testBalanceOfBatchLengthMismatchReverts() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        vm.expectRevert("LENGTH_MISMATCH");
        token.balanceOfBatch(owners, _single(1));
    }

    /*//////////////////////////////////////////////////////////////
                         SETAPPROVALFORALL
    //////////////////////////////////////////////////////////////*/

    // 正向：setApprovalForAll 设置全局授权，触发 ApprovalForAll 事件
    function testSetApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));
    }

    // 正向：撤销全局授权
    function testRevokeApprovalForAll() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, false);
        token.setApprovalForAll(bob, false);

        assertFalse(token.isApprovedForAll(alice, bob));
    }

    // 正向：初始状态未授权
    function testIsApprovedForAllInitiallyFalse() public view {
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    // 正向：授权多个 operator
    function testSetApprovalForAllMultipleOperators() public {
        vm.startPrank(alice);
        token.setApprovalForAll(bob, true);
        token.setApprovalForAll(carol, true);
        vm.stopPrank();

        assertTrue(token.isApprovedForAll(alice, bob));
        assertTrue(token.isApprovedForAll(alice, carol));
    }

    // 正向：重复授权不 revert
    function testSetApprovalForAllIdempotent() public {
        vm.startPrank(alice);
        token.setApprovalForAll(bob, true);
        token.setApprovalForAll(bob, true);
        vm.stopPrank();

        assertTrue(token.isApprovedForAll(alice, bob));
    }

    /*//////////////////////////////////////////////////////////////
                         SAFETRANSFERFROM
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 自己转移，触发 TransferSingle 事件
    function testSafeTransferFromByOwner() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, 1, 30);
        token.safeTransferFrom(alice, bob, 1, 30, "");

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(bob, 1), 30);
    }

    // 正向：被全局授权的 operator 转移
    function testSafeTransferFromByOperator() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.safeTransferFrom(alice, carol, 1, 40, "");

        assertEq(token.balanceOf(alice, 1), 60);
        assertEq(token.balanceOf(carol, 1), 40);
    }

    // 正向：转移全部余额
    function testSafeTransferFromEntireBalance() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 100, "");

        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(token.balanceOf(bob, 1), 100);
    }

    // 正向：转给自己（余额不变）
    function testSafeTransferFromToSelf() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, alice, 1, 30, "");

        assertEq(token.balanceOf(alice, 1), 100);
    }

    // 正向：转移 amount = 0
    function testSafeTransferFromZeroAmount() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 0, "");

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(bob, 1), 0);
    }

    // 正向：safeTransferFrom 到正确实现的合约，回调参数正确
    function testSafeTransferFromToReceiver() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, address(receiver), 1, 50, "data");

        assertEq(token.balanceOf(address(receiver), 1), 50);
        assertEq(receiver.lastOperator(), alice);
        assertEq(receiver.lastFrom(), alice);
        assertEq(receiver.lastId(), 1);
        assertEq(receiver.lastAmount(), 50);
        assertEq(receiver.lastData(), "data");
    }

    // 正向：operator 调用 safeTransferFrom，receiver 收到的 operator 是 msg.sender
    function testSafeTransferFromOperatorIsMessageSender() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.safeTransferFrom(alice, address(receiver), 1, 50, "");

        // operator 是实际调用者 bob，不是 owner alice
        assertEq(receiver.lastOperator(), bob);
        assertEq(receiver.lastFrom(), alice);
    }

    // 反向：未授权的地址不能转移 revert
    function testSafeTransferFromUnauthorizedReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        token.safeTransferFrom(alice, carol, 1, 30, "");
    }

    // 反向：转移超过余额 revert
    function testSafeTransferFromExceedsBalanceReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert();
        token.safeTransferFrom(alice, bob, 1, 101, "");
    }

    // 反向：safeTransferFrom 到零地址 revert
    function testSafeTransferFromToZeroAddressReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeTransferFrom(alice, address(0), 1, 30, "");
    }

    // 反向：safeTransferFrom 到返回错误 selector 的合约 revert
    function testSafeTransferFromToWrongReturnDataReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeTransferFrom(alice, address(wrongReturnData), 1, 30, "");
    }

    // 反向：safeTransferFrom 到未实现接口的合约 revert
    function testSafeTransferFromToNonReceiverReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert();
        token.safeTransferFrom(alice, address(nonReceiver), 1, 30, "");
    }

    // 反向：safeTransferFrom 到 revert 的合约 revert
    function testSafeTransferFromToRevertingReceiverReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("NO_THANKS");
        token.safeTransferFrom(alice, address(reverting), 1, 30, "");
    }

    // Fuzz：任意地址的 safeTransferFrom
    function testFuzzSafeTransferFrom(address to, uint256 id, uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        transferAmount = bound(transferAmount, 0, mintAmount);

        token.mint(alice, id, mintAmount, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, to, id, transferAmount, "");

        if (to == alice) {
            assertEq(token.balanceOf(alice, id), mintAmount);
        } else {
            assertEq(token.balanceOf(alice, id), mintAmount - transferAmount);
            assertEq(token.balanceOf(to, id), transferAmount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                       SAFEBATCHTRANSFERFROM
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 批量转移，触发 TransferBatch 事件
    function testSafeBatchTransferFromByOwner() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        uint256[] memory ids = _pair(1, 2);
        uint256[] memory amounts = _pair(30, 50);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, amounts);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(alice, 2), 150);
        assertEq(token.balanceOf(bob, 1), 30);
        assertEq(token.balanceOf(bob, 2), 50);
    }

    // 正向：被全局授权的 operator 批量转移
    function testSafeBatchTransferFromByOperator() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.safeBatchTransferFrom(alice, carol, _pair(1, 2), _pair(30, 50), "");

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(alice, 2), 150);
        assertEq(token.balanceOf(carol, 1), 30);
        assertEq(token.balanceOf(carol, 2), 50);
    }

    // 正向：批量转移到正确实现的合约，批量回调参数正确
    function testSafeBatchTransferFromToReceiver() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, address(receiver), _pair(1, 2), _pair(30, 50), "batchdata");

        assertEq(token.balanceOf(alice, 1), 70);
        assertEq(token.balanceOf(alice, 2), 150);
        assertEq(token.balanceOf(address(receiver), 1), 30);
        assertEq(token.balanceOf(address(receiver), 2), 50);
        assertEq(receiver.lastBatchOperator(), alice);
        assertEq(receiver.lastBatchFrom(), alice);
        assertEq(receiver.lastBatchIds(0), 1);
        assertEq(receiver.lastBatchIds(1), 2);
        assertEq(receiver.lastBatchAmounts(0), 30);
        assertEq(receiver.lastBatchAmounts(1), 50);
        assertEq(receiver.lastBatchData(), "batchdata");
    }

    // 正向：批量转移空数组不 revert
    function testSafeBatchTransferFromEmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    // 正向：批量转给自己
    function testSafeBatchTransferFromToSelf() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, alice, _pair(1, 2), _pair(30, 50), "");

        assertEq(token.balanceOf(alice, 1), 100);
        assertEq(token.balanceOf(alice, 2), 200);
    }

    // 反向：ids 和 amounts 长度不匹配 revert
    function testSafeBatchTransferFromLengthMismatchReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("LENGTH_MISMATCH");
        token.safeBatchTransferFrom(alice, bob, _pair(1, 2), _single(30), "");
    }

    // 反向：未授权 revert
    function testSafeBatchTransferFromUnauthorizedReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        token.safeBatchTransferFrom(alice, carol, _single(1), _single(30), "");
    }

    // 反向：转移超过余额 revert
    function testSafeBatchTransferFromExceedsBalanceReverts() public {
        token.mint(alice, 1, 100, "");
        token.mint(alice, 2, 200, "");

        vm.prank(alice);
        vm.expectRevert();
        token.safeBatchTransferFrom(alice, bob, _pair(1, 2), _pair(101, 50), "");
    }

    // 反向：批量转移到零地址 revert
    function testSafeBatchTransferFromToZeroAddressReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeBatchTransferFrom(alice, address(0), _single(1), _single(30), "");
    }

    // 反向：批量转移到返回错误 selector 的合约 revert
    function testSafeBatchTransferFromToWrongReturnDataReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("UNSAFE_RECIPIENT");
        token.safeBatchTransferFrom(alice, address(wrongReturnData), _single(1), _single(30), "");
    }

    // 反向：批量转移到未实现接口的合约 revert
    function testSafeBatchTransferFromToNonReceiverReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert();
        token.safeBatchTransferFrom(alice, address(nonReceiver), _single(1), _single(30), "");
    }

    // 反向：批量转移到 revert 的合约 revert
    function testSafeBatchTransferFromToRevertingReceiverReverts() public {
        token.mint(alice, 1, 100, "");

        vm.prank(alice);
        vm.expectRevert("NO_THANKS_BATCH");
        token.safeBatchTransferFrom(alice, address(reverting), _single(1), _single(30), "");
    }

    /*//////////////////////////////////////////////////////////////
                              URI
    //////////////////////////////////////////////////////////////*/

    // 正向：MockERC1155 的 uri 返回空字符串
    function testUri() public view {
        assertEq(token.uri(0), "");
        assertEq(token.uri(1), "");
        assertEq(token.uri(type(uint256).max), "");
    }

    /*//////////////////////////////////////////////////////////////
                         SUPPORTSINTERFACE
    //////////////////////////////////////////////////////////////*/

    // 正向：支持 ERC165
    function testSupportsERC165() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7));
    }

    // 正向：支持 ERC1155
    function testSupportsERC1155() public view {
        assertTrue(token.supportsInterface(0xd9b67a26));
    }

    // 正向：支持 ERC1155MetadataURI
    function testSupportsERC1155MetadataURI() public view {
        assertTrue(token.supportsInterface(0x0e89341c));
    }

    // 边界：不支持 0xFFFFFFFF（ERC165 规范要求）
    function testDoesNotSupportInvalidInterface() public view {
        assertFalse(token.supportsInterface(0xFFFFFFFF));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC721} from "src/tokens/MockERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

// 正确实现 onERC721Received 的接收合约
contract ERC721Recipient is ERC721TokenReceiver {
    address public lastOperator;
    address public lastFrom;
    uint256 public lastId;
    bytes public lastData;

    function onERC721Received(address operator, address from, uint256 id, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        lastOperator = operator;
        lastFrom = from;
        lastId = id;
        lastData = data;
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

// 返回错误 selector 的接收合约
contract WrongReturnDataERC721Recipient {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xDEADBEEF;
    }
}

// 没有实现 onERC721Received 的合约
contract NonERC721Recipient {}

// onERC721Received 中 revert 的接收合约
contract RevertingERC721Recipient {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        revert("NO_THANKS");
    }
}

contract ERC721Test is Test {
    MockERC721 nft;
    ERC721Recipient receiver = new ERC721Recipient();
    WrongReturnDataERC721Recipient wrongReturnData = new WrongReturnDataERC721Recipient();
    NonERC721Recipient nonReceiver = new NonERC721Recipient();
    RevertingERC721Recipient reverting = new RevertingERC721Recipient();

    address alice = address(0xA);
    address bob = address(0xB);
    address carol = address(0xC);

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setUp() public {
        nft = new MockERC721("Test NFT", "TNFT");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // 验证构造函数正确设置 name 和 symbol
    function testConstructorSetsMetadata() public view {
        assertEq(nft.name(), "Test NFT");
        assertEq(nft.symbol(), "TNFT");
    }

    // 边界：空字符串作为 name 和 symbol
    function testConstructorWithEmptyStrings() public {
        MockERC721 empty = new MockERC721("", "");
        assertEq(empty.name(), "");
        assertEq(empty.symbol(), "");
    }

    /*//////////////////////////////////////////////////////////////
                              MINT
    //////////////////////////////////////////////////////////////*/

    // 正向：mint 设置 owner、更新 balanceOf、触发 Transfer 事件
    function testMint() public {
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        nft.mint(alice, 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    // 正向：同一地址 mint 多个 NFT
    function testMintMultipleToSameAddress() public {
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        nft.mint(alice, 3);

        assertEq(nft.balanceOf(alice), 3);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.ownerOf(3), alice);
    }

    // 正向：不同地址 mint 不同 id
    function testMintToDifferentAddresses() public {
        nft.mint(alice, 1);
        nft.mint(bob, 2);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), bob);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 1);
    }

    // 反向：mint 到零地址 revert
    function testMintToZeroAddressReverts() public {
        vm.expectRevert("INVALID_RECIPIENT");
        nft.mint(address(0), 1);
    }

    // 反向：重复 mint 同一 id revert
    function testMintDuplicateIdReverts() public {
        nft.mint(alice, 1);
        vm.expectRevert("ALREADY_MINTED");
        nft.mint(bob, 1);
    }

    // Fuzz：任意地址和 id 的 mint
    function testFuzzMint(address to, uint256 id) public {
        vm.assume(to != address(0));

        nft.mint(to, id);
        assertEq(nft.ownerOf(id), to);
        assertEq(nft.balanceOf(to), 1);
    }

    /*//////////////////////////////////////////////////////////////
                              BURN
    //////////////////////////////////////////////////////////////*/

    // 正向：burn 清除 owner、更新 balanceOf、触发 Transfer 事件
    function testBurn() public {
        nft.mint(alice, 1);

        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, address(0), 1);
        nft.burn(1);

        assertEq(nft.balanceOf(alice), 0);
    }

    // 正向：burn 后 ownerOf revert
    function testBurnThenOwnerOfReverts() public {
        nft.mint(alice, 1);
        nft.burn(1);

        vm.expectRevert("NOT_MINTED");
        nft.ownerOf(1);
    }

    // 正向：burn 后清除 getApproved
    function testBurnClearsApproval() public {
        nft.mint(alice, 1);
        vm.prank(alice);
        nft.approve(bob, 1);

        nft.burn(1);
        assertEq(nft.getApproved(1), address(0));
    }

    // 反向：burn 未铸造的 id revert
    function testBurnNonExistentReverts() public {
        vm.expectRevert("NOT_MINTED");
        nft.burn(1);
    }

    // 正向：burn 后可以重新 mint 同一 id
    function testBurnAndRemint() public {
        nft.mint(alice, 1);
        nft.burn(1);

        nft.mint(bob, 1);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(bob), 1);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNEROF
    //////////////////////////////////////////////////////////////*/

    // 反向：查询未铸造 token 的 owner revert
    function testOwnerOfUnmintedReverts() public {
        vm.expectRevert("NOT_MINTED");
        nft.ownerOf(1);
    }

    /*//////////////////////////////////////////////////////////////
                            BALANCEOF
    //////////////////////////////////////////////////////////////*/

    // 正向：初始余额为 0
    function testBalanceOfInitiallyZero() public view {
        assertEq(nft.balanceOf(alice), 0);
    }

    // 反向：查询零地址的 balance revert
    function testBalanceOfZeroAddressReverts() public {
        vm.expectRevert("ZERO_ADDRESS");
        nft.balanceOf(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              APPROVE
    //////////////////////////////////////////////////////////////*/

    // 正向：owner approve spender，触发 Approval 事件
    function testApprove() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Approval(alice, bob, 1);
        nft.approve(bob, 1);

        assertEq(nft.getApproved(1), bob);
    }

    // 正向：approve 覆盖旧值
    function testApproveOverwritesPrevious() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(alice);
        nft.approve(carol, 1);

        assertEq(nft.getApproved(1), carol);
    }

    // 正向：approve address(0) 取消授权
    function testApproveZeroAddressClearsApproval() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(alice);
        nft.approve(address(0), 1);

        assertEq(nft.getApproved(1), address(0));
    }

    // 正向：被全局授权的 operator 可以 approve
    function testApproveByOperator() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.prank(bob);
        nft.approve(carol, 1);

        assertEq(nft.getApproved(1), carol);
    }

    // 反向：非 owner 且非 operator 不能 approve
    function testApproveUnauthorizedReverts() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        nft.approve(carol, 1);
    }

    // 反向：单独被授权的 spender 不能再 approve 给别人
    function testApproveByApprovedSpenderReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        nft.approve(carol, 1);
    }

    /*//////////////////////////////////////////////////////////////
                         SETAPPROVALFORALL
    //////////////////////////////////////////////////////////////*/

    // 正向：setApprovalForAll 设置全局授权，触发 ApprovalForAll 事件
    function testSetApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);
        nft.setApprovalForAll(bob, true);

        assertTrue(nft.isApprovedForAll(alice, bob));
    }

    // 正向：撤销全局授权
    function testRevokeApprovalForAll() public {
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, false);
        nft.setApprovalForAll(bob, false);

        assertFalse(nft.isApprovedForAll(alice, bob));
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFERFROM
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 自己转移，触发 Transfer 事件
    function testTransferFromByOwner() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    // 正向：被 approve 的 spender 转移
    function testTransferFromByApproved() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.ownerOf(1), carol);
    }

    // 正向：被 setApprovalForAll 的 operator 转移
    function testTransferFromByOperator() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.prank(bob);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.ownerOf(1), carol);
    }

    // 正向：transferFrom 清除单个授权
    function testTransferFromClearsApproval() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(alice);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.getApproved(1), address(0));
    }

    // 正向：transferFrom 不影响全局授权
    function testTransferFromDoesNotClearApprovalForAll() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.prank(alice);
        nft.transferFrom(alice, carol, 1);

        // 全局授权依然有效
        assertTrue(nft.isApprovedForAll(alice, bob));
    }

    // 正向：转给自己（余额不变）
    function testTransferFromToSelf() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.transferFrom(alice, alice, 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    // 反向：from 不是 owner revert
    function testTransferFromWrongFromReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("WRONG_FROM");
        nft.transferFrom(bob, carol, 1);
    }

    // 反向：转到零地址 revert
    function testTransferFromToZeroAddressReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("INVALID_RECIPIENT");
        nft.transferFrom(alice, address(0), 1);
    }

    // 反向：未授权的地址不能转移 revert
    function testTransferFromUnauthorizedReverts() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        nft.transferFrom(alice, carol, 1);
    }

    // 反向：转移未铸造的 token revert
    function testTransferFromNonExistentReverts() public {
        vm.prank(alice);
        vm.expectRevert("WRONG_FROM");
        nft.transferFrom(alice, bob, 1);
    }

    // Fuzz：任意地址的 transferFrom
    function testFuzzTransferFrom(address to) public {
        vm.assume(to != address(0));

        nft.mint(alice, 1);

        vm.prank(alice);
        nft.transferFrom(alice, to, 1);

        assertEq(nft.ownerOf(1), to);
        // alice 的余额：如果 to == alice 则为 1，否则为 0
        if (to == alice) {
            assertEq(nft.balanceOf(alice), 1);
        } else {
            assertEq(nft.balanceOf(alice), 0);
            assertEq(nft.balanceOf(to), 1);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         SAFETRANSFERFROM
    //////////////////////////////////////////////////////////////*/

    // 正向：safeTransferFrom 到 EOA 成功
    function testSafeTransferFromToEOA() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
    }

    // 正向：safeTransferFrom 到正确实现的合约
    function testSafeTransferFromToReceiver() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 1);

        assertEq(nft.ownerOf(1), address(receiver));
        assertEq(receiver.lastOperator(), alice);
        assertEq(receiver.lastFrom(), alice);
        assertEq(receiver.lastId(), 1);
        assertEq(receiver.lastData(), "");
    }

    // 正向：safeTransferFrom 带 data 到正确实现的合约
    function testSafeTransferFromWithData() public {
        nft.mint(alice, 1);

        bytes memory data = abi.encode(uint256(42));

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 1, data);

        assertEq(nft.ownerOf(1), address(receiver));
        assertEq(receiver.lastOperator(), alice);
        assertEq(receiver.lastFrom(), alice);
        assertEq(receiver.lastId(), 1);
        assertEq(receiver.lastData(), data);
    }

    // 正向：operator 调用 safeTransferFrom，receiver 收到的 operator 是 msg.sender
    function testSafeTransferFromOperatorIsMessageSender() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.prank(bob);
        nft.safeTransferFrom(alice, address(receiver), 1);

        // operator 是实际调用者 bob，不是 owner alice
        assertEq(receiver.lastOperator(), bob);
        assertEq(receiver.lastFrom(), alice);
    }

    // 反向：safeTransferFrom 到返回错误 selector 的合约 revert
    function testSafeTransferFromToWrongReturnDataReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("UNSAFE_RECIPIENT");
        nft.safeTransferFrom(alice, address(wrongReturnData), 1);
    }

    // 反向：safeTransferFrom 到未实现接口的合约 revert
    function testSafeTransferFromToNonReceiverReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert();
        nft.safeTransferFrom(alice, address(nonReceiver), 1);
    }

    // 反向：safeTransferFrom 到 revert 的合约 revert
    function testSafeTransferFromToRevertingReceiverReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("NO_THANKS");
        nft.safeTransferFrom(alice, address(reverting), 1);
    }

    // 反向：safeTransferFrom 带 data 到返回错误 selector 的合约 revert
    function testSafeTransferFromWithDataToWrongReturnDataReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("UNSAFE_RECIPIENT");
        nft.safeTransferFrom(alice, address(wrongReturnData), 1, "test");
    }

    // 反向：safeTransferFrom 带 data 到未实现接口的合约 revert
    function testSafeTransferFromWithDataToNonReceiverReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert();
        nft.safeTransferFrom(alice, address(nonReceiver), 1, "test");
    }

    // 反向：safeTransferFrom 带 data 到 revert 的合约 revert
    function testSafeTransferFromWithDataToRevertingReceiverReverts() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("NO_THANKS");
        nft.safeTransferFrom(alice, address(reverting), 1, "test");
    }

    /*//////////////////////////////////////////////////////////////
                             SAFEMINT
    //////////////////////////////////////////////////////////////*/

    // 正向：safeMint 到 EOA 成功
    function testSafeMintToEOA() public {
        nft.safeMint(alice, 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    // 正向：safeMint 到正确实现的合约
    function testSafeMintToReceiver() public {
        nft.safeMint(address(receiver), 1);

        assertEq(nft.ownerOf(1), address(receiver));
        assertEq(receiver.lastOperator(), address(this));
        assertEq(receiver.lastFrom(), address(0));
        assertEq(receiver.lastId(), 1);
        assertEq(receiver.lastData(), "");
    }

    // 正向：safeMint 带 data 到正确实现的合约
    function testSafeMintWithData() public {
        bytes memory data = abi.encode(uint256(99));

        nft.safeMint(address(receiver), 1, data);

        assertEq(nft.ownerOf(1), address(receiver));
        assertEq(receiver.lastData(), data);
    }

    // 反向：safeMint 到返回错误 selector 的合约 revert
    function testSafeMintToWrongReturnDataReverts() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        nft.safeMint(address(wrongReturnData), 1);
    }

    // 反向：safeMint 到未实现接口的合约 revert
    function testSafeMintToNonReceiverReverts() public {
        vm.expectRevert();
        nft.safeMint(address(nonReceiver), 1);
    }

    // 反向：safeMint 到 revert 的合约 revert
    function testSafeMintToRevertingReceiverReverts() public {
        vm.expectRevert("NO_THANKS");
        nft.safeMint(address(reverting), 1);
    }

    // 反向：safeMint 带 data 到返回错误 selector 的合约 revert
    function testSafeMintWithDataToWrongReturnDataReverts() public {
        vm.expectRevert("UNSAFE_RECIPIENT");
        nft.safeMint(address(wrongReturnData), 1, "test");
    }

    // 反向：safeMint 带 data 到未实现接口的合约 revert
    function testSafeMintWithDataToNonReceiverReverts() public {
        vm.expectRevert();
        nft.safeMint(address(nonReceiver), 1, "test");
    }

    // 反向：safeMint 带 data 到 revert 的合约 revert
    function testSafeMintWithDataToRevertingReceiverReverts() public {
        vm.expectRevert("NO_THANKS");
        nft.safeMint(address(reverting), 1, "test");
    }

    // 反向：safeMint 到零地址 revert
    function testSafeMintToZeroAddressReverts() public {
        vm.expectRevert("INVALID_RECIPIENT");
        nft.safeMint(address(0), 1);
    }

    // 反向：safeMint 重复 id revert
    function testSafeMintDuplicateIdReverts() public {
        nft.safeMint(alice, 1);
        vm.expectRevert("ALREADY_MINTED");
        nft.safeMint(bob, 1);
    }

    /*//////////////////////////////////////////////////////////////
                         SUPPORTSINTERFACE
    //////////////////////////////////////////////////////////////*/

    // 正向：支持 ERC165
    function testSupportsERC165() public view {
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }

    // 正向：支持 ERC721
    function testSupportsERC721() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd));
    }

    // 正向：支持 ERC721Metadata
    function testSupportsERC721Metadata() public view {
        assertTrue(nft.supportsInterface(0x5b5e139f));
    }

    // 边界：不支持 0xFFFFFFFF（ERC165 规范要求：https://eips.ethereum.org/EIPS/eip-165）
    function testDoesNotSupportInvalidInterface() public view {
        assertFalse(nft.supportsInterface(0xFFFFFFFF));
    }
}

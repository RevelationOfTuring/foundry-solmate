// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockOwned} from "src/auth/MockOwned.sol";

contract OwnedTest is Test {
    MockOwned owned;

    address owner = address(0xA);
    address nonOwner = address(0xB);
    address newOwner = address(0xC);

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    function setUp() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), owner);
        owned = new MockOwned(owner);
    }

    /*//////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // 验证构造函数正确设置 owner
    function testConstructorSetsOwner() public view {
        assertEq(owned.owner(), owner);
    }

    // 边界：构造函数可以传入零地址作为 owner
    function testConstructorWithZeroAddress() public {
        MockOwned zeroOwned = new MockOwned(address(0));
        assertEq(zeroOwned.owner(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 可以调用受保护函数
    function testOwnerCanCallProtected() public {
        vm.prank(owner);
        assertTrue(owned.protectedFunction());
    }

    // 反向：非 owner 调用受保护函数 → revert
    function testNonOwnerCannotCallProtected() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        owned.protectedFunction();
    }

    // 正向：任何人都可以调用不受保护的函数
    function testAnyoneCanCallUnprotected() public {
        vm.prank(nonOwner);
        assertTrue(owned.unprotectedFunction());
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 可以转移所有权，验证事件和状态
    function testTransferOwnership() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        owned.transferOwnership(newOwner);

        assertEq(owned.owner(), newOwner);
    }

    // 边界：可以将所有权转移给零地址（放弃所有权）
    function testTransferOwnershipToZeroAddress() public {
        vm.prank(owner);
        owned.transferOwnership(address(0));
        assertEq(owned.owner(), address(0));
    }

    // 反向：非 owner 不能转移所有权
    function testNonOwnerCannotTransfer() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        owned.transferOwnership(newOwner);
    }

    // 正向：转移所有权后旧 owner 失去权限
    function testOldOwnerLosesAccessAfterTransfer() public {
        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.prank(owner);
        vm.expectRevert("UNAUTHORIZED");
        owned.protectedFunction();
    }

    // 正向：转移所有权后新 owner 获得权限
    function testNewOwnerGainsAccessAfterTransfer() public {
        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.prank(newOwner);
        assertTrue(owned.protectedFunction());
    }
}

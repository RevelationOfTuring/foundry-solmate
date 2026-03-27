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

    function testConstructorSetsOwner() public view {
        assertEq(owned.owner(), owner);
    }

    function testConstructorWithZeroAddress() public {
        MockOwned zeroOwned = new MockOwned(address(0));
        assertEq(zeroOwned.owner(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanCallProtected() public {
        vm.prank(owner);
        assertTrue(owned.protectedFunction());
    }

    function testNonOwnerCannotCallProtected() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        owned.protectedFunction();
    }

    function testAnyoneCanCallUnprotected() public {
        vm.prank(nonOwner);
        assertTrue(owned.unprotectedFunction());
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function testTransferOwnership() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        owned.transferOwnership(newOwner);

        assertEq(owned.owner(), newOwner);
    }

    function testTransferOwnershipToZeroAddress() public {
        vm.prank(owner);
        owned.transferOwnership(address(0));
        assertEq(owned.owner(), address(0));
    }

    function testNonOwnerCannotTransfer() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        owned.transferOwnership(newOwner);
    }

    function testOldOwnerLosesAccessAfterTransfer() public {
        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.prank(owner);
        vm.expectRevert("UNAUTHORIZED");
        owned.protectedFunction();
    }

    function testNewOwnerGainsAccessAfterTransfer() public {
        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.prank(newOwner);
        assertTrue(owned.protectedFunction());
    }
}

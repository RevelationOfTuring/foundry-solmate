// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Authority} from "solmate/auth/Auth.sol";
import {MockAuth, MockAuthority, RevertingAuthority} from "src/auth/MockAuth.sol";

contract AuthTest is Test {
    MockAuth authed;
    MockAuthority authority;
    RevertingAuthority bad = new RevertingAuthority();

    address owner = address(0xA);
    address user = address(0xB);
    address newOwner = address(0xC);

    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    function setUp() public {
        authority = new MockAuthority();

        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), owner);
        vm.expectEmit(true, true, false, false);
        emit AuthorityUpdated(address(this), authority);

        authed = new MockAuth(owner, authority);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsOwner() public view {
        assertEq(authed.owner(), owner);
    }

    function testConstructorSetsAuthority() public view {
        assertEq(address(authed.authority()), address(authority));
    }

    function testConstructorWithZeroAuthority() public {
        MockAuth noAuth = new MockAuth(owner, Authority(address(0)));
        assertEq(address(noAuth.authority()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          REQUIRES AUTH
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanCallProtected() public {
        vm.prank(owner);
        assertTrue(authed.protectedFunction());
    }

    function testAuthorizedUserCanCallProtected() public {
        authority.setCanCall(user, address(authed), MockAuth.protectedFunction.selector, true);

        vm.prank(user);
        assertTrue(authed.protectedFunction());
    }

    function testUnauthorizedUserCannotCallProtected() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        authed.protectedFunction();
    }

    function testAnyoneCanCallUnprotected() public {
        vm.prank(user);
        assertTrue(authed.unprotectedFunction());
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanTransferOwnership() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        authed.transferOwnership(newOwner);

        assertEq(authed.owner(), newOwner);
    }

    function testAuthorizedUserCanTransferOwnership() public {
        authority.setCanCall(user, address(authed), authed.transferOwnership.selector, true);

        vm.prank(user);
        authed.transferOwnership(newOwner);

        assertEq(authed.owner(), newOwner);
    }

    function testUnauthorizedUserCannotTransferOwnership() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        authed.transferOwnership(newOwner);
    }

    function testTransferOwnershipToZeroAddress() public {
        vm.prank(owner);
        authed.transferOwnership(address(0));
        assertEq(authed.owner(), address(0));
    }

    function testOldOwnerLosesAccessAfterTransfer() public {
        vm.prank(owner);
        authed.transferOwnership(newOwner);

        // 清除旧 owner 在 authority 中的权限
        authority.setCanCall(owner, address(authed), authed.protectedFunction.selector, false);

        vm.prank(owner);
        vm.expectRevert("UNAUTHORIZED");
        authed.protectedFunction();
    }

    /*//////////////////////////////////////////////////////////////
                          SET AUTHORITY
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanSetAuthority() public {
        MockAuthority newAuthority = new MockAuthority();

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit AuthorityUpdated(owner, newAuthority);
        authed.setAuthority(newAuthority);

        assertEq(address(authed.authority()), address(newAuthority));
    }

    function testAuthorizedUserCanSetAuthority() public {
        authority.setCanCall(user, address(authed), authed.setAuthority.selector, true);

        MockAuthority newAuthority = new MockAuthority();

        vm.prank(user);
        authed.setAuthority(newAuthority);

        assertEq(address(authed.authority()), address(newAuthority));
    }

    function testUnauthorizedUserCannotSetAuthority() public {
        vm.prank(user);
        vm.expectRevert();
        authed.setAuthority(Authority(address(0)));
    }

    function testSetAuthorityToZero() public {
        vm.prank(owner);
        authed.setAuthority(Authority(address(0)));

        assertEq(address(authed.authority()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                      REVERTING AUTHORITY
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanSetAuthorityWhenAuthorityReverts() public {
        vm.prank(owner);
        authed.setAuthority(bad);

        // Authority revert 时 owner 仍可更换（setAuthority 先判断 owner）
        MockAuthority good = new MockAuthority();
        vm.prank(owner);
        authed.setAuthority(good);

        assertEq(address(authed.authority()), address(good));
    }

    function testOwnerCannotCallProtectedWhenAuthorityReverts() public {
        vm.prank(owner);
        authed.setAuthority(bad);

        // Authority revert 导致 isAuthorized 整体revert，即使是 owner 也被阻断
        vm.prank(owner);
        vm.expectRevert("AUTHORITY_REVERTED");
        authed.protectedFunction();
    }

    /*//////////////////////////////////////////////////////////////
                      NO AUTHORITY (address(0))
    //////////////////////////////////////////////////////////////*/

    function testOnlyOwnerWorksWithoutAuthority() public {
        MockAuth noAuth = new MockAuth(owner, Authority(address(0)));

        vm.prank(owner);
        assertTrue(noAuth.protectedFunction());

        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        noAuth.protectedFunction();
    }
}

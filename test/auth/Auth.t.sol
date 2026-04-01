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

    // 验证构造函数正确设置 owner
    function testConstructorSetsOwner() public view {
        assertEq(authed.owner(), owner);
    }

    // 验证构造函数正确设置 authority
    function testConstructorSetsAuthority() public view {
        assertEq(address(authed.authority()), address(authority));
    }

    // 验证构造函数可以传入零地址作为 authority
    function testConstructorWithZeroAuthority() public {
        MockAuth noAuth = new MockAuth(owner, Authority(address(0)));
        assertEq(address(noAuth.authority()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          REQUIRES AUTH
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 可以调用受保护函数
    function testOwnerCanCallProtected() public {
        vm.prank(owner);
        assertTrue(authed.protectedFunction());
    }

    // 正向：被 Authority 授权的用户可以调用受保护函数
    function testAuthorizedUserCanCallProtected() public {
        authority.setCanCall(user, address(authed), MockAuth.protectedFunction.selector, true);

        vm.prank(user);
        assertTrue(authed.protectedFunction());
    }

    // 反向：未授权用户调用受保护函数
    function testUnauthorizedUserCannotCallProtected() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        authed.protectedFunction();
    }

    // 正向：任何人都可以调用不受保护的函数
    function testAnyoneCanCallUnprotected() public {
        vm.prank(user);
        assertTrue(authed.unprotectedFunction());
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 可以转移所有权，验证事件和状态
    function testOwnerCanTransferOwnership() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        authed.transferOwnership(newOwner);

        assertEq(authed.owner(), newOwner);
    }

    // 正向：被 Authority 授权的用户也可以转移所有权
    function testAuthorizedUserCanTransferOwnership() public {
        authority.setCanCall(user, address(authed), authed.transferOwnership.selector, true);

        vm.prank(user);
        authed.transferOwnership(newOwner);

        assertEq(authed.owner(), newOwner);
    }

    // 反向：未授权用户不能转移所有权
    function testUnauthorizedUserCannotTransferOwnership() public {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        authed.transferOwnership(newOwner);
    }

    // 边界：可以将所有权转移给零地址（放弃所有权）
    function testTransferOwnershipToZeroAddress() public {
        vm.prank(owner);
        authed.transferOwnership(address(0));
        assertEq(authed.owner(), address(0));
    }

    // 正向：转移所有权后旧 owner 失去权限
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

    // 正向：owner 可以更换 Authority，验证事件和状态
    function testOwnerCanSetAuthority() public {
        MockAuthority newAuthority = new MockAuthority();

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit AuthorityUpdated(owner, newAuthority);
        authed.setAuthority(newAuthority);

        assertEq(address(authed.authority()), address(newAuthority));
    }

    // 正向：被 Authority 授权的用户也可以更换 Authority
    function testAuthorizedUserCanSetAuthority() public {
        authority.setCanCall(user, address(authed), authed.setAuthority.selector, true);

        MockAuthority newAuthority = new MockAuthority();

        vm.prank(user);
        authed.setAuthority(newAuthority);

        assertEq(address(authed.authority()), address(newAuthority));
    }

    // 反向：未授权用户不能更换 Authority
    function testUnauthorizedUserCannotSetAuthority() public {
        vm.prank(user);
        vm.expectRevert();
        authed.setAuthority(Authority(address(0)));
    }

    // 边界：可以将 Authority 设为零地址（禁用外部授权）
    function testSetAuthorityToZero() public {
        vm.prank(owner);
        authed.setAuthority(Authority(address(0)));

        assertEq(address(authed.authority()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                      REVERTING AUTHORITY
    //////////////////////////////////////////////////////////////*/

    // 正向：Authority revert 时 owner 仍可更换 Authority（setAuthority 先判断 owner）
    function testOwnerCanSetAuthorityWhenAuthorityReverts() public {
        vm.prank(owner);
        authed.setAuthority(bad);

        // Authority revert 时 owner 仍可更换（setAuthority 先判断 owner）
        MockAuthority good = new MockAuthority();
        vm.prank(owner);
        authed.setAuthority(good);

        assertEq(address(authed.authority()), address(good));
    }

    // 反向：Authority revert 导致 isAuthorized 整体 revert，即使是 owner 也被阻断
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

    // 正向：无 Authority 时只有 owner 可以调用受保护函数，其他人 revert
    function testOnlyOwnerWorksWithoutAuthority() public {
        MockAuth noAuth = new MockAuth(owner, Authority(address(0)));

        vm.prank(owner);
        assertTrue(noAuth.protectedFunction());

        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        noAuth.protectedFunction();
    }
}

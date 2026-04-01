// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {RolesAuthority} from "solmate/auth/authorities/RolesAuthority.sol";

/// @dev 被保护的目标合约，用于端到端验证
contract Target is Auth {
    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

    function protectedFunc() external view requiresAuth returns (bool) {
        return true;
    }

    function anotherFunc() external view requiresAuth returns (bool) {
        return true;
    }
}

contract RolesAuthorityTest is Test {
    RolesAuthority authority;
    Target target;

    address deployer = address(this);
    address owner = address(0xA);
    address alice = address(0xB);
    address bob = address(0xC);

    uint8 constant ROLE_0 = 0;
    uint8 constant ROLE_1 = 1;
    uint8 constant ROLE_2 = 2;
    uint8 constant ROLE_255 = 255;

    bytes4 protectedSig = Target.protectedFunc.selector;
    bytes4 anotherSig = Target.anotherFunc.selector;

    function setUp() public {
        authority = new RolesAuthority(owner, Authority(address(0)));
        target = new Target(owner, authority);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // 验证构造函数正确设置 owner
    function testConstructorSetsOwner() public view {
        assertEq(authority.owner(), owner);
    }

    // 验证构造函数正确设置 authority 为零地址
    function testConstructorSetsAuthority() public view {
        assertEq(address(authority.authority()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                           SET USER ROLE
    //////////////////////////////////////////////////////////////*/

    // 正向：owner 给用户分配角色，验证事件和状态
    function testSetUserRole() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit RolesAuthority.UserRoleUpdated(alice, ROLE_0, true);
        authority.setUserRole(alice, ROLE_0, true);

        assertTrue(authority.doesUserHaveRole(alice, ROLE_0));
    }

    // 正向：给同一用户分配多个角色，互不干扰
    function testSetMultipleRoles() public {
        vm.startPrank(owner);
        authority.setUserRole(alice, ROLE_0, true);
        authority.setUserRole(alice, ROLE_1, true);
        authority.setUserRole(alice, ROLE_2, true);
        vm.stopPrank();

        assertTrue(authority.doesUserHaveRole(alice, ROLE_0));
        assertTrue(authority.doesUserHaveRole(alice, ROLE_1));
        assertTrue(authority.doesUserHaveRole(alice, ROLE_2));
    }

    // 正向：撤销一个角色，其他角色不受影响
    function testRevokeUserRole() public {
        vm.startPrank(owner);
        authority.setUserRole(alice, ROLE_0, true);
        authority.setUserRole(alice, ROLE_1, true);

        // 撤销 ROLE_0，ROLE_1 不受影响
        vm.expectEmit(true, true, false, true);
        emit RolesAuthority.UserRoleUpdated(alice, ROLE_0, false);
        authority.setUserRole(alice, ROLE_0, false);
        vm.stopPrank();

        assertFalse(authority.doesUserHaveRole(alice, ROLE_0));
        assertTrue(authority.doesUserHaveRole(alice, ROLE_1));
    }

    // 边界：分配 role 255（最大值）
    function testSetUserRoleBoundary255() public {
        vm.prank(owner);
        authority.setUserRole(alice, ROLE_255, true);

        assertTrue(authority.doesUserHaveRole(alice, ROLE_255));
        assertFalse(authority.doesUserHaveRole(alice, ROLE_0));
    }

    // 反向：非 owner 不能分配角色
    function testNonOwnerCannotSetUserRole() public {
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        authority.setUserRole(alice, ROLE_0, true);
    }

    /*//////////////////////////////////////////////////////////////
                       DOES USER HAVE ROLE
    //////////////////////////////////////////////////////////////*/

    // 默认状态下用户没有任何角色
    function testDoesUserHaveRoleReturnsFalseByDefault() public view {
        assertFalse(authority.doesUserHaveRole(alice, ROLE_0));
    }

    // 分配角色后只有对应角色返回 true
    function testDoesUserHaveRoleAfterGrant() public {
        vm.prank(owner);
        authority.setUserRole(alice, ROLE_2, true);

        assertTrue(authority.doesUserHaveRole(alice, ROLE_2));
        assertFalse(authority.doesUserHaveRole(alice, ROLE_0));
        assertFalse(authority.doesUserHaveRole(alice, ROLE_1));
    }

    /*//////////////////////////////////////////////////////////////
                       SET ROLE CAPABILITY
    //////////////////////////////////////////////////////////////*/

    // 正向：设置角色能力，验证事件和状态
    function testSetRoleCapability() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit RolesAuthority.RoleCapabilityUpdated(ROLE_0, address(target), protectedSig, true);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);

        assertTrue(authority.doesRoleHaveCapability(ROLE_0, address(target), protectedSig));
    }

    // 正向：多个角色拥有同一函数能力
    function testSetMultipleRoleCapabilities() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setRoleCapability(ROLE_1, address(target), protectedSig, true);
        vm.stopPrank();

        assertTrue(authority.doesRoleHaveCapability(ROLE_0, address(target), protectedSig));
        assertTrue(authority.doesRoleHaveCapability(ROLE_1, address(target), protectedSig));
    }

    // 正向：撤销一个角色的能力，其他角色不受影响
    function testRevokeRoleCapability() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setRoleCapability(ROLE_1, address(target), protectedSig, true);

        // 撤销 ROLE_0 的权限，ROLE_1 不受影响
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, false);
        vm.stopPrank();

        assertFalse(authority.doesRoleHaveCapability(ROLE_0, address(target), protectedSig));
        assertTrue(authority.doesRoleHaveCapability(ROLE_1, address(target), protectedSig));
    }

    // 边界：role 255 的能力设置
    function testSetRoleCapabilityBoundary255() public {
        vm.prank(owner);
        authority.setRoleCapability(ROLE_255, address(target), protectedSig, true);

        assertTrue(authority.doesRoleHaveCapability(ROLE_255, address(target), protectedSig));
        assertFalse(authority.doesRoleHaveCapability(ROLE_0, address(target), protectedSig));
    }

    // 反向：非 owner 不能设置角色能力
    function testNonOwnerCannotSetRoleCapability() public {
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
    }

    /*//////////////////////////////////////////////////////////////
                    DOES ROLE HAVE CAPABILITY
    //////////////////////////////////////////////////////////////*/

    // 默认状态下角色没有任何能力
    function testDoesRoleHaveCapabilityReturnsFalseByDefault() public view {
        assertFalse(authority.doesRoleHaveCapability(ROLE_0, address(target), protectedSig));
    }

    /*//////////////////////////////////////////////////////////////
                      SET PUBLIC CAPABILITY
    //////////////////////////////////////////////////////////////*/

    // 正向：设置公开能力，验证事件和状态
    function testSetPublicCapability() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit RolesAuthority.PublicCapabilityUpdated(address(target), protectedSig, true);
        authority.setPublicCapability(address(target), protectedSig, true);

        assertTrue(authority.isCapabilityPublic(address(target), protectedSig));
    }

    // 正向：撤销公开能力
    function testRevokePublicCapability() public {
        vm.startPrank(owner);
        authority.setPublicCapability(address(target), protectedSig, true);
        authority.setPublicCapability(address(target), protectedSig, false);
        vm.stopPrank();

        assertFalse(authority.isCapabilityPublic(address(target), protectedSig));
    }

    // 反向：非 owner 不能设置公开能力
    function testNonOwnerCannotSetPublicCapability() public {
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        authority.setPublicCapability(address(target), protectedSig, true);
    }

    /*//////////////////////////////////////////////////////////////
                            CAN CALL
    //////////////////////////////////////////////////////////////*/

    // 默认状态下 canCall 返回 false
    function testCanCallReturnsFalseByDefault() public view {
        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 用户拥有对应角色 + 角色拥有该函数能力 → 通过
    function testCanCallWithRole() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));
    }

    // 函数被设为公开 → 任何人通过
    function testCanCallWithPublicCapability() public {
        vm.prank(owner);
        authority.setPublicCapability(address(target), protectedSig, true);

        // 任何人都能通过
        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertTrue(authority.canCall(bob, address(target), protectedSig));
        assertTrue(authority.canCall(owner, address(target), protectedSig));
    }

    // 角色不匹配 → 不通过
    function testCanCallFailsWithWrongRole() public {
        vm.startPrank(owner);
        // 函数需要 ROLE_1，但 alice 只有 ROLE_0
        authority.setRoleCapability(ROLE_1, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 函数不匹配 → 不通过
    function testCanCallFailsWithWrongFunction() public {
        vm.startPrank(owner);
        // alice 有 ROLE_0，ROLE_0 可调用 protectedSig，但不能调用 anotherSig
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertFalse(authority.canCall(alice, address(target), anotherSig));
    }

    // 多个角色重叠匹配 → 通过
    function testCanCallWithMultipleOverlappingRoles() public {
        vm.startPrank(owner);
        // 函数允许 ROLE_1 和 ROLE_2
        authority.setRoleCapability(ROLE_1, address(target), protectedSig, true);
        authority.setRoleCapability(ROLE_2, address(target), protectedSig, true);
        // alice 有 ROLE_0 和 ROLE_2 → ROLE_2 重叠 → 通过
        authority.setUserRole(alice, ROLE_0, true);
        authority.setUserRole(alice, ROLE_2, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));
    }

    // 撤销角色后权限消失
    function testCanCallAfterRoleRevoked() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));

        // 撤销角色后权限消失
        vm.prank(owner);
        authority.setUserRole(alice, ROLE_0, false);

        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 撤销角色能力后，即使用户有角色也无法调用
    function testCanCallAfterCapabilityRevoked() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));

        // 撤销角色权限后，即使用户有角色也无法调用
        vm.prank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, false);

        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    /*//////////////////////////////////////////////////////////////
                      END-TO-END INTEGRATION
    //////////////////////////////////////////////////////////////*/

    // 端到端：有角色权限的用户成功调用受保护函数
    function testEndToEndAuthorizedCall() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        // alice 实际调用 target 的受保护函数
        vm.prank(alice);
        assertTrue(target.protectedFunc());
    }

    // 端到端：无角色权限的用户调用受保护函数 → revert
    function testEndToEndUnauthorizedCall() public {
        // bob 没有任何角色，调用受保护函数应 revert
        vm.prank(bob);
        vm.expectRevert("UNAUTHORIZED");
        target.protectedFunc();
    }

    // 端到端：公开函数任何人可调用
    function testEndToEndPublicCapability() public {
        vm.prank(owner);
        authority.setPublicCapability(address(target), protectedSig, true);

        // 任何人都可以调用
        vm.prank(alice);
        assertTrue(target.protectedFunc());
    }

    // 端到端：owner 不需要角色也能调用（Auth.isAuthorized 兜底）
    function testEndToEndOwnerAlwaysPasses() public {
        // owner 不需要任何角色也能调用（Auth.isAuthorized 兜底）
        vm.prank(owner);
        assertTrue(target.protectedFunc());
    }

    // 端到端：完整的授权 → 撤销流程
    function testEndToEndRevokeFlowComplete() public {
        // 1. 配置权限
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_1, address(target), protectedSig, true);
        authority.setUserRole(alice, ROLE_1, true);
        vm.stopPrank();

        // 2. alice 可以调用
        vm.prank(alice);
        assertTrue(target.protectedFunc());

        // 3. 撤销 alice 的角色
        vm.prank(owner);
        authority.setUserRole(alice, ROLE_1, false);

        // 4. alice 不再能调用
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        target.protectedFunc();
    }

    // 端到端：不同 target 的权限互相隔离
    function testEndToEndMultipleTargets() public {
        // 部署第二个目标合约
        Target target2 = new Target(owner, authority);

        vm.startPrank(owner);
        // ROLE_0 只能调 target 的 protectedFunc
        authority.setRoleCapability(ROLE_0, address(target), protectedSig, true);
        // ROLE_1 只能调 target2 的 protectedFunc
        authority.setRoleCapability(ROLE_1, address(target2), protectedSig, true);

        authority.setUserRole(alice, ROLE_0, true);
        authority.setUserRole(bob, ROLE_1, true);
        vm.stopPrank();

        // alice 可以调 target，不能调 target2
        vm.prank(alice);
        assertTrue(target.protectedFunc());

        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        target2.protectedFunc();

        // bob 可以调 target2，不能调 target
        vm.prank(bob);
        assertTrue(target2.protectedFunc());

        vm.prank(bob);
        vm.expectRevert("UNAUTHORIZED");
        target.protectedFunc();
    }

    /*//////////////////////////////////////////////////////////////
                     AUTHORITY MANAGES ITSELF
    //////////////////////////////////////////////////////////////*/

    // 自治模式：通过角色权限让非 owner 也能管理角色
    function testAuthorizedUserCanManageRoles() public {
        vm.startPrank(owner);
        // 关键：让 authority 以自身作为 authority（自治模式）
        // 否则 authority 字段为 address(0)，requiresAuth 只认 owner
        authority.setAuthority(authority);

        // 授权 ROLE_0 可以调用 authority.setUserRole
        authority.setRoleCapability(ROLE_0, address(authority), RolesAuthority.setUserRole.selector, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        // alice 现在可以给 bob 分配角色（通过角色权限，而非 owner）
        vm.prank(alice);
        authority.setUserRole(bob, ROLE_1, true);

        assertTrue(authority.doesUserHaveRole(bob, ROLE_1));
    }

    // 转移所有权后新 owner 可管理，旧 owner 不能
    function testTransferOwnership() public {
        vm.prank(owner);
        authority.transferOwnership(alice);

        assertEq(authority.owner(), alice);

        // 新 owner 可以管理
        vm.prank(alice);
        authority.setUserRole(bob, ROLE_0, true);
        assertTrue(authority.doesUserHaveRole(bob, ROLE_0));

        // 旧 owner 不再能管理
        vm.prank(owner);
        vm.expectRevert("UNAUTHORIZED");
        authority.setUserRole(bob, ROLE_1, true);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {MultiRolesAuthority} from "solmate/auth/authorities/MultiRolesAuthority.sol";

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

/// @dev 用于测试 setTargetCustomAuthority 的自定义 Authority
/// 始终返回 true（全部放行）
contract AllowAllAuthority is Authority {
    function canCall(address, address, bytes4) external pure override returns (bool) {
        return true;
    }
}

/// @dev 用于测试 setTargetCustomAuthority 的自定义 Authority
/// 始终返回 false（全部拒绝）
contract DenyAllAuthority is Authority {
    function canCall(address, address, bytes4) external pure override returns (bool) {
        return false;
    }
}

contract MultiRolesAuthorityTest is Test {
    MultiRolesAuthority authority;
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
        authority = new MultiRolesAuthority(owner, Authority(address(0)));
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
        emit MultiRolesAuthority.UserRoleUpdated(alice, ROLE_0, true);
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

        // 撤销 ROLE_0
        vm.expectEmit(true, true, false, true);
        emit MultiRolesAuthority.UserRoleUpdated(alice, ROLE_0, false);
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
    // 注意：MultiRolesAuthority 的 setRoleCapability 没有 target 参数（target agnostic）
    function testSetRoleCapability() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit MultiRolesAuthority.RoleCapabilityUpdated(ROLE_0, protectedSig, true);
        authority.setRoleCapability(ROLE_0, protectedSig, true);

        assertTrue(authority.doesRoleHaveCapability(ROLE_0, protectedSig));
    }

    // 正向：多个角色拥有同一函数能力
    function testSetMultipleRoleCapabilities() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setRoleCapability(ROLE_1, protectedSig, true);
        vm.stopPrank();

        assertTrue(authority.doesRoleHaveCapability(ROLE_0, protectedSig));
        assertTrue(authority.doesRoleHaveCapability(ROLE_1, protectedSig));
    }

    // 正向：撤销一个角色的能力，其他角色不受影响
    function testRevokeRoleCapability() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setRoleCapability(ROLE_1, protectedSig, true);

        authority.setRoleCapability(ROLE_0, protectedSig, false);
        vm.stopPrank();

        assertFalse(authority.doesRoleHaveCapability(ROLE_0, protectedSig));
        assertTrue(authority.doesRoleHaveCapability(ROLE_1, protectedSig));
    }

    // 边界：role 255 的能力设置
    function testSetRoleCapabilityBoundary255() public {
        vm.prank(owner);
        authority.setRoleCapability(ROLE_255, protectedSig, true);

        assertTrue(authority.doesRoleHaveCapability(ROLE_255, protectedSig));
        assertFalse(authority.doesRoleHaveCapability(ROLE_0, protectedSig));
    }

    // 反向：非 owner 不能设置角色能力
    function testNonOwnerCannotSetRoleCapability() public {
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        authority.setRoleCapability(ROLE_0, protectedSig, true);
    }

    /*//////////////////////////////////////////////////////////////
                    DOES ROLE HAVE CAPABILITY
    //////////////////////////////////////////////////////////////*/

    // 默认状态下角色没有任何能力
    function testDoesRoleHaveCapabilityReturnsFalseByDefault() public view {
        assertFalse(authority.doesRoleHaveCapability(ROLE_0, protectedSig));
    }

    /*//////////////////////////////////////////////////////////////
                      SET PUBLIC CAPABILITY
    //////////////////////////////////////////////////////////////*/

    // 正向：设置公开能力，验证事件和状态
    // 注意：MultiRolesAuthority 的 setPublicCapability 没有 target 参数（target agnostic）
    function testSetPublicCapability() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit MultiRolesAuthority.PublicCapabilityUpdated(protectedSig, true);
        authority.setPublicCapability(protectedSig, true);

        assertTrue(authority.isCapabilityPublic(protectedSig));
    }

    // 正向：撤销公开能力
    function testRevokePublicCapability() public {
        vm.startPrank(owner);
        authority.setPublicCapability(protectedSig, true);
        authority.setPublicCapability(protectedSig, false);
        vm.stopPrank();

        assertFalse(authority.isCapabilityPublic(protectedSig));
    }

    // 反向：非 owner 不能设置公开能力
    function testNonOwnerCannotSetPublicCapability() public {
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        authority.setPublicCapability(protectedSig, true);
    }

    /*//////////////////////////////////////////////////////////////
                   SET TARGET CUSTOM AUTHORITY
    //////////////////////////////////////////////////////////////*/

    // 正向：为目标合约设置自定义 Authority，验证事件和状态
    function testSetTargetCustomAuthority() public {
        AllowAllAuthority customAuth = new AllowAllAuthority();

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit MultiRolesAuthority.TargetCustomAuthorityUpdated(address(target), Authority(address(customAuth)));
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));

        assertEq(address(authority.getTargetCustomAuthority(address(target))), address(customAuth));
    }

    // 正向：清除自定义 Authority（传入 address(0)）
    function testClearTargetCustomAuthority() public {
        AllowAllAuthority customAuth = new AllowAllAuthority();

        vm.startPrank(owner);
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
        // 清除
        authority.setTargetCustomAuthority(address(target), Authority(address(0)));
        vm.stopPrank();

        assertEq(address(authority.getTargetCustomAuthority(address(target))), address(0));
    }

    // 反向：非 owner 不能设置自定义 Authority
    function testNonOwnerCannotSetTargetCustomAuthority() public {
        AllowAllAuthority customAuth = new AllowAllAuthority();

        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
    }

    /*//////////////////////////////////////////////////////////////
                            CAN CALL
    //////////////////////////////////////////////////////////////*/

    // 默认状态下 canCall 返回 false
    function testCanCallReturnsFalseByDefault() public view {
        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 路径 3：用户拥有对应角色 + 角色拥有该函数能力 → 通过
    function testCanCallWithRole() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));
    }

    // 路径 2：函数被设为公开 → 任何人通过
    function testCanCallWithPublicCapability() public {
        vm.prank(owner);
        authority.setPublicCapability(protectedSig, true);

        // 任何人都能通过
        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertTrue(authority.canCall(bob, address(target), protectedSig));
        assertTrue(authority.canCall(owner, address(target), protectedSig));
    }

    // 路径 2 验证：公开能力是 target agnostic 的，对不同 target 都生效
    function testPublicCapabilityIsTargetAgnostic() public {
        Target target2 = new Target(owner, authority);

        vm.prank(owner);
        authority.setPublicCapability(protectedSig, true);

        // 同一函数签名，对不同 target 都公开
        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertTrue(authority.canCall(alice, address(target2), protectedSig));
    }

    // 路径 1：自定义 Authority 放行 → 通过（即使没有角色和公开能力）
    function testCanCallWithCustomAuthorityAllowAll() public {
        AllowAllAuthority customAuth = new AllowAllAuthority();

        vm.prank(owner);
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));

        // alice 没有任何角色，但自定义 Authority 全部放行
        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertTrue(authority.canCall(bob, address(target), protectedSig));
    }

    // 路径 1：自定义 Authority 拒绝 → 不通过（即使有角色和公开能力）
    function testCanCallWithCustomAuthorityDenyAll() public {
        DenyAllAuthority customAuth = new DenyAllAuthority();

        vm.startPrank(owner);
        // 设置角色和公开能力
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        authority.setPublicCapability(protectedSig, true);
        // 但目标合约有自定义 Authority（全部拒绝），优先级最高
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
        vm.stopPrank();

        // 自定义 Authority 拒绝 → 角色和公开能力都不生效
        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 路径 1 验证：自定义 Authority 只影响指定 target，不影响其他 target
    function testCustomAuthorityOnlyAffectsSpecificTarget() public {
        Target target2 = new Target(owner, authority);
        DenyAllAuthority customAuth = new DenyAllAuthority();

        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        // 只对 target 设置拒绝全部的自定义 Authority
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
        vm.stopPrank();

        // target 被自定义 Authority 拒绝
        assertFalse(authority.canCall(alice, address(target), protectedSig));
        // target2 没有自定义 Authority，走正常的角色判断 → 通过
        assertTrue(authority.canCall(alice, address(target2), protectedSig));
    }

    // 清除自定义 Authority 后回退到角色/公开能力判断
    function testCanCallFallsBackAfterClearingCustomAuthority() public {
        DenyAllAuthority customAuth = new DenyAllAuthority();

        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
        vm.stopPrank();

        // 自定义 Authority 拒绝
        assertFalse(authority.canCall(alice, address(target), protectedSig));

        // 清除自定义 Authority
        vm.prank(owner);
        authority.setTargetCustomAuthority(address(target), Authority(address(0)));

        // 回退到角色判断 → 通过
        assertTrue(authority.canCall(alice, address(target), protectedSig));
    }

    // 角色不匹配 → 不通过
    function testCanCallFailsWithWrongRole() public {
        vm.startPrank(owner);
        // 函数需要 ROLE_1，但 alice 只有 ROLE_0
        authority.setRoleCapability(ROLE_1, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 函数不匹配 → 不通过
    function testCanCallFailsWithWrongFunction() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertFalse(authority.canCall(alice, address(target), anotherSig));
    }

    // 多个角色重叠匹配 → 通过
    function testCanCallWithMultipleOverlappingRoles() public {
        vm.startPrank(owner);
        // 函数允许 ROLE_1 和 ROLE_2
        authority.setRoleCapability(ROLE_1, protectedSig, true);
        authority.setRoleCapability(ROLE_2, protectedSig, true);
        // alice 有 ROLE_0 和 ROLE_2 → ROLE_2 重叠 → 通过
        authority.setUserRole(alice, ROLE_0, true);
        authority.setUserRole(alice, ROLE_2, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));
    }

    // 撤销角色后权限消失
    function testCanCallAfterRoleRevoked() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));

        vm.prank(owner);
        authority.setUserRole(alice, ROLE_0, false);

        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // 撤销角色能力后，即使用户有角色也无法调用
    function testCanCallAfterCapabilityRevoked() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        assertTrue(authority.canCall(alice, address(target), protectedSig));

        vm.prank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, false);

        assertFalse(authority.canCall(alice, address(target), protectedSig));
    }

    // target agnostic 验证：角色能力对所有 target 都生效
    function testRoleCapabilityIsTargetAgnostic() public {
        Target target2 = new Target(owner, authority);

        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        // 同一角色能力，对不同 target 都生效
        assertTrue(authority.canCall(alice, address(target), protectedSig));
        assertTrue(authority.canCall(alice, address(target2), protectedSig));
    }

    /*//////////////////////////////////////////////////////////////
                      END-TO-END INTEGRATION
    //////////////////////////////////////////////////////////////*/

    // 端到端：有角色权限的用户成功调用受保护函数
    function testEndToEndAuthorizedCall() public {
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        vm.prank(alice);
        assertTrue(target.protectedFunc());
    }

    // 端到端：无角色权限的用户调用受保护函数 → revert
    function testEndToEndUnauthorizedCall() public {
        vm.prank(bob);
        vm.expectRevert("UNAUTHORIZED");
        target.protectedFunc();
    }

    // 端到端：公开函数任何人可调用
    function testEndToEndPublicCapability() public {
        vm.prank(owner);
        authority.setPublicCapability(protectedSig, true);

        vm.prank(alice);
        assertTrue(target.protectedFunc());

        vm.prank(bob);
        assertTrue(target.protectedFunc());
    }

    // 端到端：owner 不需要角色也能调用（Auth.isAuthorized 兜底）
    function testEndToEndOwnerAlwaysPasses() public {
        vm.prank(owner);
        assertTrue(target.protectedFunc());
    }

    // 端到端：自定义 Authority（AllowAll）→ 任何人可调用该 target
    function testEndToEndCustomAuthorityAllowAll() public {
        AllowAllAuthority customAuth = new AllowAllAuthority();

        vm.prank(owner);
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));

        // alice 没有任何角色，但自定义 Authority 放行
        vm.prank(alice);
        assertTrue(target.protectedFunc());
    }

    // 端到端：自定义 Authority（DenyAll）→ 即使有角色也被拒绝
    // 注意：owner 走的是 Auth.isAuthorized 中 user == owner 的兜底，不受 canCall 影响
    function testEndToEndCustomAuthorityDenyAllBlocksRoleBearers() public {
        DenyAllAuthority customAuth = new DenyAllAuthority();

        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
        vm.stopPrank();

        // alice 有角色但被自定义 Authority 拒绝
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        target.protectedFunc();

        // owner 仍然可以（Auth.isAuthorized 兜底 user == owner）
        vm.prank(owner);
        assertTrue(target.protectedFunc());
    }

    // 端到端：完整的授权 → 撤销流程
    function testEndToEndRevokeFlowComplete() public {
        // 1. 配置权限
        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_1, protectedSig, true);
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

    // 端到端：target agnostic — 同一角色能力对多个 target 生效
    function testEndToEndTargetAgnostic() public {
        Target target2 = new Target(owner, authority);

        vm.startPrank(owner);
        // 只配置一次角色能力（没有 target 参数）
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        // alice 可以调用两个 target 的受保护函数
        vm.prank(alice);
        assertTrue(target.protectedFunc());

        vm.prank(alice);
        assertTrue(target2.protectedFunc());
    }

    // 端到端：对一个 target 设自定义 Authority，另一个走角色判断
    function testEndToEndMixCustomAuthorityAndRoles() public {
        Target target2 = new Target(owner, authority);
        DenyAllAuthority customAuth = new DenyAllAuthority();

        vm.startPrank(owner);
        authority.setRoleCapability(ROLE_0, protectedSig, true);
        authority.setUserRole(alice, ROLE_0, true);
        // 只对 target 设置拒绝全部
        authority.setTargetCustomAuthority(address(target), Authority(address(customAuth)));
        vm.stopPrank();

        // target 被自定义 Authority 拒绝
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        target.protectedFunc();

        // target2 走角色判断 → 通过
        vm.prank(alice);
        assertTrue(target2.protectedFunc());
    }

    /*//////////////////////////////////////////////////////////////
                     AUTHORITY MANAGES ITSELF
    //////////////////////////////////////////////////////////////*/

    // 自治模式：通过角色权限让非 owner 也能管理角色
    function testAuthorizedUserCanManageRoles() public {
        vm.startPrank(owner);
        // 让 authority 以自身为 authority（自治模式）
        authority.setAuthority(authority);

        // 授权 ROLE_0 可以调用 authority.setUserRole
        authority.setRoleCapability(ROLE_0, MultiRolesAuthority.setUserRole.selector, true);
        authority.setUserRole(alice, ROLE_0, true);
        vm.stopPrank();

        // alice 现在可以给 bob 分配角色
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

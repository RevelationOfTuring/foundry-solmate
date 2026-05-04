// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "src/tokens/MockERC20.sol";
import {MockERC4626} from "src/tokens/MockERC4626.sol";

contract ERC4626Test is Test {
    MockERC20 underlying;
    MockERC4626 vault;

    address alice = address(0xA);
    address bob = address(0xB);
    address carol = address(0xC);

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function setUp() public {
        underlying = new MockERC20("Underlying Token", "UT", 18);
        vault = new MockERC4626(underlying, "Vault Token", "vUT");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // 验证构造函数正确设置 name、symbol、decimals（继承自 asset）、asset 地址
    function testConstructor() public view {
        assertEq(vault.name(), "Vault Token");
        assertEq(vault.symbol(), "vUT");
        assertEq(vault.decimals(), underlying.decimals());
        assertEq(vault.decimals(), 18);
        assertEq(address(vault.asset()), address(underlying));
    }

    // 验证初始 totalSupply 和 totalAssets 均为 0
    function testConstructorInitialStateIsZero() public view {
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    // 边界：底层资产 decimals 不同（如 USDC 的 6 位）
    function testConstructorWithDifferentDecimals() public {
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockERC4626 usdcVault = new MockERC4626(usdc, "Vault USDC", "vUSDC");
        assertEq(usdcVault.decimals(), 6);
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // 正向：首次 deposit，1:1 映射，触发 Deposit 事件
    function testDeposit() public {
        underlying.mint(alice, 1000e18);

        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);

        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, alice, 1000e18, 1000e18);
        uint256 shares = vault.deposit(1000e18, alice);
        vm.stopPrank();

        assertEq(shares, 1000e18);
        assertEq(vault.balanceOf(alice), 1000e18);
        assertEq(vault.totalSupply(), 1000e18);
        assertEq(vault.totalAssets(), 1000e18);
        assertEq(underlying.balanceOf(alice), 0);
    }

    // 正向：deposit 给不同 receiver
    function testDepositToReceiver() public {
        underlying.mint(alice, 500e18);

        vm.startPrank(alice);
        underlying.approve(address(vault), 500e18);

        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, bob, 500e18, 500e18);
        vault.deposit(500e18, bob);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 500e18);
    }

    // 正向：多次 deposit，汇率不变（无收益时）
    function testDepositMultipleTimes() public {
        underlying.mint(alice, 1000e18);
        underlying.mint(bob, 500e18);

        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        underlying.approve(address(vault), 500e18);
        uint256 bobShares = vault.deposit(500e18, bob);
        vm.stopPrank();
        assertEq(bobShares, 500e18);

        assertEq(vault.totalSupply(), 1500e18);
        assertEq(vault.totalAssets(), 1500e18);
    }

    // 正向：有收益后 deposit，汇率变化
    function testDepositAfterYield() public {
        // alice 存入 1000
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // 模拟收益：直接转入 1000 底层资产到金库
        underlying.mint(address(vault), 1000e18);
        // 此时 totalAssets = 2000, totalSupply = 1000
        assertEq(vault.totalAssets(), 2000e18);
        assertEq(vault.totalSupply(), 1000e18);

        // bob 存入 2000
        underlying.mint(bob, 2000e18);
        vm.startPrank(bob);
        underlying.approve(address(vault), 2000e18);
        uint256 bobShares = vault.deposit(2000e18, bob);
        vm.stopPrank();

        // shares = 2000 * 1000 / 2000 = 1000
        assertEq(bobShares, 1000e18);
    }

    // 反向：存入非 0 资产，但向下取整导致 shares = 0 → revert（ZERO_SHARES）
    function testDepositZeroSharesReverts() public {
        // alice 存入 1 wei → 获得 1 share
        underlying.mint(alice, 1);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1);
        vault.deposit(1, alice);
        vm.stopPrank();
        // 状态：totalAssets = 1, totalSupply = 1

        // 模拟大额捐赠抬高汇率（不经 deposit，不获得份额）
        underlying.mint(address(vault), 1e18);
        // 状态：totalAssets = 1e18 + 1, totalSupply = 1
        // 每 share 价值 ≈ 1e18

        // bob 存入 1 wei → shares = 1 * 1 / (1e18 + 1) = 0（向下取整）→ revert
        underlying.mint(bob, 1);
        vm.startPrank(bob);
        underlying.approve(address(vault), 1);
        vm.expectRevert("ZERO_SHARES");
        vault.deposit(1, bob);
        vm.stopPrank();
    }

    // 反向：未授权 → revert
    function testDepositWithoutApprovalReverts() public {
        underlying.mint(alice, 1000e18);

        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1000e18, alice);
    }

    /*//////////////////////////////////////////////////////////////
                               MINT
    //////////////////////////////////////////////////////////////*/

    // 正向：首次 mint，1:1 映射，触发 Deposit 事件
    function testMint() public {
        underlying.mint(alice, 1000e18);

        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);

        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, alice, 1000e18, 1000e18);
        uint256 assets = vault.mint(1000e18, alice);
        vm.stopPrank();

        assertEq(assets, 1000e18);
        assertEq(vault.balanceOf(alice), 1000e18);
        assertEq(vault.totalSupply(), 1000e18);
        assertEq(vault.totalAssets(), 1000e18);
    }

    // 正向：mint 给不同 receiver
    function testMintToReceiver() public {
        underlying.mint(alice, 500e18);

        vm.startPrank(alice);
        underlying.approve(address(vault), 500e18);
        vault.mint(500e18, bob);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 500e18);
    }

    // 正向：有收益后 mint，向上取整多收资产
    function testMintAfterYield() public {
        // alice 存入 3
        underlying.mint(alice, 3e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 3e18);
        vault.deposit(3e18, alice);
        vm.stopPrank();

        // 模拟收益 7：totalAssets = 10, totalSupply = 3
        underlying.mint(address(vault), 7e18);

        // bob mint 2 shares → assets = 2 * 10 / 3 = 6.666... → mulDivUp → 6.666...7
        // 若向下取整则为 6.666...6，向上取整多收了 1 wei（凸显金库不吃亏）
        underlying.mint(bob, 7e18);
        vm.startPrank(bob);
        underlying.approve(address(vault), 7e18);
        uint256 assets = vault.mint(2e18, bob);
        vm.stopPrank();

        // 向上取整：比向下取整多 1 wei
        assertEq(assets, 6666666666666666667);
        assertEq(vault.balanceOf(bob), 2e18);
        assertEq(underlying.balanceOf(bob), 7e18 - 6666666666666666667);
    }

    // 边界：mint 0 shares
    function testMintZeroShares() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        uint256 assets = vault.mint(0, alice);
        vm.stopPrank();

        assertEq(assets, 0);
        assertEq(vault.balanceOf(alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                             WITHDRAW
    //////////////////////////////////////////////////////////////*/

    // 正向：withdraw 成功，触发 Withdraw 事件
    function testWithdraw() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, 500e18, 500e18);
        uint256 shares = vault.withdraw(500e18, alice, alice);
        vm.stopPrank();

        assertEq(shares, 500e18);
        assertEq(vault.balanceOf(alice), 500e18);
        assertEq(underlying.balanceOf(alice), 500e18);
        assertEq(vault.totalAssets(), 500e18);
    }

    // 正向：withdraw 给不同 receiver
    function testWithdrawToReceiver() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        vault.withdraw(500e18, bob, alice);
        vm.stopPrank();

        assertEq(underlying.balanceOf(bob), 500e18);
        assertEq(underlying.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), 500e18);
    }

    // 正向：代理 withdraw（消耗 allowance）
    function testWithdrawByProxy() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        // alice 授权 bob 500 份额的 allowance
        vault.approve(bob, 500e18);
        vm.stopPrank();

        // bob 代理提取
        vm.prank(bob);
        vault.withdraw(500e18, bob, alice);

        assertEq(underlying.balanceOf(bob), 500e18);
        assertEq(vault.balanceOf(alice), 500e18);
        assertEq(vault.allowance(alice, bob), 0);
    }

    // 正向：无限授权代理 withdraw 不扣减 allowance
    function testWithdrawByProxyInfiniteApproval() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        // 无限授权
        vault.approve(bob, type(uint256).max);
        vm.stopPrank();

        vm.prank(bob);
        vault.withdraw(500e18, carol, alice);

        assertEq(vault.allowance(alice, bob), type(uint256).max);
        assertEq(underlying.balanceOf(carol), 500e18);
    }

    // 反向：代理 withdraw 授权不足 → revert
    function testWithdrawByProxyInsufficientAllowance() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vault.approve(bob, 100e18);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert();
        vault.withdraw(500e18, bob, alice);
    }

    // 反向：withdraw 超过余额 → revert
    function testWithdrawInsufficientBalance() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1001e18);
        vault.deposit(1000e18, alice);

        vm.expectRevert();
        vault.withdraw(1001e18, alice, alice);
        vm.stopPrank();
    }

    // 正向：withdraw 全部余额
    function testWithdrawAll() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        vault.withdraw(1000e18, alice, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(underlying.balanceOf(alice), 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                              REDEEM
    //////////////////////////////////////////////////////////////*/

    // 正向：redeem 成功，触发 Withdraw 事件
    function testRedeem() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, 500e18, 500e18);
        uint256 assets = vault.redeem(500e18, alice, alice);
        vm.stopPrank();

        assertEq(assets, 500e18);
        assertEq(vault.balanceOf(alice), 500e18);
        assertEq(underlying.balanceOf(alice), 500e18);
    }

    // 正向：redeem 给不同 receiver
    function testRedeemToReceiver() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        vault.redeem(500e18, bob, alice);
        vm.stopPrank();

        assertEq(underlying.balanceOf(bob), 500e18);
        assertEq(vault.balanceOf(alice), 500e18);
    }

    // 正向：代理 redeem（消耗 allowance）
    function testRedeemByProxy() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vault.approve(bob, 500e18);
        vm.stopPrank();

        vm.prank(bob);
        vault.redeem(500e18, carol, alice);

        assertEq(underlying.balanceOf(carol), 500e18);
        assertEq(vault.balanceOf(alice), 500e18);
        assertEq(vault.allowance(alice, bob), 0);
    }

    // 正向：无限授权代理 redeem 不扣减 allowance
    function testRedeemByProxyInfiniteApproval() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        // 无限授权
        vault.approve(bob, type(uint256).max);
        vm.stopPrank();

        vm.prank(bob);
        vault.redeem(500e18, carol, alice);

        assertEq(vault.allowance(alice, bob), type(uint256).max);
    }

    // 反向：代理 redeem 授权不足 → revert
    function testRedeemByProxyInsufficientAllowance() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vault.approve(bob, 100e18);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert();
        vault.redeem(500e18, bob, alice);
    }

    // 反向：redeem 超过余额 → revert
    function testRedeemInsufficientBalance() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1001e18);
        vault.deposit(1000e18, alice);

        vm.expectRevert();
        vault.redeem(1001e18, alice, alice);
        vm.stopPrank();
    }

    // 反向：redeem 结果为 0 资产 → revert（ZERO_ASSETS）
    // ZERO_ASSETS 在正常使用中极难触发（需要 totalAssets << totalSupply，即金库亏损）
    // 此处用 redeem(0) 验证 require 防护逻辑
    function testRedeemZeroAssetsReverts() public {
        underlying.mint(alice, 1e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);

        vm.expectRevert("ZERO_ASSETS");
        vault.redeem(0, alice, alice);
        vm.stopPrank();
    }

    // 正向：redeem 全部份额
    function testRedeemAll() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        uint256 assets = vault.redeem(1000e18, alice, alice);
        vm.stopPrank();

        assertEq(assets, 1000e18);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(underlying.balanceOf(alice), 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    // 正向：totalAssets 反映金库余额
    function testTotalAssets() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 1000e18);

        // 模拟收益
        underlying.mint(address(vault), 500e18);
        assertEq(vault.totalAssets(), 1500e18);
    }

    // 正向：convertToShares 首次 1:1
    function testConvertToSharesEmpty() public view {
        assertEq(vault.convertToShares(1000e18), 1000e18);
    }

    // 正向：convertToAssets 首次 1:1
    function testConvertToAssetsEmpty() public view {
        assertEq(vault.convertToAssets(1000e18), 1000e18);
    }

    // 正向：convertToShares 有收益后汇率变化
    function testConvertToSharesAfterYield() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // 模拟收益：totalAssets = 2000, totalSupply = 1000
        underlying.mint(address(vault), 1000e18);

        // 2000 assets → shares = 2000 * 1000 / 2000 = 1000
        assertEq(vault.convertToShares(2000e18), 1000e18);
        // 1 wei assets → shares = 1 wei * 1000 / 2000 = 0
        assertEq(vault.convertToShares(1), 0);
    }

    // 正向：convertToAssets 有收益后汇率变化
    function testConvertToAssetsAfterYield() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // 模拟收益：totalAssets = 2000, totalSupply = 1000
        underlying.mint(address(vault), 1000e18);

        // 1000 shares → assets = 1000 * 2000 / 1000 = 2000
        assertEq(vault.convertToAssets(1000e18), 2000e18);
        // 1 wei shares → assets = 1 wei * 2000 / 1000 = 2 wei
        assertEq(vault.convertToAssets(1), 2);
    }

    // 正向：convertToShares 和 convertToAssets 互为反函数（无收益时）
    function testConvertRoundTrip() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        uint256 shares = vault.convertToShares(500e18);
        uint256 assets = vault.convertToAssets(shares);
        assertEq(assets, 500e18);
    }

    /*//////////////////////////////////////////////////////////////
                          PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // 正向：previewDeposit 与 convertToShares 结果一致
    function testPreviewDepositMatchesConvert() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        underlying.mint(address(vault), 500e18);

        assertEq(vault.previewDeposit(1000e18), vault.convertToShares(1000e18));
    }

    // 正向：previewRedeem 与 convertToAssets 结果一致
    function testPreviewRedeemMatchesConvert() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        underlying.mint(address(vault), 500e18);

        assertEq(vault.previewRedeem(500e18), vault.convertToAssets(500e18));
    }

    // 正向：previewMint 向上取整（>= convertToAssets）
    function testPreviewMintRoundsUp() public {
        underlying.mint(alice, 3e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 3e18);
        vault.deposit(3e18, alice);
        vm.stopPrank();

        // 制造非整除的汇率：totalAssets = 10, totalSupply = 3
        underlying.mint(address(vault), 7e18);

        // previewMint(2 shares) = 2 * 10 / 3 = 6.666... → mulDivUp → 6.666...7（多 1 wei）
        uint256 previewAssets = vault.previewMint(2e18);
        // convertToAssets(2 shares) = 2 * 10 / 3 = 6.666... → mulDivDown → 6.666...6
        uint256 convertAssets = vault.convertToAssets(2e18);

        assertEq(previewAssets - convertAssets, 1);
    }

    // 正向：previewWithdraw 向上取整（>= convertToShares）
    function testPreviewWithdrawRoundsUp() public {
        underlying.mint(alice, 3e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 3e18);
        vault.deposit(3e18, alice);
        vm.stopPrank();

        // 制造非整除的汇率：totalAssets = 7, totalSupply = 3
        underlying.mint(address(vault), 4e18);

        // previewWithdraw(2 assets) = 2 * 3 / 7 = 0.857142857142857143 → mulDivUp → 多 1 wei
        uint256 previewShares = vault.previewWithdraw(2e18);
        // convertToShares(2 assets) = 2 * 3 / 7 = 0.857142857142857142 → mulDivDown
        uint256 convertShares = vault.convertToShares(2e18);

        assertEq(previewShares - convertShares, 1);
    }

    // 正向：previewDeposit 返回实际 deposit 获得的份额
    function testPreviewDepositMatchesActual() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(500e18, alice);

        uint256 preview = vault.previewDeposit(500e18);
        uint256 actual = vault.deposit(500e18, alice);
        vm.stopPrank();

        assertEq(preview, actual);
    }

    // 正向：previewMint 返回实际 mint 需要的资产
    function testPreviewMintMatchesActual() public {
        underlying.mint(alice, 2000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 2000e18);
        vault.deposit(500e18, alice);

        uint256 preview = vault.previewMint(500e18);
        uint256 actual = vault.mint(500e18, alice);
        vm.stopPrank();

        assertEq(preview, actual);
    }

    // 正向：previewWithdraw 返回实际 withdraw 销毁的份额
    function testPreviewWithdrawMatchesActual() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        uint256 preview = vault.previewWithdraw(500e18);
        uint256 actual = vault.withdraw(500e18, alice, alice);
        vm.stopPrank();

        assertEq(preview, actual);
    }

    // 正向：previewRedeem 返回实际 redeem 获得的资产
    function testPreviewRedeemMatchesActual() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);

        uint256 preview = vault.previewRedeem(500e18);
        uint256 actual = vault.redeem(500e18, alice, alice);
        vm.stopPrank();

        assertEq(preview, actual);
    }

    /*//////////////////////////////////////////////////////////////
                          MAX FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // 正向：maxDeposit 默认无上限
    function testMaxDeposit() public view {
        assertEq(vault.maxDeposit(alice), type(uint256).max);
    }

    // 正向：maxMint 默认无上限
    function testMaxMint() public view {
        assertEq(vault.maxMint(alice), type(uint256).max);
    }

    // 正向：maxWithdraw 等于 convertToAssets(balance)
    function testMaxWithdraw() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        assertEq(vault.maxWithdraw(alice), vault.convertToAssets(vault.balanceOf(alice)));
        assertEq(vault.maxWithdraw(alice), 1000e18);
    }

    // 正向：maxRedeem 等于 balanceOf
    function testMaxRedeem() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        assertEq(vault.maxRedeem(alice), vault.balanceOf(alice));
        assertEq(vault.maxRedeem(alice), 1000e18);
    }

    // 边界：无份额时 maxWithdraw 和 maxRedeem 都是 0
    function testMaxWithdrawAndRedeemZeroBalance() public view {
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxRedeem(alice), 0);
    }

    // 正向：maxWithdraw 随收益增长
    function testMaxWithdrawAfterYield() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // 模拟收益
        underlying.mint(address(vault), 500e18);

        // maxWithdraw 应增长到 1500
        assertEq(vault.maxWithdraw(alice), 1500e18);
        // maxRedeem 不变（份额数量没变）
        assertEq(vault.maxRedeem(alice), 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                        ROUNDING INVARIANTS
    //////////////////////////////////////////////////////////////*/

    // 舍入不变量：deposit 后立即 redeem，用户不应获利
    function testRoundingDepositRedeem() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // 模拟收益制造非整除汇率
        underlying.mint(address(vault), 333e18);

        uint256 bobDeposit = 100e18;
        underlying.mint(bob, bobDeposit);
        vm.startPrank(bob);
        underlying.approve(address(vault), bobDeposit);
        uint256 shares = vault.deposit(bobDeposit, bob);
        uint256 assetsBack = vault.redeem(shares, bob, bob);
        vm.stopPrank();

        // 取出的不应超过存入的（金库不吃亏）
        assertLe(assetsBack, bobDeposit);
    }

    // 舍入不变量：mint 后立即 withdraw，用户不应获利
    function testRoundingMintWithdraw() public {
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // 模拟收益制造非整除汇率
        underlying.mint(address(vault), 333e18);

        uint256 sharesToMint = 100e18;
        underlying.mint(bob, type(uint128).max);
        vm.startPrank(bob);
        underlying.approve(address(vault), type(uint128).max);
        uint256 assetsPaid = vault.mint(sharesToMint, bob);
        uint256 assetsBack = vault.redeem(sharesToMint, bob, bob);
        vm.stopPrank();

        // 取出的不应超过存入的
        assertLe(assetsBack, assetsPaid);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT/WITHDRAW ROUND TRIP
    //////////////////////////////////////////////////////////////*/

    // 正向：完整的存取流程——deposit + yield + withdraw
    function testFullLifecycle() public {
        // alice deposit 1000
        underlying.mint(alice, 1000e18);
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e18);
        vault.deposit(1000e18, alice);
        vm.stopPrank();

        // bob deposit 500
        underlying.mint(bob, 500e18);
        vm.startPrank(bob);
        underlying.approve(address(vault), 500e18);
        vault.deposit(500e18, bob);
        vm.stopPrank();

        // 模拟 300 收益
        underlying.mint(address(vault), 300e18);
        // totalAssets = 1800, totalSupply = 1500

        // alice redeem 全部：assets = 1000 * 1800 / 1500 = 1200
        uint256 aliceShares = vault.balanceOf(alice);
        vm.prank(alice);
        uint256 aliceAssets = vault.redeem(aliceShares, alice, alice);
        assertEq(aliceAssets, 1200e18);

        // alice 赎回后：totalAssets = 600, totalSupply = 500
        // bob redeem 全部：assets = 500 * 600 / 500 = 600
        uint256 bobShares = vault.balanceOf(bob);
        vm.prank(bob);
        uint256 bobAssets = vault.redeem(bobShares, bob, bob);
        assertEq(bobAssets, 600e18);

        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // fuzz：deposit 任意数量，balanceOf 和 totalAssets 正确
    function testFuzzDeposit(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        underlying.mint(alice, amount);
        vm.startPrank(alice);
        underlying.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.totalSupply(), shares);
    }

    // fuzz：mint 任意份额
    function testFuzzMint(uint256 shares) public {
        shares = bound(shares, 0, type(uint128).max);

        underlying.mint(alice, type(uint128).max);
        vm.startPrank(alice);
        underlying.approve(address(vault), type(uint128).max);
        uint256 assets = vault.mint(shares, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalSupply(), shares);
        assertEq(vault.totalAssets(), assets);
    }

    // fuzz：deposit 后 redeem 全部，用户不应获利
    function testFuzzDepositRedeemRounding(uint256 depositAmount, uint256 yieldAmount) public {
        depositAmount = bound(depositAmount, 1e18, type(uint96).max);
        yieldAmount = bound(yieldAmount, 0, type(uint96).max);

        // alice 先存入建立初始汇率
        underlying.mint(alice, depositAmount);
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // 模拟收益
        underlying.mint(address(vault), yieldAmount);

        // bob 存入后立即赎回
        uint256 bobDeposit = depositAmount;
        underlying.mint(bob, bobDeposit);
        vm.startPrank(bob);
        underlying.approve(address(vault), bobDeposit);
        uint256 shares = vault.deposit(bobDeposit, bob);

        uint256 assetsBack = vault.redeem(shares, bob, bob);
        assertLe(assetsBack, bobDeposit);
        vm.stopPrank();
    }

    // fuzz：convertToShares 和 convertToAssets 一致性
    function testFuzzConvertConsistency(uint256 depositAmount, uint256 queryAmount) public {
        depositAmount = bound(depositAmount, 1, type(uint128).max);
        queryAmount = bound(queryAmount, 0, type(uint128).max);

        underlying.mint(alice, depositAmount);
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 shares = vault.convertToShares(queryAmount);
        uint256 assetsBack = vault.convertToAssets(shares);

        // 双向换算后资产不应增加（向下取整两次）
        assertLe(assetsBack, queryAmount);
    }

    // fuzz：maxWithdraw 等于 convertToAssets(balanceOf)
    function testFuzzMaxWithdraw(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        underlying.mint(alice, amount);
        vm.startPrank(alice);
        underlying.approve(address(vault), amount);
        vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(vault.maxWithdraw(alice), vault.convertToAssets(vault.balanceOf(alice)));
    }

    // fuzz：maxRedeem 等于 balanceOf
    function testFuzzMaxRedeem(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        underlying.mint(alice, amount);
        vm.startPrank(alice);
        underlying.approve(address(vault), amount);
        vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(vault.maxRedeem(alice), vault.balanceOf(alice));
    }
}

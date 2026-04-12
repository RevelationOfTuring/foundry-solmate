// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MissingReturnToken} from "solmate/test/utils/weird-tokens/MissingReturnToken.sol";
import {ReturnsFalseToken} from "solmate/test/utils/weird-tokens/ReturnsFalseToken.sol";
import {RevertingToken} from "solmate/test/utils/weird-tokens/RevertingToken.sol";
import {ReturnsGarbageToken} from "solmate/test/utils/weird-tokens/ReturnsGarbageToken.sol";
import {ReturnsTooLittleToken} from "solmate/test/utils/weird-tokens/ReturnsTooLittleToken.sol";
import {ReturnsTooMuchToken} from "solmate/test/utils/weird-tokens/ReturnsTooMuchToken.sol";
import {ReturnsTwoToken} from "solmate/test/utils/weird-tokens/ReturnsTwoToken.sol";
import {MockSafeTransferLib, ETHReceiver, RevertingETHReceiver} from "src/utils/MockSafeTransferLib.sol";

contract SafeTransferLibTest is Test {
    MockSafeTransferLib mock;

    // 标准代币
    MockERC20 standardToken;
    // 非标代币（无返回值，如 USDT）
    MissingReturnToken missingReturnToken;
    // 返回 false 的代币
    ReturnsFalseToken returnsFalseToken;
    // 直接 revert 的代币
    RevertingToken revertingToken;
    // 返回垃圾数据的代币
    ReturnsGarbageToken returnsGarbageToken;
    // 返回值不足 32 字节的代币
    ReturnsTooLittleToken returnsTooLittleToken;
    // 返回值超过 32 字节的代币
    ReturnsTooMuchToken returnsTooMuchToken;
    // 返回 2（非 bool）的代币
    ReturnsTwoToken returnsTwoToken;

    // ETH 接收合约
    ETHReceiver ethReceiver;
    RevertingETHReceiver revertingEthReceiver;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        mock = new MockSafeTransferLib();

        standardToken = new MockERC20("Standard", "STD", 18);
        missingReturnToken = new MissingReturnToken();
        returnsFalseToken = new ReturnsFalseToken();
        revertingToken = new RevertingToken();
        returnsGarbageToken = new ReturnsGarbageToken();
        returnsTooLittleToken = new ReturnsTooLittleToken();
        returnsTooMuchToken = new ReturnsTooMuchToken();
        returnsTwoToken = new ReturnsTwoToken();

        ethReceiver = new ETHReceiver();
        revertingEthReceiver = new RevertingETHReceiver();

        // 给 mock 合约打入 ETH
        vm.deal(address(mock), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          safeTransferETH
    //////////////////////////////////////////////////////////////*/

    // 正向：成功转账 ETH 到 EOA
    function testSafeTransferETHToEOA() public {
        uint256 balanceBefore = alice.balance;

        mock.safeTransferETH(alice, 1 ether);

        assertEq(alice.balance, balanceBefore + 1 ether);
    }

    // 正向：成功转账 ETH 到合约（有 receive）
    function testSafeTransferETHToContract() public {
        uint256 balanceBefore = address(ethReceiver).balance;

        mock.safeTransferETH(address(ethReceiver), 1 ether);

        assertEq(address(ethReceiver).balance, balanceBefore + 1 ether);
    }

    // 正向：转账 0 ETH
    function testSafeTransferETHZeroAmount() public {
        uint256 balanceBefore = alice.balance;

        mock.safeTransferETH(alice, 0);

        assertEq(alice.balance, balanceBefore);
    }

    // 反向：转账到 revert 的合约
    function testSafeTransferETHToRevertingReceiver() public {
        vm.expectRevert("ETH_TRANSFER_FAILED");
        mock.safeTransferETH(address(revertingEthReceiver), 1 ether);
    }

    // 反向：余额不足
    function testSafeTransferETHInsufficientBalance() public {
        vm.expectRevert("ETH_TRANSFER_FAILED");
        mock.safeTransferETH(alice, 200 ether);
    }

    // Fuzz：任意金额转账
    function testFuzzSafeTransferETH(uint256 amount) public {
        amount = bound(amount, 0, address(mock).balance);
        uint256 balanceBefore = alice.balance;

        mock.safeTransferETH(alice, amount);

        assertEq(alice.balance, balanceBefore + amount);
    }

    /*//////////////////////////////////////////////////////////////
                     safeTransfer — 标准代币
    //////////////////////////////////////////////////////////////*/

    // 正向：标准代币 transfer 成功
    function testSafeTransferStandardToken() public {
        standardToken.mint(address(mock), 100e18);

        mock.safeTransfer(ERC20(address(standardToken)), alice, 50e18);

        assertEq(standardToken.balanceOf(alice), 50e18);
        assertEq(standardToken.balanceOf(address(mock)), 50e18);
    }

    // 正向：transfer 0 金额
    function testSafeTransferZeroAmount() public {
        standardToken.mint(address(mock), 100e18);

        mock.safeTransfer(ERC20(address(standardToken)), alice, 0);

        assertEq(standardToken.balanceOf(alice), 0);
        assertEq(standardToken.balanceOf(address(mock)), 100e18);
    }

    // 反向：余额不足 revert
    function testSafeTransferInsufficientBalance() public {
        standardToken.mint(address(mock), 10e18);

        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(standardToken)), alice, 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                   safeTransferFrom — 标准代币
    //////////////////////////////////////////////////////////////*/

    // 正向：标准代币 transferFrom 成功
    function testSafeTransferFromStandardToken() public {
        standardToken.mint(alice, 100e18);

        vm.prank(alice);
        standardToken.approve(address(mock), 100e18);

        mock.safeTransferFrom(ERC20(address(standardToken)), alice, bob, 50e18);

        assertEq(standardToken.balanceOf(alice), 50e18);
        assertEq(standardToken.balanceOf(bob), 50e18);
    }

    // 反向：未授权 revert
    function testSafeTransferFromInsufficientAllowance() public {
        standardToken.mint(alice, 100e18);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(address(standardToken)), alice, bob, 50e18);
    }

    // 反向：余额不足 revert
    function testSafeTransferFromInsufficientBalance() public {
        standardToken.mint(alice, 10e18);

        vm.prank(alice);
        standardToken.approve(address(mock), 100e18);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(address(standardToken)), alice, bob, 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                      safeApprove — 标准代币
    //////////////////////////////////////////////////////////////*/

    // 正向：标准代币 approve 成功
    function testSafeApproveStandardToken() public {
        mock.safeApprove(ERC20(address(standardToken)), alice, 100e18);

        assertEq(standardToken.allowance(address(mock), alice), 100e18);
    }

    // 正向：approve 0（用于 USDT 先归零）
    function testSafeApproveZero() public {
        mock.safeApprove(ERC20(address(standardToken)), alice, 100e18);
        mock.safeApprove(ERC20(address(standardToken)), alice, 0);

        assertEq(standardToken.allowance(address(mock), alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                  MissingReturnToken（无返回值，如 USDT）
    //////////////////////////////////////////////////////////////*/

    // 正向：无返回值代币 transfer 成功
    function testSafeTransferMissingReturn() public {
        // MissingReturnToken 构造函数给 deployer（this）铸造了 type(uint256).max
        // 直接转余额到 mock
        missingReturnToken.transfer(address(mock), 10e18);

        mock.safeTransfer(ERC20(address(missingReturnToken)), alice, 1e18);

        assertEq(missingReturnToken.balanceOf(alice), 1e18);
    }

    // 正向：无返回值代币 transferFrom 成功
    function testSafeTransferFromMissingReturn() public {
        // MissingReturnToken 构造函数给 deployer（this）铸造了 type(uint256).max
        // 授权 mock 从 this 转出
        missingReturnToken.approve(address(mock), type(uint256).max);

        mock.safeTransferFrom(ERC20(address(missingReturnToken)), address(this), alice, 1e18);

        assertEq(missingReturnToken.balanceOf(alice), 1e18);
    }

    // 正向：无返回值代币 approve 成功
    function testSafeApproveMissingReturn() public {
        mock.safeApprove(ERC20(address(missingReturnToken)), alice, 100e18);

        assertEq(missingReturnToken.allowance(address(mock), alice), 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                ReturnsFalseToken（返回 false）
    //////////////////////////////////////////////////////////////*/

    // 反向：返回 false 的代币 transfer 应 revert
    function testSafeTransferReturnsFalse() public {
        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsFalseToken)), alice, 1e18);
    }

    // 反向：返回 false 的代币 transferFrom 应 revert
    function testSafeTransferFromReturnsFalse() public {
        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(address(returnsFalseToken)), address(this), alice, 1e18);
    }

    // 反向：返回 false 的代币 approve 应 revert
    function testSafeApproveReturnsFalse() public {
        vm.expectRevert("APPROVE_FAILED");
        mock.safeApprove(ERC20(address(returnsFalseToken)), alice, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                RevertingToken（直接 revert）
    //////////////////////////////////////////////////////////////*/

    // 反向：revert 的代币 transfer 应 revert
    function testSafeTransferReverting() public {
        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(revertingToken)), alice, 1e18);
    }

    // 反向：revert 的代币 transferFrom 应 revert
    function testSafeTransferFromReverting() public {
        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(address(revertingToken)), address(this), alice, 1e18);
    }

    // 反向：revert 的代币 approve 应 revert
    function testSafeApproveReverting() public {
        vm.expectRevert("APPROVE_FAILED");
        mock.safeApprove(ERC20(address(revertingToken)), alice, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
              ReturnsTooLittleToken（返回值不足 32 字节）
    //////////////////////////////////////////////////////////////*/

    // 反向：返回值不足 32 字节的代币 transfer 应 revert
    // 虽然返回的前 8 字节看起来像 true，但 returndatasize < 32 且不为 0
    // → 不满足标准返回（需 ≥ 32 字节），也不满足无返回值（returndatasize != 0）
    function testSafeTransferReturnsTooLittle() public {
        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsTooLittleToken)), alice, 1e18);
    }

    // 反向：返回值不足 32 字节的代币 transferFrom 应 revert
    function testSafeTransferFromReturnsTooLittle() public {
        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(address(returnsTooLittleToken)), address(this), alice, 1e18);
    }

    // 反向：返回值不足 32 字节的代币 approve 应 revert
    function testSafeApproveReturnsTooLittle() public {
        vm.expectRevert("APPROVE_FAILED");
        mock.safeApprove(ERC20(address(returnsTooLittleToken)), alice, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
              ReturnsTooMuchToken（返回值超过 32 字节）
    //////////////////////////////////////////////////////////////*/

    // 正向：返回值超过 32 字节但前 32 字节为 1（true）→ 成功
    // call 的 outputSize=32 只拷贝前 32 字节到 scratch space，
    // 但 returndatasize() 返回实际长度（4096），仍满足 gt(returndatasize(), 31)
    function testSafeTransferReturnsTooMuch() public {
        // ReturnsTooMuchToken 构造函数给 deployer（this）铸造了 type(uint256).max
        // 直接转余额到 mock
        returnsTooMuchToken.transfer(address(mock), 10e18);

        mock.safeTransfer(ERC20(address(returnsTooMuchToken)), alice, 1e18);

        assertEq(returnsTooMuchToken.balanceOf(alice), 1e18);
    }

    // 正向：returnsTooMuch transferFrom 成功
    function testSafeTransferFromReturnsTooMuch() public {
        returnsTooMuchToken.approve(address(mock), type(uint256).max);

        mock.safeTransferFrom(ERC20(address(returnsTooMuchToken)), address(this), alice, 1e18);

        assertEq(returnsTooMuchToken.balanceOf(alice), 1e18);
    }

    // 正向：returnsTooMuch approve 成功
    function testSafeApproveReturnsTooMuch() public {
        mock.safeApprove(ERC20(address(returnsTooMuchToken)), alice, 100e18);

        assertEq(returnsTooMuchToken.allowance(address(mock), alice), 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                ReturnsTwoToken（返回 2，非 bool）
    //////////////////////////////////////////////////////////////*/

    // 反向：返回 2 的代币 transfer 应 revert
    // returndatasize ≥ 32 但 mload(0) == 2 != 1 → 不满足标准返回
    // 进入 if 体，returndatasize == 32 != 0 → success = false
    function testSafeTransferReturnsTwo() public {
        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsTwoToken)), alice, 1e18);
    }

    // 反向：返回 2 的代币 transferFrom 应 revert
    function testSafeTransferFromReturnsTwo() public {
        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(address(returnsTwoToken)), address(this), alice, 1e18);
    }

    // 反向：返回 2 的代币 approve 应 revert
    function testSafeApproveReturnsTwo() public {
        vm.expectRevert("APPROVE_FAILED");
        mock.safeApprove(ERC20(address(returnsTwoToken)), alice, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
            ReturnsGarbageToken（返回垃圾数据，可配置）
    //////////////////////////////////////////////////////////////*/

    // 正向：垃圾数据为空（returndatasize=0）→ 按无返回值处理 → 成功
    function testSafeTransferGarbageEmpty() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage("");

        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);

        assertEq(returnsGarbageToken.balanceOf(alice), 1e18);
    }

    // 正向：垃圾数据为 abi.encode(true)（标准返回）→ 成功
    function testSafeTransferGarbageTrue() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage(abi.encode(true));

        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);

        assertEq(returnsGarbageToken.balanceOf(alice), 1e18);
    }

    // 反向：垃圾数据为 abi.encode(false)（返回 false）→ revert
    function testSafeTransferGarbageFalse() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage(abi.encode(false));

        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);
    }

    // 反向：垃圾数据为随机 1 字节 → returndatasize=1，不满足任何合法路径 → revert
    function testSafeTransferGarbageOneByte() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage(hex"ab");

        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);
    }

    // 反向：垃圾数据为 31 字节 → 不足 32 字节，且不为空 → revert
    function testSafeTransferGarbage31Bytes() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage(new bytes(31));

        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);
    }

    // 正向：垃圾数据为 32 字节的 1（abi.encode(uint256(1))）→ 等同返回 true → 成功
    function testSafeTransferGarbage32BytesOne() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage(abi.encode(uint256(1)));

        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);

        assertEq(returnsGarbageToken.balanceOf(alice), 1e18);
    }

    // 反向：垃圾数据为 32 字节的 2 → mload(0) == 2 != 1 → revert
    function testSafeTransferGarbage32BytesTwo() public {
        returnsGarbageToken.transfer(address(mock), 10e18);
        returnsGarbageToken.setGarbage(abi.encode(uint256(2)));

        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(address(returnsGarbageToken)), alice, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    EOA 地址作为 token（边界）
    //////////////////////////////////////////////////////////////*/

    // 反向：token 是 EOA → call transfer 成功但 extcodesize=0 → revert
    function testSafeTransferToEOAToken() public {
        vm.expectRevert("TRANSFER_FAILED");
        mock.safeTransfer(ERC20(alice), bob, 1e18);
    }

    // 反向：token 是 EOA → call transferFrom 成功但 extcodesize=0 → revert
    function testSafeTransferFromEOAToken() public {
        vm.expectRevert("TRANSFER_FROM_FAILED");
        mock.safeTransferFrom(ERC20(alice), address(this), bob, 1e18);
    }

    // 反向：token 是 EOA → call approve 成功但 extcodesize=0 → revert
    function testSafeApproveEOAToken() public {
        vm.expectRevert("APPROVE_FAILED");
        mock.safeApprove(ERC20(alice), bob, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                         Fuzz 测试
    //////////////////////////////////////////////////////////////*/

    // Fuzz：标准代币 transfer 任意金额
    function testFuzzSafeTransfer(uint256 amount) public {
        amount = bound(amount, 0, type(uint128).max);
        standardToken.mint(address(mock), amount);

        mock.safeTransfer(ERC20(address(standardToken)), alice, amount);

        assertEq(standardToken.balanceOf(alice), amount);
    }

    // Fuzz：标准代币 transferFrom 任意金额
    function testFuzzSafeTransferFrom(uint256 amount) public {
        amount = bound(amount, 0, type(uint128).max);
        standardToken.mint(alice, amount);

        vm.prank(alice);
        standardToken.approve(address(mock), amount);

        mock.safeTransferFrom(ERC20(address(standardToken)), alice, bob, amount);

        assertEq(standardToken.balanceOf(bob), amount);
    }

    // Fuzz：标准代币 approve 任意金额
    function testFuzzSafeApprove(uint256 amount) public {
        mock.safeApprove(ERC20(address(standardToken)), alice, amount);

        assertEq(standardToken.allowance(address(mock), alice), amount);
    }
}

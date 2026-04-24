// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "src/tokens/MockERC20.sol";

contract ERC20Test is Test {
    MockERC20 token;

    address alice = address(0xA);
    address bob = address(0xB);
    address carol = address(0xC);

    // 用于 permit 测试的私钥和地址
    uint256 ownerPrivateKey = 0x1234;
    address owner = vm.addr(ownerPrivateKey);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function setUp() public {
        token = new MockERC20("Test Token", "TT", 18);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // 验证构造函数正确设置 name、symbol、decimals
    function testConstructorSetsMetadata() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TT");
        assertEq(token.decimals(), 18);
    }

    // 验证初始 totalSupply 为 0
    function testConstructorInitialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    // 验证构造函数缓存了 DOMAIN_SEPARATOR
    function testConstructorCachesDomainSeparator() public view {
        // DOMAIN_SEPARATOR 应该是非零值
        assertTrue(token.DOMAIN_SEPARATOR() != bytes32(0));
    }

    // 边界：decimals 可以设为 0
    function testConstructorWithZeroDecimals() public {
        MockERC20 zeroDecimal = new MockERC20("Zero", "Z", 0);
        assertEq(zeroDecimal.decimals(), 0);
    }

    // 边界：空字符串作为 name 和 symbol
    function testConstructorWithEmptyStrings() public {
        MockERC20 empty = new MockERC20("", "", 18);
        assertEq(empty.name(), "");
        assertEq(empty.symbol(), "");
    }

    /*//////////////////////////////////////////////////////////////
                              APPROVE
    //////////////////////////////////////////////////////////////*/

    // 正向：approve 设置授权额度，触发 Approval 事件
    function testApprove() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 100);
        assertTrue(token.approve(bob, 100));
        assertEq(token.allowance(alice, bob), 100);
    }

    // 正向：approve 覆盖旧值（不是累加）
    function testApproveOverwritesPreviousValue() public {
        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(alice);
        token.approve(bob, 50);
        assertEq(token.allowance(alice, bob), 50);
    }

    // 正向：approve type(uint256).max（无限授权）
    function testApproveMaxAmount() public {
        vm.prank(alice);
        token.approve(bob, type(uint256).max);
        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    // 边界：approve 额度为 0
    function testApproveZero() public {
        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(alice);
        token.approve(bob, 0);
        assertEq(token.allowance(alice, bob), 0);
    }

    // 边界：approve 给零地址
    function testApproveToZeroAddress() public {
        vm.prank(alice);
        assertTrue(token.approve(address(0), 100));
        assertEq(token.allowance(alice, address(0)), 100);
    }

    /*//////////////////////////////////////////////////////////////
                              TRANSFER
    //////////////////////////////////////////////////////////////*/

    // 正向：transfer 转账成功，触发 Transfer 事件
    function testTransfer() public {
        token.mint(alice, 1000);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 400);
        assertTrue(token.transfer(bob, 400));

        assertEq(token.balanceOf(alice), 600);
        assertEq(token.balanceOf(bob), 400);
    }

    // 反向：余额不足 → revert
    function testTransferInsufficientBalance() public {
        token.mint(alice, 100);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 101);
    }

    // 边界：转账 0
    function testTransferZeroAmount() public {
        token.mint(alice, 100);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));

        assertEq(token.balanceOf(alice), 100);
        assertEq(token.balanceOf(bob), 0);
    }

    // 边界：转给自己
    function testTransferToSelf() public {
        token.mint(alice, 100);

        vm.prank(alice);
        assertTrue(token.transfer(alice, 50));

        // 先扣后加，余额不变
        assertEq(token.balanceOf(alice), 100);
    }

    // 边界：转给零地址（不会 revert）
    function testTransferToZeroAddress() public {
        token.mint(alice, 100);

        vm.prank(alice);
        assertTrue(token.transfer(address(0), 50));

        assertEq(token.balanceOf(alice), 50);
        assertEq(token.balanceOf(address(0)), 50);
    }

    // 正向：transfer 不改变 totalSupply
    function testTransferDoesNotChangeTotalSupply() public {
        token.mint(alice, 1000);
        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.transfer(bob, 400);

        assertEq(token.totalSupply(), supplyBefore);
    }

    // 正向：转全部余额
    function testTransferEntireBalance() public {
        token.mint(alice, 1000);

        vm.prank(alice);
        token.transfer(bob, 1000);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1000);
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER FROM
    //////////////////////////////////////////////////////////////*/

    // 正向：transferFrom 授权转账成功，触发 Transfer 事件
    function testTransferFrom() public {
        token.mint(alice, 1000);

        vm.prank(alice);
        token.approve(bob, 500);

        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, carol, 300);
        assertTrue(token.transferFrom(alice, carol, 300));

        assertEq(token.balanceOf(alice), 700);
        assertEq(token.balanceOf(carol), 300);
        assertEq(token.allowance(alice, bob), 200);
    }

    // 正向：无限授权不扣减 allowance
    function testTransferFromInfiniteApproval() public {
        token.mint(alice, 1000);

        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, carol, 500);

        // allowance 不变
        assertEq(token.allowance(alice, bob), type(uint256).max);
        assertEq(token.balanceOf(alice), 500);
        assertEq(token.balanceOf(carol), 500);
    }

    // 反向：授权额度不足 → revert
    function testTransferFromInsufficientAllowance() public {
        token.mint(alice, 1000);

        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, carol, 101);
    }

    // 反向：余额不足 → revert（即使 allowance 足够）
    function testTransferFromInsufficientBalance() public {
        token.mint(alice, 100);

        vm.prank(alice);
        token.approve(bob, 200);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, carol, 101);
    }

    // 边界：transferFrom 转 0
    function testTransferFromZeroAmount() public {
        token.mint(alice, 100);
        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, 0));

        assertEq(token.balanceOf(alice), 100);
        assertEq(token.allowance(alice, bob), 100);
    }

    // 边界：用完全部 allowance
    function testTransferFromExactAllowance() public {
        token.mint(alice, 1000);
        vm.prank(alice);
        token.approve(bob, 500);

        vm.prank(bob);
        token.transferFrom(alice, carol, 500);

        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.balanceOf(carol), 500);
    }

    /*//////////////////////////////////////////////////////////////
                               MINT
    //////////////////////////////////////////////////////////////*/

    // 正向：mint 增加余额和 totalSupply，触发 Transfer 事件（from = address(0)）
    function testMint() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), alice, 1000);
        token.mint(alice, 1000);

        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.totalSupply(), 1000);
    }

    // 正向：多次 mint 累加
    function testMintMultiple() public {
        token.mint(alice, 100);
        token.mint(alice, 200);
        token.mint(bob, 300);

        assertEq(token.balanceOf(alice), 300);
        assertEq(token.balanceOf(bob), 300);
        assertEq(token.totalSupply(), 600);
    }

    // 边界：mint 0
    function testMintZero() public {
        token.mint(alice, 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    // 边界：mint 给零地址（不会 revert）
    function testMintToZeroAddress() public {
        token.mint(address(0), 100);
        assertEq(token.balanceOf(address(0)), 100);
        assertEq(token.totalSupply(), 100);
    }

    // 反向：totalSupply 溢出 → revert
    function testMintOverflow() public {
        token.mint(alice, type(uint256).max);

        vm.expectRevert();
        token.mint(bob, 1);
    }

    /*//////////////////////////////////////////////////////////////
                               BURN
    //////////////////////////////////////////////////////////////*/

    // 正向：burn 减少余额和 totalSupply，触发 Transfer 事件（to = address(0)）
    function testBurn() public {
        token.mint(alice, 1000);

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, address(0), 400);
        token.burn(alice, 400);

        assertEq(token.balanceOf(alice), 600);
        assertEq(token.totalSupply(), 600);
    }

    // 反向：burn 超过余额 → revert
    function testBurnInsufficientBalance() public {
        token.mint(alice, 100);

        vm.expectRevert();
        token.burn(alice, 101);
    }

    // 边界：burn 0
    function testBurnZero() public {
        token.mint(alice, 100);
        token.burn(alice, 0);

        assertEq(token.balanceOf(alice), 100);
        assertEq(token.totalSupply(), 100);
    }

    // 正向：burn 全部余额
    function testBurnEntireBalance() public {
        token.mint(alice, 1000);
        token.burn(alice, 1000);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    // 正向：mint 后 burn，确保不变量 sum(balanceOf) == totalSupply
    function testMintThenBurnInvariant() public {
        token.mint(alice, 500);
        token.mint(bob, 300);
        token.burn(alice, 200);

        assertEq(token.totalSupply(), 600);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), 600);
    }

    /*//////////////////////////////////////////////////////////////
                          DOMAIN SEPARATOR
    //////////////////////////////////////////////////////////////*/

    // 正向：DOMAIN_SEPARATOR 在同一条链上返回一致值
    function testDomainSeparatorConsistency() public view {
        bytes32 ds1 = token.DOMAIN_SEPARATOR();
        bytes32 ds2 = token.DOMAIN_SEPARATOR();
        assertEq(ds1, ds2);
    }

    // 正向：DOMAIN_SEPARATOR 符合 EIP-712 计算
    function testDomainSeparatorMatchesExpected() public view {
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Test Token")),
                keccak256("1"),
                block.chainid,
                address(token)
            )
        );
        assertEq(token.DOMAIN_SEPARATOR(), expected);
    }

    // 正向：链 fork 后 DOMAIN_SEPARATOR 会改变
    function testDomainSeparatorChangesOnFork() public {
        bytes32 dsBefore = token.DOMAIN_SEPARATOR();

        // 模拟 fork（改变 chainid）
        uint256 newChainId = 999;
        vm.chainId(newChainId);

        bytes32 dsAfter = token.DOMAIN_SEPARATOR();
        assertTrue(dsBefore != dsAfter);

        // 验证新的 DOMAIN_SEPARATOR 用了新的 chainId
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Test Token")),
                keccak256("1"),
                newChainId,
                address(token)
            )
        );
        assertEq(dsAfter, expected);
    }

    /*//////////////////////////////////////////////////////////////
                              PERMIT
    //////////////////////////////////////////////////////////////*/

    // 辅助函数：生成 permit 签名
    function _signPermit(
        uint256 privateKey,
        address _owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                _owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (v, r, s) = vm.sign(privateKey, digest);
    }

    // 正向：permit 设置 allowance，触发 Approval 事件
    function testPermit() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 0, deadline);

        vm.expectEmit(true, true, false, true);
        emit Approval(owner, bob, 1000);
        token.permit(owner, bob, 1000, deadline, v, r, s);

        assertEq(token.allowance(owner, bob), 1000);
        assertEq(token.nonces(owner), 1);
    }

    // 正向：连续两次 permit，nonce 递增
    function testPermitNonceIncrement() public {
        uint256 deadline = block.timestamp + 1 hours;

        // 第一次 permit（nonce = 0）
        (uint8 v1, bytes32 r1, bytes32 s1) = _signPermit(ownerPrivateKey, owner, bob, 100, 0, deadline);
        token.permit(owner, bob, 100, deadline, v1, r1, s1);
        assertEq(token.nonces(owner), 1);

        // 第二次 permit（nonce = 1）
        (uint8 v2, bytes32 r2, bytes32 s2) = _signPermit(ownerPrivateKey, owner, bob, 200, 1, deadline);
        token.permit(owner, bob, 200, deadline, v2, r2, s2);
        assertEq(token.nonces(owner), 2);
        assertEq(token.allowance(owner, bob), 200);
    }

    // 反向：签名过期 → revert
    function testPermitExpiredDeadline() public {
        uint256 deadline = block.timestamp - 1;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 0, deadline);

        vm.expectRevert("PERMIT_DEADLINE_EXPIRED");
        token.permit(owner, bob, 1000, deadline, v, r, s);
    }

    // 反向：签名重放（同一签名用两次）→ revert
    function testPermitReplay() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 0, deadline);

        // 第一次成功
        token.permit(owner, bob, 1000, deadline, v, r, s);

        // 第二次重放 → revert（nonce 已递增）
        vm.expectRevert("INVALID_SIGNER");
        token.permit(owner, bob, 1000, deadline, v, r, s);
    }

    // 反向：错误的签名者 → revert
    function testPermitWrongSigner() public {
        uint256 wrongKey = ownerPrivateKey + 1;
        uint256 deadline = block.timestamp + 1 hours;

        // 用错误的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(wrongKey, owner, bob, 1000, 0, deadline);

        vm.expectRevert("INVALID_SIGNER");
        token.permit(owner, bob, 1000, deadline, v, r, s);
    }

    // 反向：错误的 nonce → revert
    function testPermitWrongNonce() public {
        uint256 deadline = block.timestamp + 1 hours;

        // 用 nonce=1 签名，但当前 nonce=0
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 1, deadline);

        vm.expectRevert("INVALID_SIGNER");
        token.permit(owner, bob, 1000, deadline, v, r, s);
    }

    // 反向：篡改 value → revert
    function testPermitTamperedValue() public {
        uint256 deadline = block.timestamp + 1 hours;

        // 签 value=1000，但提交 value=2000
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 0, deadline);

        vm.expectRevert("INVALID_SIGNER");
        token.permit(owner, bob, 2000, deadline, v, r, s);
    }

    // 反向：篡改 spender → revert
    function testPermitTamperedSpender() public {
        uint256 deadline = block.timestamp + 1 hours;

        // 签 spender=bob，但提交 spender=carol
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 0, deadline);

        vm.expectRevert("INVALID_SIGNER");
        token.permit(owner, carol, 1000, deadline, v, r, s);
    }

    // 边界：permit deadline 恰好等于 block.timestamp（不应 revert）
    function testPermitDeadlineExactlyNow() public {
        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 1000, 0, deadline);

        // deadline >= block.timestamp，应该通过
        token.permit(owner, bob, 1000, deadline, v, r, s);
        assertEq(token.allowance(owner, bob), 1000);
    }

    // 边界：permit value = 0
    function testPermitZeroValue() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 0, 0, deadline);

        token.permit(owner, bob, 0, deadline, v, r, s);
        assertEq(token.allowance(owner, bob), 0);
    }

    // 边界：permit value = type(uint256).max（无限授权）
    function testPermitMaxValue() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, type(uint256).max, 0, deadline);

        token.permit(owner, bob, type(uint256).max, deadline, v, r, s);
        assertEq(token.allowance(owner, bob), type(uint256).max);
    }

    // 正向：permit 后可以用 transferFrom 转账
    function testPermitThenTransferFrom() public {
        token.mint(owner, 1000);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ownerPrivateKey, owner, bob, 500, 0, deadline);

        token.permit(owner, bob, 500, deadline, v, r, s);

        vm.prank(bob);
        token.transferFrom(owner, carol, 300);

        assertEq(token.balanceOf(owner), 700);
        assertEq(token.balanceOf(carol), 300);
        assertEq(token.allowance(owner, bob), 200);
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // fuzz：mint 任意数量
    function testFuzzMint(address to, uint256 amount) public {
        token.mint(to, amount);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    // fuzz：burn 不超过余额的任意数量
    function testFuzzBurn(address from, uint256 mintAmount, uint256 burnAmount) public {
        burnAmount = bound(burnAmount, 0, mintAmount);

        token.mint(from, mintAmount);
        token.burn(from, burnAmount);

        assertEq(token.balanceOf(from), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    // fuzz：approve 任意数量
    function testFuzzApprove(address spender, uint256 amount) public {
        vm.prank(alice);
        assertTrue(token.approve(spender, amount));
        assertEq(token.allowance(alice, spender), amount);
    }

    // fuzz：transfer 不超过余额的任意数量
    function testFuzzTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0)); // 避免地址冲突干扰
        token.mint(alice, amount);

        vm.prank(alice);
        assertTrue(token.transfer(to, amount));

        if (to == alice) {
            assertEq(token.balanceOf(alice), amount);
        } else {
            assertEq(token.balanceOf(alice), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    // fuzz：transferFrom 不超过 allowance 和余额的任意数量
    function testFuzzTransferFrom(uint256 mintAmount, uint256 approveAmount, uint256 transferAmount) public {
        // 确保 transferAmount <= min(approveAmount, mintAmount)
        approveAmount = bound(approveAmount, 0, mintAmount);
        transferAmount = bound(transferAmount, 0, approveAmount);

        token.mint(alice, mintAmount);
        vm.prank(alice);
        token.approve(bob, approveAmount);

        vm.prank(bob);
        token.transferFrom(alice, carol, transferAmount);

        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(carol), transferAmount);

        if (approveAmount == type(uint256).max) {
            assertEq(token.allowance(alice, bob), type(uint256).max);
        } else {
            assertEq(token.allowance(alice, bob), approveAmount - transferAmount);
        }
    }
}

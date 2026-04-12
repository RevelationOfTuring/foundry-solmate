// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// SafeTransferLib 是 library，所有函数都是 internal（编译时内联到调用合约中）。
// vm.expectRevert 只能捕获外部调用的 revert，无法捕获内联函数的 revert。
// 因此需要这个 Mock 合约将 internal 函数包装为 external 调用，使测试中的 revert 可被捕获。
contract MockSafeTransferLib {
    using SafeTransferLib for ERC20;

    // forge-lint: disable-next-line(mixed-case-function)
    function safeTransferETH(address to, uint256 amount) external {
        SafeTransferLib.safeTransferETH(to, amount);
    }

    function safeTransferFrom(ERC20 token, address from, address to, uint256 amount) external {
        token.safeTransferFrom(from, to, amount);
    }

    function safeTransfer(ERC20 token, address to, uint256 amount) external {
        token.safeTransfer(to, amount);
    }

    function safeApprove(ERC20 token, address to, uint256 amount) external {
        token.safeApprove(to, amount);
    }

    receive() external payable {}
}

/// @dev 能接收 ETH 的合约
contract ETHReceiver {
    receive() external payable {}
}

/// @dev receive 中 revert 的合约，用于测试 ETH 转账失败
contract RevertingETHReceiver {
    receive() external payable {
        revert();
    }
}

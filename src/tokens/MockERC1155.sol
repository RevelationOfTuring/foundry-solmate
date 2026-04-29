// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC1155} from "solmate/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _mint(to, id, amount, data);
    }

    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        _batchMint(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }

    function batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) external {
        _batchBurn(from, ids, amounts);
    }
}

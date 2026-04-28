// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function burn(uint256 id) external {
        _burn(id);
    }

    function safeMint(address to, uint256 id) external {
        _safeMint(to, id);
    }

    function safeMint(address to, uint256 id, bytes memory data) external {
        _safeMint(to, id, data);
    }
}

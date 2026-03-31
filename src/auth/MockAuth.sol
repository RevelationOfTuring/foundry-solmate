// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Auth, Authority} from "solmate/auth/Auth.sol";

contract MockAuth is Auth {
    constructor(address owner, Authority authority) Auth(owner, authority) {}

    function protectedFunction() external view requiresAuth returns (bool) {
        return true;
    }

    function unprotectedFunction() external pure returns (bool) {
        return true;
    }
}

contract MockAuthority is Authority {
    mapping(address => mapping(address => mapping(bytes4 => bool))) public permissions;

    function setCanCall(address user, address target, bytes4 functionSig, bool allowed) external {
        permissions[user][target][functionSig] = allowed;
    }

    function canCall(address user, address target, bytes4 functionSig) external view override returns (bool) {
        return permissions[user][target][functionSig];
    }
}

contract RevertingAuthority is Authority {
    function canCall(address, address, bytes4) external pure override returns (bool) {
        revert("AUTHORITY_REVERTED");
    }
}

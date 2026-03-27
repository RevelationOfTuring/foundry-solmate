// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

contract MockOwned is Owned {
    constructor(address owner) Owned(owner) {}

    function protectedFunction() external view onlyOwner returns (bool) {
        return true;
    }

    function unprotectedFunction() external pure returns (bool) {
        return true;
    }
}

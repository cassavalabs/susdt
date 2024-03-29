// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

library AddressCast {
    error InvalidEVMAddress(bytes32 account);

    function toBytes32(address account) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    function toAddress(bytes32 account) internal pure returns (address) {
        if (uint256(account) >> 160 != 0) {
            revert InvalidEVMAddress(account);
        }
        return address(uint160(uint256(account)));
    }
}

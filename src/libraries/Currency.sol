// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title Currency
 * @notice A library to safely manage transfer of both native
 * and non-native token transfer in a gas optimised manner
 */
library Currency {
    using Currency for address;

    address public constant NATIVE = address(0x0);

    /**
     * @notice Reverts on failed transfer
     * @param token address of token transfered
     */
    error FundTransferFailed(address token);

    /**
     * @notice A singleton function to handle native and non-native asset transfer
     * @param token address of token to be transfered
     * @param to address of the token receipient
     * @param amount the amount of value
     */
    function transfer(address token, address to, uint256 amount) internal {
        if (isNative(token)) {
            safeTransfer(to, amount);
        } else {
            safeTransferERC20(token, to, amount);
        }
    }

    /**
     * @notice Internal function to handle native token transfers
     * @param to receipient address
     * @param amount value to send
     */
    function safeTransfer(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the Native token and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        if (!success) revert FundTransferFailed(NATIVE);
    }

    /**
     * @notice Internal function to handle non-native token transfers
     * @param token contract address of token
     * @param to receipient address
     * @param amount value to transfer
     */
    function safeTransferERC20(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                0,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, to) // Append the "to" argument.
            mstore(36, amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // We use 68 because that's the total length of our calldata (4 + 32 * 2)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0, 68, 0, 32)
            )

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }

        if (!success) revert FundTransferFailed(token);
    }

    /**
     * @notice Internal function to handle non-native token transferFrom
     * @param token contract address of token
     * @param from address of source account
     * @param to receipient address
     * @param amount value to transfer
     */
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                0,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, from) // Append the "from" argument.
            mstore(36, to) // Append the "to" argument.
            mstore(68, amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // We use 100 because that's the total length of our calldata (4 + 32 * 3)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0, 100, 0, 32)
            )

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }

        if (!success) revert FundTransferFailed(token);
    }

    /**
     * @notice Internal function to return if a currency is native or ERC20
     * @param token address of token contract
     */
    function isNative(address token) internal pure returns (bool) {
        return token == NATIVE;
    }

    /**
     * @notice Internal function to get the balance of an address
     * @param currency address of token
     * @param account the address to check balance for
     */
    function balanceOf(
        address currency,
        address account
    ) internal view returns (uint256) {
        if (currency.isNative()) {
            return account.balance;
        } else {
            return IERC20(currency).balanceOf(account);
        }
    }

    /**
     * @dev Sets a `amount` amount of tokens as the allowance of `spender` over the
     *  caller's tokens.
     * @param currency address of token
     * @param spender address of spender
     * @param amount amount to approve
     */
    function approve(
        address currency,
        address spender,
        uint256 amount
    ) internal {
        IERC20(currency).approve(spender, amount);
    }

    /**
     * @dev converts address to numeric value
     * @param currency token address
     * @return uint256 representation of the given address
     */
    function toId(address currency) internal pure returns (uint256) {
        return uint160(address(currency));
    }

    /**
     * @dev converts from uint256 to address
     * @param id uint256 representation of an address
     * @return address
     */
    function fromId(uint256 id) internal pure returns (address) {
        return address(uint160(id));
    }
}

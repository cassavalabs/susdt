// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library Errors {
    /// @notice Revert if the account is denylisted
    error DenyListedAccount(bytes32 account);

    /// @notice Revert if the account is not denylisted
    error UnDenyListedAccount();

    /// @notice Revert if currency is allowed
    error CurrencyAllowed();

    /// @notice Revert if underlying currency is not allowed
    error InvalidUnderlyingCurrency(address currency);

    /// @notice Revert if insufficient liquidity
    error InsufficientLiquidity();

    /// @notice Revert if an invalid chain limit is provided
    error InValidChainLimit();

    /// @notice Revert if the minting limit is reached on a chain
    error ChainLimitReached(uint256 limit);
}

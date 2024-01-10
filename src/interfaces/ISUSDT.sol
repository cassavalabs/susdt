// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ISUSDT {
    /**
     * @notice Emitted whenever a new token is been allowed on the vault
     * @param currency the token address
     */
    event AllowCurrency(address indexed currency);

    /**
     * @notice Emitted whenever a user redeem SUSDT for any of the underlying stables
     * @param currency the token redeemed
     * @param account the account redeeming
     * @param amount the value redeem
     */
    event Redeem(
        address indexed currency,
        address indexed account,
        uint256 amount
    );

    /**
     * @notice Emitted when an account is deny listed
     * @param account the account deny listed
     */
    event DenyList(bytes32 indexed account);

    /**
     * @notice Emitted when an account is cleared from deny listed
     * @param account the account
     */
    event UnDenyList(bytes32 indexed account);

    /**
     * @notice allow bridge to accept local `currency` for bridging
     * `currency` is required to be a stable coin to ensure optimum bridging
     * @param currency address of token to accept
     */
    function allowCurrency(address currency) external;

    /**
     * @notice useful for recovering native/local tokens sent to the router by mistake
     * @param currency address of token to withdraw
     * @param to address of token receiver
     * @param amount amount of token to withdraw
     */
    function recoverToken(
        address currency,
        address to,
        uint256 amount
    ) external;

    /**
     * @dev Issues SUSDT by locking any of the accepted stable coins
     * @param currency the underlying asset to wrap
     * @param amount the amount of asset to wrap
     */
    function issue(address currency, uint256 amount) external;

    /**
     * @dev Bridge SUSDT to the underlying `currency`, subject to liquidity availability
     * @param currency the underlying token to redeem
     * @param amount the amount of SUSDT to redeem for `currency`
     */
    function redeem(address currency, uint256 amount) external;

    /**
     * @dev allow transfering value without previous approval in a single tx
     * @param from token owner account address
     * @param to receipient of `value`
     * @param value amount to transfer
     * @param deadline unix timestamp after which signature is invalid
     * @param v v component of signature
     * @param r r component of signature
     * @param s s component of signature
     */
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev allow redeeming value without previous approval in a single tx
     * @param currency address of token to receive
     * @param from token owner account address
     * @param value amount to transfer
     * @param deadline unix timestamp after which signature is invalid
     * @param v v component of signature
     * @param r r component of signature
     * @param s s component of signature
     */
    function redeemWithAuthorization(
        address currency,
        address from,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Block a malicious account from transacting with token
     * @param account the account to deny access
     */
    function denyList(bytes32 account) external;

    /**
     * @dev Unblock an account to resume transactions
     * @param account the account to clear from deny list
     */
    function unDenyList(bytes32 account) external;

    /**
     * @dev Allow setting mintable chain limit
     * @param amount the new limit amount
     */
    function updateChainLimit(uint256 amount) external;

    /**
     * @dev Allow halting operations
     */
    function pause() external;

    /**
     * @dev Allow starting halted operations
     */
    function unpause() external;

    /**
     * @notice Check if an account is denied access
     * @param account the account to check status
     * @return bool True if account is denied access
     */
    function isDenyListed(bytes32 account) external view returns (bool);
}

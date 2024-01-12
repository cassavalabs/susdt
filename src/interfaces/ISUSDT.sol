// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ISUSDT {
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
     * Emitted when a remote transafer is initiated
     * @param guid the message delivery hash
     * @param from the src account
     * @param to the receipient address on the dst chain
     * @param amount value to send
     * @param srcEid the originating endpoint id
     * @param dstEid the destination endpoint id
     */
    event RemoteTransfer(
        bytes32 indexed guid,
        bytes32 indexed from,
        bytes32 indexed to,
        uint256 amount,
        uint32 srcEid,
        uint32 dstEid
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
     * @dev Issues SUSDT by locking the accepted stable coin
     * @param amount the amount of asset to wrap
     */
    function issue(uint256 amount) external;

    /**
     * @dev Bridge SUSDT to the underlying asset, subject to liquidity availability
     * @param amount the amount of SUSDT to redeem for `currency`
     */
    function redeem(uint256 amount) external;

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

    /**
     * @dev Allow transfering `amount` from local chain to `dstEid` to `to`
     * @param dstEid destination endpoint ID.
     * @param to receipient address
     * @param amount value to transfer
     * @param gasDrop the amount of destination native token to send to `to`
     */
    function remoteTransfer(
        uint32 dstEid,
        bytes32 to,
        uint256 amount,
        uint128 gasDrop
    ) external payable;

    /**
     * @dev Allow transfering `amount` from local chain to `dstEid` to `to`
     * @param dstEid destination endpoint ID.
     * @param to receipient address
     * @param amount value to transfer
     * @param gasDrop the amount of destination native token to send to `to`
     * @param receiverValue the amount of destination native token for remote executions
     * @param payload the payload to attach to token transfer
     */
    function remoteTransferWithPayload(
        uint32 dstEid,
        bytes32 to,
        uint256 amount,
        uint128 gasDrop,
        uint64 receiverValue,
        bytes calldata payload
    ) external payable;

    /**
     * @dev Allow airdroping `dstEid` chain native token to `to`
     * @param dstEid destination chain endpoint identifier
     * @param receiver the receipient address
     * @param amount value of native token to airdrop
     */
    function airdrop(
        uint32 dstEid,
        bytes32 receiver,
        uint128 amount
    ) external payable;
}

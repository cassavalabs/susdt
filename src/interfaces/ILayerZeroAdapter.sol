// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Origin} from "./ILayerZeroEndpointV2.sol";

interface ILayerZeroAdapter {
    ///@notice Emitted when a new router contract is registered
    event RouterRegistered(uint32 eid, bytes32 router);

    /**
     * @notice Allows whitelisting a contract for peer communication
     * @param _eid layerZero endpoint ID
     * @param _router the router contract address
     */
    function registerRouter(uint32 _eid, bytes32 _router) external;

    /**
     * @notice Allow setting a delegate account for L0 configs
     * @param _delegate address to delegate to
     */
    function setDelegate(address _delegate) external;

    /**
     * @dev Allows setting required gas for destination execution
     * @param _dstEid the destination endpoint id
     * @param _msgType payload id
     * @param _gas the gas limit for payload execution
     */
    function setDestGas(uint32 _dstEid, uint8 _msgType, uint64 _gas) external;

    /**
     * @notice called to receive composed message
     * @param _from the src address
     * @param _guid guid of message
     * @param _message composed message
     * @param _executor the executor address
     * @param _extraData extra data from executor
     */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;

    /**
     * @notice Checks if the path initialization is allowed based on the provided origin.
     * @param _origin The origin information containing the source endpoint and sender address.
     * @return Whether the path has been initialized.
     *
     * @dev This indicates to the endpoint that the OApp has enabled msgs for
     * this particular path to be received.
     * @dev This defaults to assuming if a peer has been set, its initialized.
     * Can be overridden by the OApp if there is other logic to determine this.
     */
    function allowInitializePath(
        Origin calldata _origin
    ) external view returns (bool);

    /**
     * @notice Retrieves the next nonce for a given source endpoint and sender address.
     * @dev Is required by the off-chain executor to determine the OApp expects msg
     * execution to be ordered.
     *
     * @param _eid The source endpoint ID.
     * @param _sender The sender address.
     *
     * @return nonce The next nonce.
     */
    function nextNonce(
        uint32 _eid,
        bytes32 _sender
    ) external view returns (uint64);

    /**
     * @dev Entry point for receiving messages or packets from the endpoint.
     * @param _origin The origin information containing the source endpoint and sender address.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address on the src chain.
     *  - nonce: The nonce of the message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The payload of the received message.
     * @param _executor The address of the executor for the received message.
     * @param _extraData Additional arbitrary data provided by the corresponding executor.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the adapter contract.
     * @return receiverVersion The version of the adapter contract.
     *
     * @dev Providing 0 as the default for senderVersion. Indicates that
     * the senderVersion is not implemented.
     * ie. this is a SEND only OApp.
     * @dev If the OApp sends and receive messages, then this needs to be override
     * returning the correct versions.
     */
    function oAppVersion()
        external
        view
        returns (uint64 senderVersion, uint64 receiverVersion);
}

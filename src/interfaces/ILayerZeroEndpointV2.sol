// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

struct MessagingParams {
    uint32 dstEid;
    bytes32 receiver;
    bytes message;
    bytes options;
    bool payInLzToken;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

interface ILayerZeroEndpointV2 {
    function quote(
        MessagingParams calldata _params,
        address _sender
    ) external view returns (MessagingFee memory);

    function send(
        MessagingParams calldata _params,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory);

    /// @dev the Oapp sends the lzCompose message to the endpoint
    /// @dev the composer MUST assert the sender because anyone can send compose msg with this function
    /// @dev with the same GUID, the Oapp can send compose to multiple _composer at the same time
    /// @dev authenticated by the msg.sender
    /// @param _to the address which will receive the composed message
    /// @param _guid the message guid
    /// @param _message the message
    function sendCompose(
        address _to,
        bytes32 _guid,
        uint16 _index,
        bytes calldata _message
    ) external;

    function setLzToken(address _lzToken) external;

    function lzToken() external view returns (address);

    function nativeToken() external view returns (address);

    function setDelegate(address _delegate) external;
}

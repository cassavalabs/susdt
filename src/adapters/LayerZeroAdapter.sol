// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ILayerZeroAdapter} from "../interfaces/ILayerZeroAdapter.sol";
import {ILayerZeroEndpointV2, Origin, MessagingFee, MessagingParams, MessagingReceipt} from "../interfaces/ILayerZeroEndpointV2.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Authorization} from "../Authorization.sol";

import {BytesLib} from "../libraries/BytesLib.sol";
import {Currency} from "../libraries/Currency.sol";
import {Errors} from "../libraries/Errors.sol";
import {MessageType} from "../libraries/MessageType.sol";

abstract contract LayerZeroAdapter is Authorization, ILayerZeroAdapter {
    using BytesLib for bytes;
    using SafeCast for uint256;

    struct LzState {
        uint32 eid;
        // A map of chainId to connected contracts address
        mapping(uint32 => bytes32) routers;
        // A map of action type => gas
        mapping(uint32 => mapping(uint8 => uint64)) gasLookup;
    }

    uint64 internal constant ADAPTER_VERSION = 1;
    uint16 internal constant TYPE_3 = 3;
    uint8 internal constant WORKER_ID = 1;
    uint8 internal constant OPTION_TYPE_LZRECEIVE = 1;
    uint8 internal constant OPTION_TYPE_NATIVE_DROP = 2;
    uint8 internal constant OPTION_TYPE_LZCOMPOSE = 3;
    uint8 internal constant OPTION_TYPE_ORDERED_EXECUTION = 4;

    ILayerZeroEndpointV2 public immutable endpoint;
    LzState public lzState;

    constructor(address _endpoint, address _owner) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
        endpoint.setDelegate(_owner);
    }

    /// @inheritdoc ILayerZeroAdapter
    function registerRouter(
        uint32 _eid,
        bytes32 _router
    ) external override onlyOwner {
        lzState.routers[_eid] = _router;
        emit RouterRegistered(_eid, _router);
    }

    /// @inheritdoc ILayerZeroAdapter
    function setDestGas(
        uint32 _dstEid,
        uint8 _functionType,
        uint64 _gas
    ) external override onlyOwner {
        lzState.gasLookup[_dstEid][_functionType] = _gas;
    }

    /// @inheritdoc ILayerZeroAdapter
    function setDelegate(address _delegate) public override onlyOwner {
        endpoint.setDelegate(_delegate);
    }

    /// @inheritdoc ILayerZeroAdapter
    function allowInitializePath(
        Origin calldata origin
    ) public view override returns (bool) {
        return lzState.routers[origin.srcEid] == origin.sender;
    }

    /// @inheritdoc ILayerZeroAdapter
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable virtual {
        address _endpoint = address(endpoint);
        // Ensures the endpoint caller is layerZero
        if (_endpoint != msg.sender) revert Errors.OnlyEndpoint(_endpoint);

        // Ensures the message originates from a whitelisted router contract
        _ensureTrustedOrigin(_origin);

        // Call the internal OApp implementation of lzReceive.
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable override {
        _lzCompose(_from, _guid, _message, _executor, _extraData);
    }

    /// @inheritdoc ILayerZeroAdapter
    function oAppVersion()
        public
        pure
        override
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        senderVersion = ADAPTER_VERSION;
        receiverVersion = ADAPTER_VERSION;
    }

    /// @inheritdoc ILayerZeroAdapter
    function nextNonce(
        uint32 /*_srcEid*/,
        bytes32 /*_sender*/
    ) public view virtual returns (uint64) {
        return 0;
    }

    function _lzGasLookup(
        uint32 _dstEid,
        uint8 _msgType
    ) internal view returns (uint64) {
        uint64 gasLimit = lzState.gasLookup[_dstEid][_msgType];

        if (gasLimit == 0) {
            gasLimit = 200_000;
        }

        return gasLimit;
    }

    function _addExecutorOption(
        bytes memory _options,
        uint8 _optionType,
        bytes memory _option
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _options,
                WORKER_ID,
                _option.length.toUint16() + 1, // +1 for optionType
                _optionType,
                _option
            );
    }

    function _addNativeDropOption(
        bytes memory _options,
        uint128 _amount,
        bytes32 _receiver
    ) internal pure returns (bytes memory) {
        bytes memory option = abi.encodePacked(_amount, _receiver);
        return _addExecutorOption(_options, OPTION_TYPE_NATIVE_DROP, option);
    }

    function _basicOptions(
        uint32 _dstEid,
        uint8 _msgType,
        uint64 _value
    ) internal view returns (bytes memory _options) {
        bytes memory newOption = abi.encodePacked(TYPE_3);
        bytes memory _option = _value == 0
            ? abi.encodePacked(_lzGasLookup(_dstEid, _msgType))
            : abi.encodePacked(_lzGasLookup(_dstEid, _msgType), _value);
        _options = _addExecutorOption(
            newOption,
            OPTION_TYPE_LZRECEIVE,
            _option
        );
    }

    function _getEndpointRouter(
        uint32 _eid
    ) internal view returns (bytes32 router) {
        router = lzState.routers[_eid];

        if (router == bytes32(0)) revert Errors.InvalidRouter();
    }

    function _ensureTrustedOrigin(Origin calldata _origin) internal view {
        if (_getEndpointRouter(_origin.srcEid) != _origin.sender)
            revert Errors.UnAuthorizedRouter();
    }

    function _quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) internal view virtual returns (MessagingFee memory fee) {
        return
            endpoint.quote(
                MessagingParams(
                    _dstEid,
                    _getEndpointRouter(_dstEid),
                    _message,
                    _options,
                    _payInLzToken
                ),
                address(this)
            );
    }

    function _assertMessagingFee(MessagingFee memory _fee) internal {
        address lzToken = endpoint.lzToken();

        if (lzToken != address(0) && _fee.lzTokenFee > 0) {
            Currency.safeTransferFrom(
                lzToken,
                msg.sender,
                address(endpoint),
                _fee.lzTokenFee
            );
        } else {
            if (msg.value < _fee.nativeFee) revert Errors.InSufficientFee();
        }
    }

    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal returns (MessagingReceipt memory receipt) {
        /// Ensure valid message fee
        _assertMessagingFee(_fee);

        return
            // solhint-disable-next-line check-send-result
            endpoint.send{value: _fee.nativeFee}(
                MessagingParams(
                    _dstEid,
                    _getEndpointRouter(_dstEid),
                    _message,
                    _options,
                    _fee.lzTokenFee > 0
                ),
                _refundAddress
            );
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual;

    function _lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual {}
}

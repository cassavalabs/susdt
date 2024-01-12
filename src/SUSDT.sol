// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ISUSDT} from "./interfaces/ISUSDT.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Authorization} from "./Authorization.sol";
import {LayerZeroAdapter, MessagingFee, MessagingReceipt, Origin} from "./adapters/LayerZeroAdapter.sol";

import {AddressCast} from "./libraries/AddressCast.sol";
import {BytesLib} from "./libraries/BytesLib.sol";
import {Currency} from "./libraries/Currency.sol";
import {Errors} from "./libraries/Errors.sol";
import {MessageType} from "./libraries/MessageType.sol";

contract SUSDT is
    ISUSDT,
    Authorization,
    ERC20,
    ERC20Permit,
    Pausable,
    LayerZeroAdapter
{
    using Currency for address;
    using AddressCast for address;
    using AddressCast for bytes32;
    using SafeCast for uint256;
    using BytesLib for bytes;

    /// @notice the maximum supply allowed on this local chain
    uint256 private _limit;
    /// @dev Keep track of accepted stable
    address public immutable underlyingAsset;
    /// @dev Keep track of total value locked per asset
    uint256 public totalValueLocked;
    /// @dev Keeps track of malicious accounts denied access
    mapping(bytes32 => bool) private _denyListed;

    constructor(
        address _owner,
        address _endpoint,
        address _underlyingAsset
    )
        Authorization(_owner, _owner)
        ERC20("Synthmos USDT", "sUSDT")
        ERC20Permit("Synthmos USDT")
        LayerZeroAdapter(_endpoint, _owner)
    {
        underlyingAsset = _underlyingAsset;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @inheritdoc ISUSDT
    function recoverToken(
        address currency,
        address to,
        uint256 amount
    ) external override onlyOwner {
        if (currency == address(underlyingAsset))
            revert Errors.CurrencyAllowed();

        _ensureNotDenyListed(to.toBytes32());

        currency.transfer(to, amount);
    }

    /// @inheritdoc ISUSDT
    function issue(uint256 amount) external override {
        /// Lock the token and mint SUSDT wrapper token
        underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);

        unchecked {
            totalValueLocked += amount;
        }

        _mint(msg.sender, amount);
    }

    /// @inheritdoc ISUSDT
    function redeem(uint256 amount) external override {
        /// Ensure liquidity exists for redeeming the underlying asset
        if (totalValueLocked < amount) revert Errors.InsufficientLiquidity();

        /// Burn the equivalent SUSDT token before redeeming
        _burn(msg.sender, amount);

        unchecked {
            totalValueLocked -= amount;
        }

        underlyingAsset.safeTransferERC20(msg.sender, amount);
        emit Redeem(underlyingAsset, msg.sender, amount);
    }

    /// @inheritdoc ISUSDT
    function transferWithAuthorization(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        permit(from, to, amount, deadline, v, r, s);
        _spendAllowance(from, to, amount);
        _transfer(from, to, amount);
    }

    /// @inheritdoc ISUSDT
    function remoteTransfer(
        uint32 dstEid,
        bytes32 to,
        uint256 amount,
        uint128 gasDrop
    ) external payable override {
        bytes memory _message = abi.encodePacked(
            MessageType.TRANSFER,
            msg.sender.toBytes32(),
            to,
            amount.toUint64()
        );
        _remoteTransfer(
            msg.sender,
            dstEid,
            to,
            amount,
            gasDrop,
            0,
            MessageType.TRANSFER,
            _message
        );
    }

    /// @inheritdoc ISUSDT
    function remoteTransferWithPayload(
        uint32 dstEid,
        bytes32 to,
        uint256 amount,
        uint128 gasDrop,
        uint64 receiverValue,
        bytes calldata payload
    ) external payable override {
        bytes memory _message = abi.encodePacked(
            MessageType.TRANSFER_WITH_PAYLOAD,
            msg.sender.toBytes32(),
            to,
            amount.toUint64(),
            payload
        );

        _remoteTransfer(
            msg.sender,
            dstEid,
            to,
            amount,
            gasDrop,
            receiverValue,
            MessageType.TRANSFER_WITH_PAYLOAD,
            _message
        );
    }

    /// @inheritdoc ISUSDT
    function airdrop(
        uint32 dstEid,
        bytes32 receiver,
        uint128 amount
    ) external payable override {
        _airdrop(msg.sender, dstEid, receiver, amount);
    }

    /// @inheritdoc ISUSDT
    function denyList(bytes32 account) external override onlyOperator {
        if (_denyListed[account]) revert Errors.DenyListedAccount(account);

        _denyListed[account] = true;
        emit DenyList(account);
    }

    /// @inheritdoc ISUSDT
    function unDenyList(bytes32 account) external override onlyOperator {
        if (!_denyListed[account]) revert Errors.UnDenyListedAccount();

        _denyListed[account] = false;
        emit UnDenyList(account);
    }

    /// @inheritdoc ISUSDT
    function updateChainLimit(uint256 amount) external override onlyOwner {
        uint256 supply = totalSupply();
        if (amount <= supply) revert Errors.InValidChainLimit();

        _limit = amount;
    }

    /// @inheritdoc ISUSDT
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc ISUSDT
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ISUSDT
    function isDenyListed(
        bytes32 account
    ) external view override returns (bool) {
        return _denyListed[account];
    }

    function _ensureNotDenyListed(bytes32 account) internal view {
        if (_denyListed[account]) revert Errors.DenyListedAccount(account);
    }

    function _ensureAllowedCurrency(address _currency) internal view {
        if (_currency != address(underlyingAsset))
            revert Errors.InvalidUnderlyingCurrency(_currency);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal override {
        _ensureNotDenyListed(owner.toBytes32());
        _ensureNotDenyListed(spender.toBytes32());

        super._approve(owner, spender, value, emitEvent);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        _ensureNotDenyListed(from.toBytes32());
        _ensureNotDenyListed(to.toBytes32());

        super._update(from, to, value);

        if (from == address(0)) {
            uint256 supply = totalSupply();

            if (supply > _limit) revert Errors.ChainLimitReached(_limit);
        }
    }

    function _remoteTransfer(
        address _caller,
        uint32 _dstEid,
        bytes32 _to,
        uint256 _amount,
        uint128 _gasDrop,
        uint64 _receiverValue,
        uint8 _msgType,
        bytes memory _message
    ) internal {
        bytes memory _option = _basicOptions(_dstEid, _msgType, _receiverValue);
        bytes memory _options = _gasDrop == 0
            ? _option
            : _addNativeDropOption(_option, _gasDrop, _to);

        MessagingFee memory _fee = _quote(_dstEid, _message, _options, false);

        /// Burn the users local SUSDT balance and dispatch remote call to mint
        _burn(_caller, _amount);
        MessagingReceipt memory msgReceipt = _lzSend(
            _dstEid,
            _message,
            _options,
            _fee,
            _caller
        );
        emit RemoteTransfer(
            msgReceipt.guid,
            _caller.toBytes32(),
            _to,
            _amount,
            lzState.eid,
            _dstEid
        );
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /**_executor*/,
        bytes calldata /**_extraData*/
    ) internal override {
        uint8 _msgType = _message.toUint8(0);

        bytes32 from = _message.toBytes32(1);
        bytes32 to = _message.toBytes32(33);
        uint64 amount = _message.toUint64(65);

        _mint(to.toAddress(), amount);

        if (_msgType == MessageType.TRANSFER_WITH_PAYLOAD) {
            bytes memory _payload = _message.slice(73, _message.length);
            bytes memory _composedMsg = abi.encodePacked(
                msg.sender,
                _origin.nonce,
                _origin.srcEid,
                amount,
                _payload
            );

            endpoint.sendCompose(to.toAddress(), _guid, 0, _composedMsg);
        }

        emit RemoteTransfer(
            _guid,
            from,
            to,
            amount,
            _origin.srcEid,
            lzState.eid
        );
    }

    receive() external payable virtual {}
}

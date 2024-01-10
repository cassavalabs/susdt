// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ISUSDT} from "./interfaces/ISUSDT.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Authorization} from "./Authorization.sol";

import {AddressCast} from "./libraries/AddressCast.sol";
import {Currency} from "./libraries/Currency.sol";
import {Errors} from "./libraries/Errors.sol";

contract SUSDT is ISUSDT, Authorization, ERC20, ERC20Permit, Pausable {
    using Currency for address;
    using AddressCast for address;
    using AddressCast for bytes32;

    /// @notice the maximum supply allowed on this local chain
    uint256 private _limit;

    /// @dev Keep track of accepted stables
    mapping(address currency => bool supported) public currencies;
    /// @dev Keep track of total value locked per asset
    mapping(address currency => uint256 reserve) public totalValueLocked;
    /// @dev Keeps track of malicious accounts denied access
    mapping(bytes32 => bool) private _denyListed;

    constructor(
        address _owner
    )
        Authorization(_owner, _owner)
        ERC20("Synthmos USDT", "sUSDT")
        ERC20Permit("Synthmos USDT")
    {}

    /// @inheritdoc ISUSDT
    function allowCurrency(address currency) external override onlyOwner {
        if (currencies[currency]) revert Errors.CurrencyAllowed();

        currencies[currency] = true;
        emit AllowCurrency(currency);
    }

    /// @inheritdoc ISUSDT
    function recoverToken(
        address currency,
        address to,
        uint256 amount
    ) external override onlyOwner {
        if (currencies[currency]) revert Errors.CurrencyAllowed();

        _ensureNotDenyListed(to.toBytes32());

        currency.transfer(to, amount);
    }

    /// @inheritdoc ISUSDT
    function issue(address currency, uint256 amount) external override {
        _ensureAllowedCurrency(currency);
        _ensureNotDenyListed(msg.sender.toBytes32());

        /// Lock the token and mint SUSDT wrapper token
        currency.safeTransferFrom(msg.sender, address(this), amount);

        unchecked {
            totalValueLocked[currency] += amount;
        }

        _mint(msg.sender, amount);
    }

    /// @inheritdoc ISUSDT
    function redeem(address currency, uint256 amount) external override {
        _redeem(currency, msg.sender, amount);
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
    function redeemWithAuthorization(
        address currency,
        address from,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        permit(from, address(this), amount, deadline, v, r, s);
        _redeem(currency, from, amount);
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
        if (!currencies[_currency])
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

    function _redeem(
        address currency,
        address account,
        uint256 amount
    ) internal {
        _ensureAllowedCurrency(currency);

        if (totalValueLocked[currency] < amount)
            revert Errors.InsufficientLiquidity();

        /// Burn the equivalent SUSDT token before redeeming
        _burn(account, amount);

        unchecked {
            totalValueLocked[currency] -= amount;
        }

        currency.safeTransferERC20(account, amount);
        emit Redeem(currency, account, amount);
    }
}

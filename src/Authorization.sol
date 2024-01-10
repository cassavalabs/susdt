// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.19;

/**
 * @title Authorization
 * @author iphyman
 * @notice This is a simple account authorization contract
 */
abstract contract Authorization {
    address public owner;
    address public operator;

    /**
     * @notice Emitted whenever the protocol's operator is changed
     * @param prevOperator the previous operator address
     * @param newOperator the new operator address
     */
    event OperatorChanged(
        address indexed prevOperator,
        address indexed newOperator
    );

    /**
     * @notice Emitted whenever the protocol's ownership changes
     * @param prevOwner the previous owner address
     * @param newOwner the new owner address
     */
    event OwnerChanged(address indexed prevOwner, address indexed newOwner);

    ///@notice Revert when `msg.sender` is not a privileged user
    error UnAuthorized();

    ///@notice Revert when `msg.sender` is not a previleged operator
    error NotOperator();

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert UnAuthorized();
        _;
    }

    modifier onlyOperator() virtual {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _owner, address _operator) {
        owner = _owner;
        operator = _operator;

        emit OperatorChanged(address(0), _operator);
        emit OwnerChanged(address(0), _owner);
    }

    /**
     * @notice Allows owner to transfer contract ownership
     * @param newOwner address of the new owner
     */
    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;

        emit OwnerChanged(msg.sender, newOwner);
    }

    /**
     * @notice Allows owner to set new operator
     * @param newOperator address of the new operator
     */
    function setOperator(address newOperator) external onlyOwner {
        operator = newOperator;

        emit OperatorChanged(msg.sender, newOperator);
    }
}

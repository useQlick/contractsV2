// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IQUSD} from "../interfaces/IQUSD.sol";

/// @title QUSD
/// @notice Qlick USD - Virtual USD token used for liquidity provisioning and trading in prediction markets
/// @dev Only the Market contract can mint/burn QUSD tokens
contract QUSD is ERC20, Ownable, IQUSD {
    /// @notice Address authorized to mint and burn tokens (typically the Market contract)
    address public minter;

    /// @notice Emitted when the minter address is updated
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    error UnauthorizedMinter(address caller);
    error ZeroAddress();

    modifier onlyMinter() {
        if (msg.sender != minter) revert UnauthorizedMinter(msg.sender);
        _;
    }

    /// @param initialOwner Address that will own this contract (can set minter)
    constructor(address initialOwner) ERC20("Qlick USD", "QUSD") Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    /// @notice Set the authorized minter address
    /// @param _minter Address of the Market contract
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();
        address oldMinter = minter;
        minter = _minter;
        emit MinterUpdated(oldMinter, _minter);
    }

    /// @inheritdoc IQUSD
    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0)) revert ZeroAddress();
        _mint(to, amount);
    }

    /// @inheritdoc IQUSD
    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}


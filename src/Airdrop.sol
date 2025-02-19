// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Airdrop
 * @dev This contract facilitates an airdrop mechanism utilizing a Merkle tree for efficient and secure claims.
 * The contract allows only the owner to set the Merkle root, pause the contract, and withdraw remaining tokens.
 */
contract Airdrop is Ownable {
    IERC20 public token; // ERC20 token contract that will be distributed through the airdrop
    bytes32 public merkleRoot; // Merkle root for validating claims
    bool public paused; // Flag to control the active state of the contract

    mapping(address => bool) public hasClaimed; // Mapping to track whether an address has already claimed tokens

    error InsufficientBalance(); // Custom error for insufficient balance during withdrawal
    error ZeroAddress(); // Custom error for zero address checks
    error InvalidProof(); // Custom error for invalid Merkle proof
    error AlreadyClaimed(); // Custom error for claims that have already been made
    error TransferFailed(); // Custom error for failed token transfers
    error ContractPaused(); // Custom error for actions taken while the contract is paused
    error InvalidAmount(); // Custom error for invalid withdrawal amounts

    event TokensClaimed(address indexed recipient, uint256 amount); // Event emitted when tokens are successfully claimed

    /**
     * @dev Constructor to initialize the contract with the token address.
     * @param tokenAddress The address of the ERC20 token to be used for the airdrop.
     */
    constructor(address tokenAddress) Ownable(msg.sender) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        token = IERC20(tokenAddress);
    }

    // Modifier to ensure the function can only be executed when the contract is not paused
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /**
     * @dev Allows the owner to set the Merkle root for claims.
     * @param _merkleRoot The new Merkle root to be set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev Claims tokens for the caller if they provide a valid Merkle proof.
     * @param amount The amount of tokens to claim.
     * @param merkleProof The Merkle proof validating the claim.
     */
    function claim(uint256 amount, bytes32[] calldata merkleProof) external whenNotPaused {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        // Validate the Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert InvalidProof();

        // Record the claim status
        hasClaimed[msg.sender] = true;

        // Transfer tokens to the caller
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit TokensClaimed(msg.sender, amount);
    }

    /**
     * @dev Allows the owner to withdraw remaining tokens from the contract.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        if (token.balanceOf(address(this)) < amount) revert InsufficientBalance();

        bool success = token.transfer(owner(), amount);
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Allows the owner to pause or unpause the contract.
     * @param _paused Boolean value indicating the desired pause state.
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /**
     * @dev Returns the balance of the contract in the ERC20 token.
     * @return The current balance of the contract.
     */
    function contractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

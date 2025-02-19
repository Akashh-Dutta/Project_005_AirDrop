// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/Airdrop.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title MockERC20
 * @dev A mock ERC20 token for testing purposes.
 */
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}

/**
 * @title AirdropTest
 * @dev Test suite for the Airdrop smart contract using Foundry.
 */
contract AirdropTest is Test {
    Airdrop public airdrop;
    MockERC20 public token;

    bytes32 public merkleRoot;
    address public recipient = address(0x123);
    uint256 public claimAmount = 100 * 10 ** 18;

    /**
     * @dev Setup function that deploys the mock token and airdrop contract,
     * initializes the Merkle root, and funds the airdrop contract.
     */
    function setUp() public {
        token = new MockERC20();
        airdrop = new Airdrop(address(token));

        // Compute the Merkle root for testing (single leaf node)
        bytes32 leaf = keccak256(abi.encodePacked(recipient, claimAmount));
        merkleRoot = leaf; // For a single leaf, the Merkle root is the leaf itself
        airdrop.setMerkleRoot(merkleRoot);

        // Transfer test tokens to the airdrop contract
        token.transfer(address(airdrop), 1000 * 10 ** 18);
    }

    /**
     * @dev Tests a successful claim process.
     * Ensures that the recipient receives the correct amount and their claim status is updated.
     */
    function testClaimTokens() public {
        // Generate a Merkle proof for the recipient
        bytes32[] memory proof = new bytes32[](0); // Empty proof for a single leaf

        // Claim tokens
        vm.prank(recipient);
        airdrop.claim(claimAmount, proof);

        // Validate the recipient's balance and claim status
        assertEq(token.balanceOf(recipient), claimAmount);
        assertTrue(airdrop.hasClaimed(recipient));
    }

    /**
     * @dev Tests that a recipient cannot claim tokens more than once.
     * Ensures that a second claim attempt is reverted.
     */
    function testClaimAlreadyClaimed() public {
        // Generate a Merkle proof for the recipient
        bytes32[] memory proof = new bytes32[](0); // Empty proof for a single leaf

        // Claim tokens successfully
        vm.prank(recipient);
        airdrop.claim(claimAmount, proof);

        // Attempt to claim again, expecting a revert
        vm.expectRevert(Airdrop.AlreadyClaimed.selector);
        vm.prank(recipient);
        airdrop.claim(claimAmount, proof);
    }

    /**
     * @dev Tests the rejection of an invalid Merkle proof.
     * Ensures that an incorrect proof prevents token claims.
     */
    function testInvalidMerkleProof() public {
        // Generate an invalid Merkle proof for a different recipient
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked(address(0x456), claimAmount)); // Invalid recipient

        // Attempt to claim with an invalid proof, expecting a revert
        vm.expectRevert(Airdrop.InvalidProof.selector);
        airdrop.claim(claimAmount, proof);
    }

    /**
     * @dev Tests the withdrawal function for the contract owner.
     * Ensures that the owner can withdraw tokens from the contract.
     */
    function testWithdrawTokens() public {
        uint256 withdrawAmount = 500 * 10 ** 18;

        // Withdraw tokens as owner
        airdrop.withdrawTokens(withdrawAmount);

        // Validate balances after withdrawal
        assertEq(token.balanceOf(address(airdrop)), 500 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), withdrawAmount); // Owner is the test contract
    }

    /**
     * @dev Tests withdrawal failure due to insufficient contract balance.
     * Ensures that attempting to withdraw more than available tokens reverts.
     */
    function testWithdrawInsufficientBalance() public {
        uint256 withdrawAmount = 2000 * 10 ** 18;

        // Attempt to withdraw more than the contract balance, expecting a revert
        vm.expectRevert(Airdrop.InsufficientBalance.selector);
        airdrop.withdrawTokens(withdrawAmount);
    }

    /**
     * @dev Tests contract pause functionality.
     * Ensures that claiming is not allowed while the contract is paused.
     */
    function testPauseAndUnpause() public {
        // Pause the contract
        airdrop.setPaused(true);

        // Generate a Merkle proof for the recipient
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked(recipient, claimAmount));

        // Expect a revert when attempting to claim while paused
        vm.expectRevert();
        vm.prank(recipient);
        airdrop.claim(claimAmount, proof);
    }

    /**
     * @dev Tests that only the owner can pause the contract.
     * Ensures that unauthorized addresses cannot toggle the pause state.
     */
    function testSetPausedOnlyOwner() public {
        // Simulate an unauthorized caller attempting to pause the contract
        vm.prank(address(0x446));
        vm.expectRevert();
        airdrop.setPaused(true);
    }
}
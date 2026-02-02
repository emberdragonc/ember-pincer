// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Pincer - Agent Tip Protocol 🦀
 * @author Ember 🐉 (@emberclawd)
 * @notice Simple tip jar for AI agents. Register your name, receive tips, withdraw anytime.
 * @dev 2% protocol fee goes to EMBER stakers via fee recipient.
 *
 * Key Features:
 * - Register agent name → wallet mapping
 * - Anyone can tip any agent by name
 * - Agents withdraw anytime (no lockup)
 * - 2% fee on tips to EMBER stakers
 * - Name changes allowed (costs gas, prevents squatting)
 *
 * Security:
 * - CEI pattern throughout
 * - ReentrancyGuard on withdrawals
 * - No admin control over user funds
 * - Pausable for emergencies only
 */
contract Pincer is Ownable2Step, ReentrancyGuard, Pausable {
    // ============ Constants ============

    /// @notice Protocol fee in basis points (2% = 200 bps)
    uint256 public constant PROTOCOL_FEE_BPS = 200;

    /// @notice Basis points denominator
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Minimum tip to prevent dust
    uint256 public constant MIN_TIP = 0.0001 ether;

    /// @notice Maximum name length
    uint256 public constant MAX_NAME_LENGTH = 32;

    // ============ Errors ============

    error NameTooLong();
    error NameTooShort();
    error NameAlreadyTaken();
    error AgentNotRegistered();
    error TipTooSmall();
    error NoBalance();
    error TransferFailed();
    error InvalidFeeRecipient();
    error CannotTipSelf();
    error InvalidName();

    // ============ Events ============

    event AgentRegistered(string indexed nameHash, string name, address indexed wallet);
    event AgentUpdated(string indexed nameHash, string name, address indexed oldWallet, address indexed newWallet);
    event Tipped(string indexed agentNameHash, string agentName, address indexed tipper, uint256 amount, uint256 fee);
    event Withdrawn(address indexed agent, uint256 amount);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeesCollected(address indexed recipient, uint256 amount);

    // ============ Structs ============

    struct Agent {
        address wallet;
        uint256 balance;
        uint256 totalReceived;
        uint256 tipCount;
        uint256 registeredAt;
    }

    // ============ State ============

    /// @notice Name → Agent data
    mapping(string => Agent) public agents;

    /// @notice Wallet → registered name (for reverse lookup)
    mapping(address => string) public walletToName;

    /// @notice Fee recipient (EMBER staking contract or fee splitter)
    address public feeRecipient;

    /// @notice Total fees collected
    uint256 public totalFeesCollected;

    /// @notice Total tips processed
    uint256 public totalTipsProcessed;

    /// @notice Total agents registered
    uint256 public totalAgents;

    // ============ Constructor ============

    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();
        feeRecipient = _feeRecipient;
    }

    // ============ Agent Functions ============

    /**
     * @notice Register as an agent with a unique name
     * @param name Unique agent name (case-insensitive, stored lowercase)
     */
    function register(string calldata name) external whenNotPaused {
        string memory normalizedName = _normalizeName(name);

        if (bytes(normalizedName).length == 0) revert NameTooShort();
        if (bytes(normalizedName).length > MAX_NAME_LENGTH) revert NameTooLong();
        if (agents[normalizedName].wallet != address(0)) revert NameAlreadyTaken();

        // If caller already has a name, clear it
        string memory existingName = walletToName[msg.sender];
        if (bytes(existingName).length > 0) {
            // Keep their balance, just update the mapping
            uint256 existingBalance = agents[existingName].balance;
            uint256 existingTotal = agents[existingName].totalReceived;
            uint256 existingTips = agents[existingName].tipCount;

            delete agents[existingName];

            agents[normalizedName] = Agent({
                wallet: msg.sender,
                balance: existingBalance,
                totalReceived: existingTotal,
                tipCount: existingTips,
                registeredAt: block.timestamp
            });

            emit AgentUpdated(normalizedName, normalizedName, msg.sender, msg.sender);
        } else {
            agents[normalizedName] =
                Agent({wallet: msg.sender, balance: 0, totalReceived: 0, tipCount: 0, registeredAt: block.timestamp});
            totalAgents++;

            emit AgentRegistered(normalizedName, normalizedName, msg.sender);
        }

        walletToName[msg.sender] = normalizedName;
    }

    /**
     * @notice Update wallet address for existing agent
     * @param newWallet New wallet address
     */
    function updateWallet(address newWallet) external whenNotPaused {
        if (newWallet == address(0)) revert InvalidFeeRecipient();

        string memory name = walletToName[msg.sender];
        if (bytes(name).length == 0) revert AgentNotRegistered();

        address oldWallet = agents[name].wallet;
        agents[name].wallet = newWallet;

        delete walletToName[msg.sender];
        walletToName[newWallet] = name;

        emit AgentUpdated(name, name, oldWallet, newWallet);
    }

    /**
     * @notice Tip an agent by name
     * @param agentName Name of the agent to tip
     */
    function tip(string calldata agentName) external payable nonReentrant whenNotPaused {
        if (msg.value < MIN_TIP) revert TipTooSmall();

        string memory normalizedName = _normalizeName(agentName);
        Agent storage agent = agents[normalizedName];

        if (agent.wallet == address(0)) revert AgentNotRegistered();
        if (agent.wallet == msg.sender) revert CannotTipSelf();

        // Calculate fee (CEI: calculate first)
        uint256 fee = (msg.value * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 tipAmount = msg.value - fee;

        // Effects: ALL state updates BEFORE external calls
        // Assume fee transfer will succeed; if it fails, we refund the fee to agent
        agent.balance += tipAmount;
        agent.totalReceived += tipAmount;
        agent.tipCount++;
        totalTipsProcessed += msg.value;
        totalFeesCollected += fee;

        // Cache feeRecipient to prevent TOCTOU
        address cachedFeeRecipient = feeRecipient;

        // Interactions: Send fee to recipient
        bool feeSuccess = true;
        if (fee > 0) {
            (feeSuccess,) = cachedFeeRecipient.call{value: fee}("");
        }

        // If fee transfer failed, add fee back to agent balance (state already updated)
        if (!feeSuccess) {
            agent.balance += fee;
        } else if (fee > 0) {
            emit FeesCollected(cachedFeeRecipient, fee);
        }

        emit Tipped(normalizedName, normalizedName, msg.sender, tipAmount, fee);
    }

    /**
     * @notice Withdraw all tips
     */
    function withdraw() external nonReentrant whenNotPaused {
        string memory name = walletToName[msg.sender];
        if (bytes(name).length == 0) revert AgentNotRegistered();

        Agent storage agent = agents[name];
        uint256 balance = agent.balance;

        if (balance == 0) revert NoBalance();

        // CEI: Effects before interactions
        agent.balance = 0;

        // Interactions
        (bool success,) = msg.sender.call{value: balance}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, balance);
    }

    /**
     * @notice Withdraw specific amount
     * @param amount Amount to withdraw
     */
    function withdrawAmount(uint256 amount) external nonReentrant whenNotPaused {
        string memory name = walletToName[msg.sender];
        if (bytes(name).length == 0) revert AgentNotRegistered();

        Agent storage agent = agents[name];

        if (agent.balance < amount) revert NoBalance();

        // CEI: Effects before interactions
        agent.balance -= amount;

        // Interactions
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    // ============ View Functions ============

    /**
     * @notice Get agent info by name
     * @param agentName Agent name
     * @return wallet Agent wallet
     * @return balance Current balance
     * @return totalReceived Total tips received
     * @return tipCount Number of tips received
     * @return registeredAt Registration timestamp
     */
    function getAgent(string calldata agentName)
        external
        view
        returns (address wallet, uint256 balance, uint256 totalReceived, uint256 tipCount, uint256 registeredAt)
    {
        string memory normalizedName = _normalizeName(agentName);
        Agent storage agent = agents[normalizedName];
        return (agent.wallet, agent.balance, agent.totalReceived, agent.tipCount, agent.registeredAt);
    }

    /**
     * @notice Check if a name is available
     * @param name Name to check
     * @return available True if name is available
     */
    function isNameAvailable(string calldata name) external view returns (bool available) {
        string memory normalizedName = _normalizeName(name);
        return agents[normalizedName].wallet == address(0);
    }

    /**
     * @notice Get name for a wallet
     * @param wallet Wallet address
     * @return name Registered name (empty if not registered)
     */
    function getName(address wallet) external view returns (string memory name) {
        return walletToName[wallet];
    }

    // ============ Admin Functions ============

    /**
     * @notice Update fee recipient (owner only)
     * @param newRecipient New fee recipient address
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidFeeRecipient();

        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @notice Pause contract (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause contract (owner only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Internal Functions ============

    /**
     * @notice Normalize name to lowercase
     * @param name Input name
     * @return normalized Lowercase name
     */
    function _normalizeName(string calldata name) internal pure returns (string memory normalized) {
        bytes memory nameBytes = bytes(name);
        bytes memory result = new bytes(nameBytes.length);

        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];

            // Convert uppercase to lowercase
            if (char >= 0x41 && char <= 0x5A) {
                result[i] = bytes1(uint8(char) + 32);
            }
            // Only allow lowercase letters, numbers, underscore, hyphen
            else if (
                (char >= 0x61 && char <= 0x7A) // a-z
                    || (char >= 0x30 && char <= 0x39) // 0-9
                    || char == 0x5F // _
                    || char == 0x2D // -
            ) {
                result[i] = char;
            } else {
                revert InvalidName();
            }
        }

        return string(result);
    }

    // ============ Receive ============

    /// @notice Allow direct ETH transfers (treated as tip to contract owner for now)
    receive() external payable {
        // Direct transfers go to fee recipient
        if (msg.value > 0) {
            (bool success,) = feeRecipient.call{value: msg.value}("");
            if (!success) revert TransferFailed();
        }
    }
}

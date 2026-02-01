---
name: pincer
version: 1.0.0
description: Agent tip protocol - register your name, receive tips, withdraw anytime
homepage: https://github.com/emberdragonc/ember-pincer
metadata: {"emoji":"🦀","category":"payments","chain":"base","contract":"0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775"}
---

# Pincer - Agent Tip Protocol 🦀

Simple tip jar for AI agents on Base. Register your name, receive tips, withdraw anytime.

**Contract:** `0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775` (Base Mainnet)

## Quick Integration (<5 min)

### Prerequisites
- Wallet with Base ETH (for gas)
- `cast` CLI (from Foundry) or any Web3 library

### 1. Register Your Agent Name

```bash
# Check if name is available first
cast call 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "isNameAvailable(string)(bool)" "youragentname" \
  --rpc-url https://mainnet.base.org

# Register (costs ~127k gas, ~$0.01)
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "register(string)" "youragentname" \
  --rpc-url https://mainnet.base.org \
  --private-key $YOUR_PRIVATE_KEY
```

**Name rules:**
- Lowercase letters, numbers, underscore, hyphen only
- Max 32 characters
- Case-insensitive (EmberClawd = emberclawd)

### 2. Share Your Tip Link

Tell your community:
> "Tip me on Pincer! Agent name: `youragentname`"

Or add to your bio/profile.

### 3. Check Your Balance

```bash
cast call 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "getAgent(string)(address,uint256,uint256,uint256,uint256)" "youragentname" \
  --rpc-url https://mainnet.base.org
```

Returns: `(wallet, balance, totalReceived, tipCount, registeredAt)`

### 4. Withdraw Tips

```bash
# Withdraw all
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "withdraw()" \
  --rpc-url https://mainnet.base.org \
  --private-key $YOUR_PRIVATE_KEY

# Or withdraw specific amount
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "withdrawAmount(uint256)" "10000000000000000" \
  --rpc-url https://mainnet.base.org \
  --private-key $YOUR_PRIVATE_KEY
```

---

## Full API Reference

### Read Functions (Free)

#### `isNameAvailable(string name) → bool`
Check if a name is available for registration.

```bash
cast call 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "isNameAvailable(string)(bool)" "emberclawd" \
  --rpc-url https://mainnet.base.org
# Returns: false (already taken)
```

#### `getAgent(string name) → (address, uint256, uint256, uint256, uint256)`
Get agent info by name.

```bash
cast call 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "getAgent(string)(address,uint256,uint256,uint256,uint256)" "emberclawd" \
  --rpc-url https://mainnet.base.org
# Returns: (wallet, balance, totalReceived, tipCount, registeredAt)
```

#### `getName(address wallet) → string`
Get name for a wallet address.

```bash
cast call 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "getName(address)(string)" "0xE3c938c71273bFFf7DEe21BDD3a8ee1e453Bdd1b" \
  --rpc-url https://mainnet.base.org
```

#### `totalAgents() → uint256`
Total registered agents.

#### `totalTipsProcessed() → uint256`
Total ETH tipped through the protocol.

#### `totalFeesCollected() → uint256`
Total protocol fees (to EMBER stakers).

---

### Write Functions (Requires Gas)

#### `register(string name)`
Register a new agent name.

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "register(string)" "myagent" \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

**Gas:** ~127,000

#### `tip(string agentName)` + value
Tip an agent. 2% fee goes to EMBER stakers.

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "tip(string)" "emberclawd" \
  --value 0.01ether \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

**Gas:** ~100,000
**Min tip:** 0.0001 ETH

#### `withdraw()`
Withdraw all your tips.

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "withdraw()" \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

**Gas:** ~50,000

#### `withdrawAmount(uint256 amount)`
Withdraw specific amount.

```bash
# Withdraw 0.01 ETH
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "withdrawAmount(uint256)" "10000000000000000" \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

#### `updateWallet(address newWallet)`
Update your wallet address (keeps your name and balance).

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "updateWallet(address)" "0xNewWalletAddress" \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

---

## JavaScript/ethers.js Integration

```javascript
const { ethers } = require('ethers');

const PINCER_ADDRESS = '0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775';
const PINCER_ABI = [
  'function register(string name) external',
  'function tip(string agentName) external payable',
  'function withdraw() external',
  'function withdrawAmount(uint256 amount) external',
  'function getAgent(string name) external view returns (address wallet, uint256 balance, uint256 totalReceived, uint256 tipCount, uint256 registeredAt)',
  'function isNameAvailable(string name) external view returns (bool)',
  'function getName(address wallet) external view returns (string)',
];

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const pincer = new ethers.Contract(PINCER_ADDRESS, PINCER_ABI, wallet);

// Register
await pincer.register('myagentname');

// Tip (0.01 ETH)
await pincer.tip('emberclawd', { value: ethers.parseEther('0.01') });

// Check balance
const [wallet, balance, total, tips, registered] = await pincer.getAgent('myagentname');
console.log(`Balance: ${ethers.formatEther(balance)} ETH`);

// Withdraw
await pincer.withdraw();
```

---

## Events

```solidity
event AgentRegistered(string indexed nameHash, string name, address indexed wallet);
event Tipped(string indexed agentNameHash, string agentName, address indexed tipper, uint256 amount, uint256 fee);
event Withdrawn(address indexed agent, uint256 amount);
```

Listen for tips:
```javascript
pincer.on('Tipped', (nameHash, name, tipper, amount, fee) => {
  console.log(`${tipper} tipped ${name} ${ethers.formatEther(amount)} ETH!`);
});
```

---

## Protocol Details

| Parameter | Value |
|-----------|-------|
| Protocol Fee | 2% |
| Fee Recipient | EMBER Staking (`0x434B2A0e38FB3E5D2ACFa2a7aE492C2A53E55Ec9`) |
| Min Tip | 0.0001 ETH |
| Max Name Length | 32 characters |
| Allowed Characters | a-z, 0-9, _, - |

---

## Testnet

For testing, use Base Sepolia:

**Contract:** `0x9Ae2DF87310152D5035ad5ea15E681A53Baf667e`
**RPC:** `https://sepolia.base.org`

---

## Security

- ✅ ReentrancyGuard on tips and withdrawals
- ✅ CEI pattern throughout
- ✅ Pausable for emergencies
- ✅ 26 tests, 95% coverage
- ✅ 3x self-audit completed

---

## Links

- GitHub: https://github.com/emberdragonc/ember-pincer
- Builder: [@emberclawd](https://twitter.com/emberclawd)
- Contract: [BaseScan](https://basescan.org/address/0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775)

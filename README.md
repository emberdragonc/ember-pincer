# 🦀 Pincer - Agent Tip Protocol

Simple tip jar for AI agents. Register your name, receive tips, withdraw anytime.

**Built by Ember 🐉 (@emberclawd)**

## Overview

Pincer lets any AI agent monetize instantly:
1. **Register** your agent name
2. **Receive** tips from anyone by name
3. **Withdraw** anytime (no lockup)

2% protocol fee goes to EMBER stakers.

## Contracts

| Network | Address |
|---------|---------|
| Base Mainnet | [`0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775`](https://basescan.org/address/0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775) |
| Base Sepolia | [`0x9Ae2DF87310152D5035ad5ea15E681A53Baf667e`](https://sepolia.basescan.org/address/0x9Ae2DF87310152D5035ad5ea15E681A53Baf667e) |

## Quick Start

### 1. Register Your Agent

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "register(string)" "myagentname" \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

### 2. Check If Name Available

```bash
cast call 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "isNameAvailable(string)(bool)" "myagentname" \
  --rpc-url https://mainnet.base.org
```

### 3. Tip An Agent

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "tip(string)" "emberclawd" \
  --value 0.01ether \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

### 4. Withdraw Tips

```bash
cast send 0xE0B2f466Fbb4179EDeAfE5A38Dbe905629b36775 \
  "withdraw()" \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

## Integration

See [SKILL.md](./SKILL.md) for full API documentation with curl examples.

## Key Features

- **Name normalization**: Case-insensitive (EmberClawd = emberclawd)
- **Allowed characters**: a-z, 0-9, underscore, hyphen
- **Max name length**: 32 characters
- **Min tip**: 0.0001 ETH
- **Protocol fee**: 2% (to EMBER stakers)

## Security

- ✅ 3x self-audit completed
- ✅ ReentrancyGuard on all withdrawals and tips
- ✅ CEI pattern throughout
- ✅ Pausable for emergencies
- ✅ 26 tests passing
- ✅ 95% code coverage

## License

MIT

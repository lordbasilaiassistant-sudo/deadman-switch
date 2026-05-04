# DeadManSwitch — On-Chain Inheritance & Liveness Beacon for Base

A minimal, immutable, permissionless dead-man switch on **Base mainnet**. Lock ETH, ping it on a schedule. If you stop pinging, the funds route to your beneficiary. Anyone can trigger the payout for a small bounty.

- **Use cases:** estate planning, wallet-compromise hedge, founder vesting fallback, multi-year "if I disappear" payouts.
- **Trust model:** non-upgradeable, no admin keys after deploy, no whitelist, no oracle.
- **Cost:** 0.5% fee on register, 0.5% bounty on trigger. Both capped at 5% (immutable).

## Live deployment

| Network | Address | Verified |
|---|---|---|
| Base mainnet (8453) | [`0x40f1AAb4c82D48260Ab1207e27329d51290025DB`](https://basescan.org/address/0x40f1aab4c82d48260ab1207e27329d51290025db) | ✓ |
| Base Sepolia (84532) | [`0x495fbeb17eCB16694f83Ed2A48EBCf59CD9D20AE`](https://sepolia.basescan.org/address/0x495fbeb17eCB16694f83Ed2A48EBCf59CD9D20AE) | ✓ |

Mainnet parameters: `minInterval=1h`, `maxInterval=10y`. Treasury `0x7a3E312Ec6e20a9F62fE2405938EB9060312E334`.

## Interface

```solidity
function register(address beneficiary, uint64 intervalSeconds) external payable returns (uint256 id);
function ping(uint256 id) external;
function trigger(uint256 id) external;       // anyone, after deadline → bounty to caller
function cancel(uint256 id) external;        // owner only, before deadline
function isAlive(uint256 id) external view returns (bool);
```

Full ABI: `out/DeadManSwitch.sol/DeadManSwitch.json` after `forge build`.

## Why on-chain

- **No subscription:** no off-chain keeper to pay, anyone earns the bounty for triggering.
- **No SaaS dependency:** if our website disappears, the contract still works.
- **Verifiable behavior:** integration test on Sepolia matched expected payouts to the wei.

## Build / test

```bash
forge install
forge build
forge test -vv
```

Deploy to Base mainnet:
```bash
THRYXTREASURY_PRIVATE_KEY=0x... forge script script/Mainnet.s.sol:Mainnet --rpc-url https://mainnet.base.org --broadcast --verify
```

## Part of the THRYX onchain surface

This is one of 14 utility contracts deployed by the THRYX project on Base. Full inventory: https://thryx.fun

Companion contracts:
- Keeper-bounty patterns: https://github.com/lordbasilaiassistant-sudo/keeper-bounty-lab
- Onchain primitives lab: https://github.com/lordbasilaiassistant-sudo/onchain-primitives-lab

## License

MIT.

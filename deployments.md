# DeadManSwitch Deployments

## Base Sepolia (chainId 84532)

- **Address:** `0x495fbeb17eCB16694f83Ed2A48EBCf59CD9D20AE`
- **Treasury:** `0x7a3E312Ec6e20a9F62fE2405938EB9060312E334`
- **Deployed:** 2026-05-03
- **Tx cost:** ~0.000028 ETH
- **Constructor params:**
  - registerFeeBps: 50 (0.5%)
  - triggerBountyBps: 50 (0.5%)
  - maxRegisterFeeBps: 500 (5% hard cap)
  - maxTriggerBountyBps: 500 (5% hard cap)
  - minInterval: 60 seconds
  - maxInterval: 3650 days (~10 years)
- **Explorer:** https://sepolia.basescan.org/address/0x495fbeb17eCB16694f83Ed2A48EBCf59CD9D20AE

### Live integration test (2026-05-03) — PASSED

Switch ID 0:
- Deposit: 0.00002 ETH (20,000,000,000,000 wei)
- Fee → treasury at register: 100,000,000,000 wei (0.5%) — verified by contract holding only `locked` after register
- Locked: 19,900,000,000,000 wei
- Interval: 60 seconds
- Beneficiary: `0x860700Faf38C7720b6876ec0D83fec7EAF8fbf8c` (started at 0 wei)

After deadline + trigger:
- Beneficiary received: **19,800,500,000,000 wei** = `locked - bounty` exactly
- Triggerer received: 99,500,000,000 wei bounty (0.5% of locked)
- Contract balance: 0 wei
- `claimed` flag: true
- `isAlive(0)`: false

Math checks out to the wei. Contract working as designed.

## Base Mainnet (chainId 8453) — LIVE

- **Address:** `0x40f1AAb4c82D48260Ab1207e27329d51290025DB`
- **Treasury:** `0x7a3E312Ec6e20a9F62fE2405938EB9060312E334`
- **Deployed:** 2026-05-03
- **Tx cost:** ~0.000027 ETH
- **Constructor params:**
  - registerFeeBps: 50 (0.5%)
  - triggerBountyBps: 50 (0.5%)
  - maxRegisterFeeBps: 500 (5% hard cap)
  - maxTriggerBountyBps: 500 (5% hard cap)
  - **minInterval: 1 hour** (production floor)
  - maxInterval: 3650 days (~10 years)
- **Verified:** Yes (Basescan, Etherscan V2 API)
- **Explorer:** https://basescan.org/address/0x40f1aab4c82d48260ab1207e27329d51290025db

## See also — sibling deployments (all Base mainnet, all verified)

DeadManSwitch is one of 14 utility contracts + 4 tokens deployed by the same treasury
(`0x7a3E312Ec6e20a9F62fE2405938EB9060312E334`). Portfolio hub: https://thryx.fun

### Keeper Bounty Lab (`KeeperBountyLab/LAB_REPORT.md`)

| Contract | Address |
|---|---|
| ManualFloorOracle | [`0xBD073CC2c610EeB0aA49FeAD7eee2ED980cbd70E`](https://basescan.org/address/0xBD073CC2c610EeB0aA49FeAD7eee2ED980cbd70E) |
| VestingAutoClaim | [`0x07EC89a177c7bcBB5205A8fF274f751f1C37fe4E`](https://basescan.org/address/0x07EC89a177c7bcBB5205A8fF274f751f1C37fe4E) |
| EnsAutoRenewer | [`0x4B0486C004b34Bfe6D632d5dD329c988eDDB1aE7`](https://basescan.org/address/0x4B0486C004b34Bfe6D632d5dD329c988eDDB1aE7) |
| DaoProposalExecutor | [`0xbC91411Ec61B9352A6CdF3a6722E89e5FB279F2E`](https://basescan.org/address/0xbC91411Ec61B9352A6CdF3a6722E89e5FB279F2E) |
| NftCancelOnFloorDrop | [`0xFF15F745736cfA35cf00691397584709C3Fd34b1`](https://basescan.org/address/0xFF15F745736cfA35cf00691397584709C3Fd34b1) |
| CurveGraduationPusher | [`0x7C10082fa45c530785a123B8506623e9d3C4Ad30`](https://basescan.org/address/0x7C10082fa45c530785a123B8506623e9d3C4Ad30) |

### Onchain Primitives (`OnchainPrimitives/LAB_REPORT.md`)

| Contract | Address |
|---|---|
| StealthAddressRegistry (EIP-5564) | [`0xD227B45aF37591E6227EB30B757232c1D541c016`](https://basescan.org/address/0xD227B45aF37591E6227EB30B757232c1D541c016) |
| SlashablePromiseVault | [`0xe2b5AfF3e1e05f999BbF48EDD27C4c872b953268`](https://basescan.org/address/0xe2b5AfF3e1e05f999BbF48EDD27C4c872b953268) |
| ConditionalTokenDrop | [`0x8Fb1224e814fcfE4dcd952a6d3DFF722d86862Ae`](https://basescan.org/address/0x8Fb1224e814fcfE4dcd952a6d3DFF722d86862Ae) |
| TimeCapsule | [`0x52E5829b8C71A8F4878B5569Df4255dfeB909a0C`](https://basescan.org/address/0x52E5829b8C71A8F4878B5569Df4255dfeB909a0C) |
| AddressTaggingMarket | [`0x0288DfE67bE8876D92c0EA41c190b506cd99eD63`](https://basescan.org/address/0x0288DfE67bE8876D92c0EA41c190b506cd99eD63) |
| GroupBountyPool | [`0xaB4C7B22B952f99cC8Bf280D17230E8CaDd6CbD4`](https://basescan.org/address/0xaB4C7B22B952f99cC8Bf280D17230E8CaDd6CbD4) |
| AtomicSwapHTLC | [`0xc3D0CBC815DE1938D4714bf2603b33400f588433`](https://basescan.org/address/0xc3D0CBC815DE1938D4714bf2603b33400f588433) |

### Tokens (`TokenLaunches/launched-tokens.json`) — Clanker v4, 80% LP fees → treasury

| Token | Address |
|---|---|
| Aletheia (ALETH) | [`0x1896354e4729C689B27CbDFdE5F8192eD0115B07`](https://basescan.org/token/0x1896354e4729C689B27CbDFdE5F8192eD0115B07) |
| Mnemosyne (MNEM) | [`0x6358208342Be88A6D8bDC7c00D09fB43C49DdB07`](https://basescan.org/token/0x6358208342Be88A6D8bDC7c00D09fB43C49DdB07) |
| Huginn (HUGIN) | [`0x75BB9e3eB32747D7A9eEEf8467f5f4C44C977B07`](https://basescan.org/token/0x75BB9e3eB32747D7A9eEEf8467f5f4C44C977B07) |
| Custos (CUSTOS) | [`0x3EFf9f255B5a1891a8003A2Bf46dE45247a8aB07`](https://basescan.org/token/0x3EFf9f255B5a1891a8003A2Bf46dE45247a8aB07) |

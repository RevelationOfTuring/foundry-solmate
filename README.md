# Foundry-Solmate

Line-by-line source analysis of [solmate](https://github.com/transmissions11/solmate) with annotated contracts, mock helpers, and comprehensive Foundry test coverage.

## Overview

This project provides a systematic deep-dive into solmate's core modules (pinned at commit [89365b8](https://github.com/transmissions11/solmate/commit/89365b8)), combining source-level annotations with rigorous test validation.

Annotated fork with inline Chinese comments: [RevelationOfTuring/solmate (code-reading branch)](https://github.com/RevelationOfTuring/solmate/tree/code-reading)

**Goals**:
- **Annotated source code** — line-by-line Chinese comments covering design rationale, gas optimizations, and security considerations
- **Full Foundry test coverage** — happy paths, revert paths, boundary conditions, and end-to-end integration tests for every public function

## Project Structure

```
foundry-solmate/
├── lib/
│   ├── forge-std/           # Foundry standard library v1.15.0
│   └── solmate/             # Solmate source (with inline annotations)
├── src/                     # Mock contracts (expose internals for testing)
│   └── auth/
│       ├── MockAuth.sol
│       └── MockOwned.sol
├── test/                    # Foundry tests
│   ├── auth/
│   │   ├── Auth.t.sol
│   │   ├── Owned.t.sol
│   │   └── authorities/
│   │       ├── RolesAuthority.t.sol
│   │       └── MultiRolesAuthority.t.sol
│   └── ...
└── ...
```

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Target a specific contract
forge test --match-contract MultiRolesAuthorityTest -v

# Target a specific test function
forge test --match-test testCanCallWithCustomAuthority -vvv
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| [solmate](https://github.com/transmissions11/solmate) | main @ [89365b8](https://github.com/transmissions11/solmate/commit/89365b8) | Target library under analysis |
| [forge-std](https://github.com/foundry-rs/forge-std) | v1.15.0 | Foundry test framework |

## License

Test code in this repository is released under the MIT License. The original solmate source code is licensed under AGPL-3.0.

## Donate

If you find this project helpful, consider buying me a coffee ☕

```
EVM: 0x93E75664A29040fC14281FdFa8821e7900000000
```

Accepts any EVM-compatible chain — Ethereum, Arbitrum, Optimism, Base, BSC, Polygon, etc.

## Contact

For questions, discussions, or consulting on smart contract development, feel free to reach out:

📧 **wgy.michael@gmail.com**

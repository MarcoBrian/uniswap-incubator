# Uniswap Hook Incubator

Curated playground for experimenting with Uniswap v4 Hooks, swap routers, and supporting infrastructure. Each sub-project lives in its own Foundry workspace so ideas stay isolated but share common tooling.

## Repository Layout

| Path | What lives here |
| --- | --- |
| `points-hook/` | ERC1155-based loyalty hooks that mint on swap events |
| `swap-and-bridge-op/` | Router that swaps via v4 `IPoolManager` and bridges to Optimism |
| `internal-swap-pool/` | Fee-aware hook that front-runs swaps with treasury inventory |
| `Notes/` | Scratch space for whiteboard ideas, links, and research artifacts |

## Project Overviews

### `points-hook`
- Implements `PointsHook` and `PointsHookTiered`, two `BaseHook` contracts that mint ERC1155 rewards after swaps.
- Rewards are scoped per `PoolId`; hook data encodes the receiver address so LPs or integrators can attribute points.
- Includes helper `USDC` mock, Foundry scripts, and fork tests for simulating mainnet pools.

### `swap-and-bridge-op`
- `SwapAndBridgeOptimismRouter` lets a user swap against Uniswap v4 pools and optionally bridge the output to Optimism using the L1 Standard Bridge.
- Guards against unsupported bridge assets with `l1ToL2TokenAddresses`, settles residual ETH, and handles both ERC20 and native flows.
- Useful reference for composing hooks with post-swap settlement logic.

### `internal-swap-pool`
- ReturnDelta hooks examples
- `InternalSwapPool` derives from `BaseHook` to manage protocol-owned inventory and dynamic fees.
- Converts accumulated token1 fees into token0 before user swaps, acting as a lightweight internal order book.
- Tracks per-pool claimable fees, enforces minimum donation thresholds, and redistributes proceeds via the `donate` pathway.
- Another project is `CSMM.sol` , which is Constant Sum Market Maker. Custom curve created for stablecoin 1:1 peg. Used the ReturnDelta hooks to customize this curve. 

## Getting Started

1. Install Foundry (if not already):
   ```sh
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
2. Install Uniswap v4 periphery tooling once (from repo root or any workspace):
   ```sh
   forge install Uniswap/v4-periphery
   ```
3. Enter the project you want to work on, e.g.:
   ```sh
   cd points-hook
   ```
4. Common commands (run from any sub-project directory):
   ```sh
   forge install    # pull dependencies
   forge build      # compile contracts
   forge test       # run local tests
   forge fmt        # format Solidity files
   ```

## Development Notes

- Each workspace includes its own `foundry.toml`, cache, and `lib/` tree so experiments don’t fight over remappings.
- Hook-heavy projects pin Uniswap v4 `periphery` and `core` via git submodules; run `git submodule update --init --recursive` after cloning.
- When adding a new prototype, follow the existing folder pattern so CI and tooling remain consistent.
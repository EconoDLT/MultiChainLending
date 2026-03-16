# Multi-Chain Lending
This repository contains code and data for the submitted paper.

CODE: 
Code is written in R and is found in the file lending_analysis.R. Fundamental functions are plm() for the panel data (fixed effects) regression and lm() for the OLS regressions.

DATA OVERVIEW:
53 Bridge Protocols,
15 Decentralized Protocols,
9 Blockchains (Three Groups: Ethereum L1, L2, AltL1).
Protocol availability across blockchains is shown in protocol_availability.png.

RAW DATA: Separate raw data files are uploaded, and the sources are written in the folder names.

PROCESSED DATA: 
The analyzed dataset is composed of four files: 
- ethereum_lending.csv
- L2_lending.csv
- altL1_lending.csv
- aggregated_lending.csv


Data has a daily frequency and covers the period: 17 October 2022 to 01 January 2025. The start date is the first day when the bridge volume data was available on DeFiLlama for the first time.

Core Financial Metrics:
TVL, Revenue, Bridge Volume, Liquidation.

Credit Risk Parameter:
Credit Expansion Ratio (CER) = dailyBorrowUSD / dailyDepositUSD

Yield Data: ETH APY, Stablecoin APY.

Dummy Variables For Events: Bridge Integrations, Bridge Hack, Mainnet.

Market Sentiment: Fear and Greed Index (FGI).

Other Control Variables: ETH Volatility, Gas Price.






# Cross-Chain Speculative Liquidation MEV

**Oracle Latency, DON Behavior, and Exploitation Windows in Aave v3 Across Ethereum and Layer-2 Networks**

This repository contains the data collection, analysis, and simulation scripts accompanying the paper *"Cross-Chain Speculative Liquidation MEV"*. The codebase is organized into five sequential phases: liquidation statistics, oracle observation queries, DON peer analysis, CEX price data, and cross-chain latency/exploitation analysis.

---

## Repository Structure

```
cross-chain-liquidation-mev/
│
├── README.md
│
├── 1_liquidation_statistics/
│   └── identify_price_feeds_from_liquidations.py
│
├── 2_oracle_observations/
│   ├── updateAt_count_script.py
│   └── updateAt_count_script2.py
│
├── 3_don_peers/
│   └── peers_observations_statistics.py
│
├── 4_cex_data/
│   ├── binance_historical_price_data.py
│   └── ohlcv14.py
│
├── 5_observation_matching/
│   ├── observations_binance_match_method_1_multiple_bins_usage.py
│   └── observations_binance_match_method_2_3_4_single_bin_usage.py
│   └── comparison_observations_latency_by_chain.py
│
├── 6_cex_comparison/
│   └── cex_comparison.py
│
├── 7_exploitable_windows/
│   └── health_factor_comparison_by_chains.py
│
└── data/
│   ├── binance/              # Raw and processed Binance price data
│   ├── chainlink/            # Oracle configuration JSON files and raw event logs
│   └── raw_logs/             # NewTransmission events, raw observations logs 
│
└── results
    ├── liquidation_statistics/           # Output tables with statistics
    └── observation_match/        
    │   └── multiple_bin_usage/           # Observations thrown into all matched CEX price bins
    │   └── weighted_bin_usage/           # Observations thrown into the best CEX price bin
    │   └── comparison_observations       # Observation latencies by chains compared
    └── exploitable_cross_chain_windows/  # Output statistics and plots
```

---

## 1 — Liquidation Statistics & Aave–Chainlink Relationship

### `1_liquidation_statistics/identify_price_feeds_from_liquidations.py`

**Purpose:** Proves and documents how Aave v3 liquidations consume Chainlink oracle contracts. Produces a ranked, deduplicated list of price feeds involved in liquidations per chain.

**What it does:**
- Queries all `LiquidationCall` events from the Aave v3 `Pool` contract on Ethereum, Arbitrum, Optimism, and Base.
- For each liquidated asset, calls the `AaveOracle` contract to resolve the `priceSource` address.
- Handles three feed types:
  - **Derivative feeds** (e.g., stETH/USD): resolves via `ASSET_TO_PEG` → core ETH/USD proxy.
  - **Stablecoin feeds** (e.g., USDC/USD): resolves via `ASSET_TO_USD_AGGREGATOR`.
  - **SVR feeds**: detects `secondaryProxyAddress` and flags SVR-enabled pairs.
- Cross-validates resolved proxy addresses against Chainlink JSON configuration files in `data/chainlink/`, verifying heartbeat and deviation threshold parameters manually.
- Counts total liquidations per price feed pair and chain.
- Outputs a ranked CSV and summary table.

**Outputs:** `data/results/liquidation_statistics/liquidations_by_feed_chain.csv`

---

## 2 — Oracle Observation Queries

### `2_oracle_observations/updateAt_count_script.py`

**Purpose:** Queries `NewTransmission` raw logs from Chainlink aggregator contracts on Ethereum and Arbitrum, extracting observations arrays and counting price updates.

**What it does:**
- Accepts a list of Chainlink aggregator addresses (ETH/USD, BTC/USD, LINK/USD) per chain.
- Queries raw `NewTransmission` event logs within a specified block range.
- Decodes the `observations` array (per-peer submitted prices) from each event.
- Records: block number, block timestamp, transmitter address, aggregator address, observations array.
- Counts total `updatedAt` (price update) events per feed and chain.
- Organizes output by feed pair and chain.

**Outputs:** `data/chainlink/new_transmissions_{chain}_{feed}.json`

---

### `2_oracle_observations/updateAt_count_script2.py`

**Purpose:** Extension of `updateAt_count_script.py` with support for Optimism. Handles Optimism-specific RPC endpoints and block time differences.

**Additional handling:**
- Optimism RPC configuration and batch size adjustments for rate limiting.
- Merges output format with the base script for downstream compatibility.

---

## 3 — DON Peer Statistics

### `3_don_peers/peers_observations_statistics.py`

**Purpose:** Investigates the statistical behavior of individual DON peers across `NewTransmission` events.

**What it does:**
- Loads raw `NewTransmission` data from Phase 2 outputs.
- For each event, decomposes the `observations` array into individual peer submissions.
- Computes per-feed, per-chain statistics:
  - Total number of `updatedAt` events.
  - Number of active DON peers (unique transmitters).
  - Distribution of submitted observation values: Min, Mean, Median, Max.
  - **Identical observation fraction**: percentage of events where all peers submitted the exact same price, i.e., `len(set(observations)) == 1`.
- Cross-references peer transmitter addresses with known Chainlink node operator identities from `data/chainlink/operators.json` for partial deanonymization.

**Outputs:** `data/results/don_peer_statistics_{chain}_{feed}.csv`

---

## 4 — CEX Price Data Collection

### `4_cex_data/binance_historical_price_data.py`

**Purpose:** Downloads historical second-interval price data from Binance for ETH and BTC.

**What it does:**
- Uses the Binance REST API (`/api/v3/klines`) with `1s` interval.
- Downloads data for a configurable date range (default: all of 2025 + October 10, 2025).
- Stores OHLCV data (open, high, low, close, volume) per second.
- Handles pagination and API rate limiting automatically.

**Outputs:** `data/binance/binance_{asset}_1s_{date}.csv`

---

### `4_cex_data/ohlcv14.py`

**Purpose:** Queries OHLCV data from five centralized exchanges for cross-CEX comparison.

**Exchanges supported:** Binance, Kraken, Coinbase, Bybit, OKX

**What it does:**
- Uses the `ccxt` library to query 1-second OHLCV data from all five CEXs.
- Aligns timestamps across exchanges to a common UTC second-level index.
- Stores per-exchange output in a standardized format.
- Reports data availability gaps (not all exchanges offer 1s resolution for all assets).

**Outputs:** `data/binance/{exchange}_{asset}_ohlcv.csv`

---

## 5 — Observation–CEX Price Matching

### `5_observation_matching/observations_binance_match_method_1_multiple_bins_usage.py`

**Purpose:** Method 1 — matches each DON peer observation to CEX price bins (multiple bins per observation).

**What it does:**
- Treats each second of CEX price data as a "bin" defined by `[low, high]` for that second.
- For each observation value in a `NewTransmission` event, finds all bins whose `[low, high]` range contains the observation.
- Assigns the observation to all matching bins (multiple matches allowed).
- Computes a matched latency as the difference between the matched CEX second timestamp and the `NewTransmission` block timestamp.

**Known issue:** Multiple bin matches per observation inflate the total matched count. Use Methods 2–4 for quantitative latency analysis.

**Currently covers:** ETH/USD (Ethereum). Modify `FEED` and `CHAIN` parameters for BTC/USD or other chains.

**Outputs:** `data/results/method1_matches_{chain}_{feed}.csv`

---

### `5_observation_matching/observations_binance_match_method_2_3_4_single_bin_usage.py`

**Purpose:** Methods 2, 3, and 4 — single-bin assignment resolving the inflation problem from Method 1.

**Method 2 — Closest Bin:**
- Assigns each observation to the bin minimizing `|obs - bin_mid|` where `bin_mid = (low + high) / 2`.

**Method 3 — Random Bin:**
- Among all bins containing the observation value, selects one uniformly at random.
- Used for sensitivity analysis.

**Method 4 — Mid-Price Proximity (primary):**
- Computes `mid = (low + high) / 2` for each matched bin.
- Assigns the observation to the bin whose mid-price is closest to the observation value.
- This is the primary method used in the paper's latency analysis.

**For all methods:**
- Computes the matched latency: `latency = new_transmission_block_timestamp - matched_cex_second_timestamp`.
- Reports latency distribution statistics: mean, median, std, min, max, CV.
- Supports ETH/USD and BTC/USD; configurable via `FEED` parameter.

**Outputs:** `data/results/method{2,3,4}_latency_{chain}_{feed}.csv`

---

## 6 — CEX Comparison & Influence Analysis

### `6_cex_comparison/cex_comparison.py`

**Purpose:** Identifies which CEX most strongly drives DON observation prices using MAE and GMM.

**What it does:**
- Loads per-transmission observation arrays (Phase 2) and five-CEX OHLCV data (Phase 4).
- For each transmission event $i$ and CEX $j$, computes the residual:
  `r[i,j] = observation[i] - CEX_price[j, t_i]`
- Computes per-CEX Mean Absolute Error (MAE) against the on-chain aggregated price.
- Fits a Gaussian Mixture Model (GMM) to the residuals per CEX to assess distributional concentration.
- Ranks CEXs by MAE (lower = more influential) and GMM component dominance (fewer components = tighter alignment).
- Reports results per chain and feed, identifying a "primary CEX" per feed.

**Statistical outputs:**
- MAE table per CEX × chain × feed.
- GMM component count and dominant component weight per CEX.
- Summary ranking: most to least influential CEX per feed.

**Outputs:** `data/results/cex_influence_{chain}_{feed}.csv`, `data/results/gmm_summary.json`

---

## Phase 7 — Detecting & Calculating Exploitable Health Factors Between Chains

### `7_health_factor_comparison_by_chains/health_factor_comparison_by_chains.py`

**Purpose:** Determines whether a liquidation on a target chain (Ethereum, Arbitrum, or Base) can be predicted and speculated by observing oracle price feed updates on the Optimism benchmark chain. Computes health factors of borrowing positions using the price feeds of each chain independently, and identifies the exploitable window during which a position is liquidatable according to the Optimism price feed but not yet liquidatable according to the target chain's own price feed.

**What it does:**

- **Position loading.** Loads all open borrowing positions on Aave v3 for each target chain from on-chain data: collateral asset, collateral amount, debt asset, debt amount, and the Chainlink `priceSource` addresses per asset.

- **Health factor calculation per chain.** For each position, computes the health factor $H$ using the most recent on-chain oracle price on each chain independently:

```
H_c = sum(collateral_i * P_i_c * LT_i) / sum(debt_j * P_j_c)
```

  where `P_i_c` is the latest price from chain `c`'s Chainlink aggregator for asset `i`, and `LT_i` is the protocol liquidation threshold for that asset.

- **Cross-chain health factor comparison.** For each position, computes `H` under the Optimism price feed (`H_OP`) and under the target chain's price feed (`H_target`). A position is flagged as **exploitable** when:

```
H_OP < 1  AND  H_target >= 1
```

  This condition means the position is already liquidatable according to Optimism prices but not yet on the target chain — the speculative window is open.

- **Window duration estimation.** For each exploitable position event, cross-references the timestamp of the Optimism `NewTransmission` event that pushed `H_OP` below 1 against the subsequent `NewTransmission` event on the target chain. The difference defines the empirical exploitation window `W_OP→target` for that event, contributing to the distribution analyzed in the paper.

- **Exploitable window statistics.** Aggregates all exploitable events per chain pair and feed:
  - Count and frequency of exploitable windows over the study period.
  - Window duration distribution: min, mean, median, max, std, CV.
  - Fraction of total liquidations preceded by an exploitable cross-chain window.
  - Health factor delta `ΔH = H_target - H_OP` at window open, indicating proximity of the target chain to also triggering liquidation.

- **Speculator detection.** Checks whether any liquidation transactions on the target chain were submitted within `epsilon` seconds of the Optimism `NewTransmission` event that opened the window — i.e., before the target chain's own price feed updated. Flags such transactions as likely cross-chain speculative liquidations and records the submitting address for further profiling.

**Inputs:**
- Aave v3 position data (collateral, debt, LT) per target chain.
- `NewTransmission` event logs for Optimism and each target chain (Phase 2 outputs).
- Oracle configuration (DT, HB) per chain and feed (Phase 1 outputs).
- On-chain liquidation transaction timestamps (Phase 1 outputs).

**Key parameters:**
```python
BENCHMARK_CHAIN  = "optimism"
TARGET_CHAINS    = ["ethereum", "arbitrum", "base"]
FEEDS            = ["ETH/USD", "BTC/USD"]
EPSILON_SECONDS  = 5    # tolerance for speculator detection
MIN_WINDOW_SECS  = 1    # minimum window duration to report
```

**Outputs:**
- `data/results/health_factor_windows_{target_chain}_{feed}.csv` — per-event exploitable window records with timestamps, `H_OP`, `H_target`, `DH`, and window duration.
- `data/results/health_factor_window_summary.csv` — aggregated window statistics per chain pair and feed.
- `data/results/suspected_speculators.csv` — addresses and transaction hashes of suspected cross-chain speculative liquidators.

---

## Data Directory

### `data/binance/`
Raw and processed CEX price data. Files named `{exchange}_{asset}_1s_{date}.csv`.

### `data/chainlink/`
- **Oracle configuration JSON files** per chain: deviation threshold, heartbeat, proxy address, SVR flag.
- **Raw `NewTransmission` event logs** per chain and feed (output of Phase 2).
- **`operators.json`**: known Chainlink node operator addresses and identities for deanonymization.

### `data/results/liquidation_statistics/`
Aggregated output tables:
- `liquidations_by_feed_chain.csv` — ranked liquidations per feed and chain.
- `oracle_config_summary.csv` — DT, HB, SVR, update counts per chain/feed.
- `don_peer_statistics.csv` — peer counts, observation distributions, identity fractions.
- `latency_summary.csv` — CEX-to-chain latency statistics per method, chain, and feed.
- `exploitation_window.csv` — $W_{c_1 \to c_2}^f$, CV, KS test p-values per chain pair and feed.

---

## Configuration

Each script accepts configuration via a `config.py` file or inline constants at the top of the file:

```python
# RPC endpoints
RPC_ETHEREUM  = "https://..."
RPC_ARBITRUM  = "https://..."
RPC_OPTIMISM  = "https://..."
RPC_BASE      = "https://..."

# Study period
DATE_START = "2025-01-01"
DATE_END   = "2025-12-31"
DATE_INTRADAY = "2025-10-10"

# Assets
FEEDS = ["ETH/USD", "BTC/USD", "LINK/USD"]
```

---

## Dependencies

```
pip install web3 pandas numpy scipy scikit-learn ccxt requests tqdm
```

Python 3.10+ recommended.

---

## Citation

If you use this code or data, please cite:

```bibtex
@inproceedings{anon2025crosschain,
  title     = {Cross-Chain Speculative Liquidation {MEV}: Oracle Latency, {DON} Behavior, and Exploitation Windows in {Aave} v3},
  author    = {Anonymous},
  booktitle = {Submitted for Review},
  year      = {2025}
}
```


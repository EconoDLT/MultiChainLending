# Multi-Chain Lending
**DeFi, Lending Protocols, Risk-Management Models, and Cross-Chain Asset Transfers across 9 EVM Blockchains with 3 Different Network Architectures**

This repository contains the collected data, the R code used, further explanations and clarifications for the research paper that extends automated risk management models of on-chain lending protocols, with cross-chain components and variables.

---

## Repository Structure

```
MultiChainLending/
│
├── README.md
│
├── analysis_code/
│   └── lending_analysis.R
│
├── protocol_data_availability/
│   └── protocol_availability.png   # The list of protocols involved in the data
│
└── data/
    └── processed_data/             # These files are required to run the script
    │   └── ethereum_lending.csv
    │   └── L2_lending.csv
    │   └── altL1_lending.csv
    │   └── aggregated_lending.csv
    └── raw_data/                   # This folder includes a lot of raw data files
                                    # Free to use as long as the data source is stated
```

---

## 1 — Code

### `lending_analysis.R`

The script is written in R. Fundamental functions are:
- `plm()` for the panel data (fixed effects) regression, and
- `lm()` for the OLS regressions.

---

## 2 — Data

### Data Overview

The dataset covers:
- 53 bridge protocols,
- 15 on-chain lending protocols,
- 9 blockchains (three groups: Ethereum (L1), L2, AltL1).
Protocol availability across blockchains is shown in `protocol_availability.png`.
Data has a daily frequency and covers the period: 17 October 2022 to 01 January 2025. The start date is when the bridge volume data was available on DeFiLlama for the first time.

### Raw Data

Separate raw data files are uploaded to the `data/raw_data` folder. The source of each data file is written in the folder names.
E.g.: `MultiChainLending/Data/RawData/Bridge_Volume_From_DeFiLlama/bridge_volumes_arbitrum_one.csv`

### Processed Data

The analyzed dataset is composed of four files:
- `ethereum_lending.csv`
- `L2_lending.csv`
- `altL1_lending.csv`
- `aggregated_lending.csv`

The following variables are included in the data files:
- Core Financial Metrics: `TVL`, `Revenue`, `BridgeVolume`, `Liquidation`, `Withdraw`, `Deposit`, `ActiveUsers`.
- Credit Risk Parameter: `CER` (Credit Expansion Ratio)
$$
CER = \frac{dailyBorrowUSD}{dailyDepositUSD}
$$
- Yield Data: `ETH_APY`, `Stablecoin_APY`.
- Dummy Variables For Events: `BridgeIntegrations`, `BridgeHack`, `Mainnet`.
- Market Sentiment: `FGI` (Fear and Greed Index).
- Network Control Variables: `volETH` (ETH Volatility), `GasPrice`.

---

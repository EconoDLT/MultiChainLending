# Interoperability Effects: Extending DeFi Lending Risk Models to Multi-Chain Environments

This repository contains the collected data, the R code used, further explanations and clarifications for the following research paper that extends automated risk management models of on-chain lending protocols, with cross-chain components and variables:

[CITATION + arXiv Link]

***Abstract: On-chain lending has expanded across multiple distributed ledgers as DeFi becomes increasingly multi-chain. This environment introduces novel technical and financial mechanisms, particularly cross-blockchain communication and asset transfer protocols, yet cross-chain elements remain understudied in lending protocol risk management. To address this gap, we apply panel regression fixed effects and OLS models to empirically analyze cross-blockchain interoperability solutions, using TVL and total revenue as performance proxies over October 2022–January 2025. Our dataset covers 15 decentralized lending protocols and 53 cross-chain bridges across 9 EVM-compatible blockchains, categorized as Ethereum, alternative layer-1s, and Ethereum layer-2 networks. Results reveal that cross-chain activity impacts are highly domain-specific. Bridge volume significantly affects TVL and revenue within individual blockchain categories but disappears in pooled regressions, indicating that fixed effects absorb critical heterogeneity. Increased bridge integrations are associated with decreased TVL and protocol revenue across categories, suggesting liquidity escapes from those lending ecosystems. Bridge volume and liquidations produce heterogeneous effects across categories. Bridge hacks and new network launches do not have a significant relationships with the TVL and revenue, as control variables. High R² values confirm meaningful explanatory power, though conflicting cross-model results caution against uniform risk frameworks. We further show Ethereum attracts large depositors, while layer-2s skew toward retail participation. We conclude that effective DeFi risk models should incorporate cross-chain metrics and adopt a layer-aware approach to accurately reflect the evolving multi-chain landscape.***

**Keywords:** Decentralized Finance, Blockchain, Lending, Risk Management

**Related Skills/Knowledge:** Distributed Systems, Econometrics, Financial Modelling, Collateralization, Debt Market.

---

## Repository Structure

```
MultiChainLending/
│
├── README.md
│
├── lending_analysis.R              # Code to analyze the data
│
├── protocol_availability.png       # The list of protocols involved in the data
│
└── data/
    └── processed_data/             # These files are required to run the script
    │   └── ethereum_lending.csv
    │   └── L2_lending.csv
    │   └── altL1_lending.csv
    │   └── aggregated_lending.csv
    └── raw_data/                   # This folder includes multiple raw data files
                                    # Free to use as long as the data source is stated
```

---

## 1 — Code

### `lending_analysis.R`

The script is written in R. Fundamental functions are:
- `plm()` for the panel data (fixed effects) regression, and
- `lm()` for the OLS regressions.

**Inputs:** `ethereum_lending.csv`, `L2_lending.csv`, `altL1_lending.csv`, `aggregated_lending.csv`.

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
- Yield Data: `ETH_APY`, `Stablecoin_APY`.
- Dummy Variables For Events: `BridgeIntegrations`, `BridgeHack`, `Mainnet`.
- Market Sentiment: `FGI` (Fear and Greed Index).
- Network Control Variables: `volETH` (ETH Volatility), `GasPrice`.
- Credit Risk Parameter: `CER` (Credit Expansion Ratio).

``
CER = dailyBorrowUSD / dailyDepositUSD
``

---

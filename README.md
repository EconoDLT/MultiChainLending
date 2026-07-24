# Multi-Chain Lending Paper

This repository contains the collected data, the R code used, further explanations and clarifications for the submitted research paper that extends automated risk management models of on-chain lending protocols, with cross-chain components and variables.

H. O. Sevim, “Connecting Distributed Ledgers: Surveying Novel Interoperability Solutions in On-chain Finance,” arXiv:2603.21797, 2026. https://arxiv.org/abs/2603.21797

***Abstract: On-chain lending has expanded across multiple distributed ledgers as DeFi becomes increasingly multi-chain. This environment introduces novel technical and financial mechanisms, particularly cross-blockchain communication and asset transfer protocols, yet cross-chain elements remain understudied in lending protocol risk management. To address this gap, we applied panel regression fixed effects and OLS models to empirically analyze cross-blockchain interoperability solutions, using TVL and total revenue as performance proxies from October 2022 to January 2025. Our data set covers 15 decentralized lending protocols and 53 cross-chain bridges across 9 EVM-compatible blockchains, categorized as Ethereum, alternative layer-1s, and Ethereum layer-2 networks. Results reveal that cross-chain activity impacts on protocol performance. Bridge volume emerges as a critical driver, exerts a significant effect on TVL and revenue across different categories, though the direction of this effect varies heterogeneously. Increased bridge integrations are associated with decreased TVL and protocol revenue across categories, indicating liquidity escapes from those lending ecosystems. Liquidations produce heterogeneous effects across categories. The panel data reveal that new network launches are weakly associated with TVL and revenue, while bridge hacks show no significant relationship. High R-squared values confirm meaningful explanatory power. We further show Ethereum attracts large depositors, while layer-2s skew toward retail participation. We conclude that effective DeFi risk models should incorporate cross-chain metrics and adopt a layer-aware approach to accurately reflect the evolving multi-chain landscape.***

**Keywords:** Decentralized Finance, Blockchain, Lending, Risk Management.

**Related Skills/Knowledge:** Cross-Chain Interoperability, Distributed Systems, Qualitative Comparison, Econometrics, Statistical Modelling.


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
        └── ethereum_lending.csv
        └── L2_lending.csv
        └── altL1_lending.csv
        └── aggregated_lending.csv
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
CER = log ( dailyBorrowUSD / dailyDepositUSD )
``

### Raw Data Request

Data can be shared upon request as long as sharing is compliant with the terms and conditions of the data sources.

---

## 3 — Robustness Checks for Endogeneity and Identification

To address potential reverse causality, simultaneity, and omitted-variable bias, we performed four additional robustness checks. The complete implementation is available in `lending_analysis.R`.

### 3.1 Two-Way Fixed Effects

**Method:** Added day fixed effects (`effect = "twoways"`) to the individual fixed-effects model.

**Result:**
- TVL coefficient changes from **+0.138 → -0.266**
- Revenue coefficient changes from **-0.061 → -0.311**

**Takeaway:** Daily fixed effects noticeably change the coefficient estimates. However, with only **3 cross-sectional units** and roughly **800 day fixed effects**, the model has very limited residual degrees of freedom (negative adjusted R²). We therefore treat this as a sensitivity check rather than a replacement for the main specification.

### 3.2 Lagged Variable Models

**Method:** Estimated:
- 1-, 2-, and 3-day lag models
- Distributed-lag model (lags 0–2)
- Fully lagged specification (all continuous regressors lagged by one day)

**Result:**
- **TVL:** Bridge coefficient remains between **0.125** – **0.195**
- **Revenue:** Bridge coefficient remains between **-0.061** – **-0.014**

**Takeaway:** The bridge-volume coefficient remains stable across lag structures, weakening concerns that same-day simultaneity is driving the baseline results.

### 3.3 Instrumental Variables (2SLS)

**Method:** Used the **2-day lag of bridge volume** as an instrument for current bridge volume (`ivreg`).

**Diagnostics:**
- First-stage F-statistic **> 350** (strong instrument)
- Wu-Hausman test **p < 0.001** (evidence of endogeneity)

**Result:**
- **TVL:** IV = **0.358** (OLS = **0.107**)
- **Revenue:** IV = **-0.012** (OLS = **0.013**)

**Takeaway:** The IV results provide evidence that endogeneity is present. However, because the exclusion restriction cannot be directly verified, the estimates should be viewed as exploratory rather than definitive causal estimates.

### 3.4 Difference-in-Differences

**Method:** Interacted event dummies (`bridgeHack`, `bridgeIntegrations`, `mainnet`) with network categories (L2 and AltL1).

**Result:** Most interaction terms are statistically insignificant, with only a few marginally significant effects.

**Takeaway:** Event responses vary only modestly across network architectures, while the main event effects remain qualitatively consistent with the baseline model.

### Summary

Across all robustness checks, the main findings remain qualitatively consistent:

- Bridge activity remains associated with TVL and Revenue.
- The bridge-volume coefficient remains stable across lag specifications.
- Instrumental-variable estimation is consistent with endogeneity.
- None of the additional tests establish definitive causal identification.

Overall, these robustness checks do not overturn the main findings. They support interpreting the estimated relationships as **robust associations that are consistent with a possible causal channel**, while stopping short of establishing causality. Stronger identification strategies (e.g., exogenous shocks to bridge infrastructure) remain an important direction for future research.

---

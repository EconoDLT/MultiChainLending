# Multi-Chain Lending
This repository contains code and data for the submitted paper.

CODE: 
Code is written in R and is found in the file lending_analysis.R.

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


Data has a daily frequency and covers the period: 24 October 2022 to 01 January 2025.

Core Financial Metrics:
TVL, Revenue, Bridge Volume, Liquidation.

Credit Risk Parameter:
Credit Expansion Ratio (CER) = dailyBorrowUSD / dailyDepositUSD

Yield Data: ETH APY, Stablecoin APY.

Dummy Variables For Events: Bridge Integrations, Bridge Hack, Mainnet.

Market Sentiment: Fear and Greed Index (FGI)

Other Control Variables: ETH Volatility, Gas Price.








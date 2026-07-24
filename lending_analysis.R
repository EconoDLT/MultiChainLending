# =============================================================================
# LOAD REQUIRED PACKAGES
# =============================================================================
library(readr)
library(dplyr)
library(plm)
library(car)
library(corrplot)
library(stargazer)
library(lubridate)

options(scipen = 999)   # disable notations to see full values
options(width = 120)    # wider console for better formatting

# =============================================================================
# REDIRECT OUTPUT TO A TEXT FILE
# =============================================================================
sink("regression_results.txt", split = TRUE)  # split = TRUE also shows output in console

# =============================================================================
# USER: SET VARIABLE NAMES (REPLACE WITH YOUR ACTUAL COLUMN NAMES)
# =============================================================================

# Dependent variables (will be log-transformed)
A1 <- "dailyTotalRevenueUSD"
A2 <- "totalValueLockedUSD"

# Dummy (event) variables
D1 <- "bridgeHack"
D2 <- "bridgeIntegrations"
D3 <- "mainnet"

# Control variables
C1 <- "weightedAverageEthAPY"
C2 <- "weightedAverageStablecoinAPY"
C3 <- "weightedAverageGasPrice"
C4 <- "ETHreturn"           
C5 <- "FGI"                 
C6 <- "volETH"              # 7-day ETH volatility (for regressions only)

# Bridge / continuous variables (will be log-transformed)
B1 <- "bridgeVolume"
B2 <- "dailyLiquidateUSD"
B3 <- "dailyWithdrawUSD"
B4 <- "CER"

# Date column
date_col <- "Date"

# =============================================================================
# CREATE VECTORS OF VARIABLE GROUPS (basic groups only, not log-transformed yet)
# =============================================================================
all_deps <- c(A1, A2)
all_dummies <- c(D1, D2, D3)
all_controls_raw <- c(C1, C2, C3, C4, C5)        # For raw summary (includes ETHreturn, excludes volETH)
all_controls_reg <- c(C1, C2, C3, C5, C6)        # For regressions (includes volETH, excludes ETHreturn)
all_continuous <- c(B1, B2, B3, B4)

# For raw summary statistics
all_ivs_raw <- c(all_dummies, all_controls_raw, all_continuous)
all_ivs_raw_no_dummies <- c(all_controls_raw, all_continuous)

# =============================================================================
# CUSTOM SUMMARY FUNCTION: For dummies, show count of 1s; for continuous, show standard stats + SD
# =============================================================================
custom_summary <- function(data, vars, dummy_vars) {
  cat("\nVariable               Type         Summary\n")
  cat("------------------------------------------------------------\n")
  for (v in vars) {
    if (v %in% dummy_vars) {
      # Dummy variable: count 1s and 0s
      tbl <- table(data[[v]], useNA = "ifany")
      cat(sprintf("%-20s dummy       1s: %d, 0s: %d", v, tbl["1"], tbl["0"]))
      if (!is.null(tbl[NA])) cat(sprintf(", NA: %d", tbl[NA]))
      cat("\n")
    } else {
      # Continuous variable: standard summary with SD
      x <- data[[v]]
      summ <- summary(x)
      sd_val <- sd(x, na.rm = TRUE)
      cat(sprintf("%-20s continuous  Min: %.2f, 1Q: %.2f, Median: %.2f, Mean: %.2f, SD: %.2f, 3Q: %.2f, Max: %.2f, NAs: %d\n",
                  v, summ[1], summ[2], summ[3], summ[4], sd_val, summ[5], summ[6], sum(is.na(x))))
    }
  }
  cat("------------------------------------------------------------\n")
}

# =============================================================================
# FUNCTION TO CALCULATE AND PRINT VIF (with and without dummies)
# =============================================================================
calculate_vif <- function(data, dependent_var, iv_list, label) {
  cat(sprintf("\n--- VIF %s (using %s as dependent) ---\n", label, dependent_var))
  formula_vif <- as.formula(paste(dependent_var, "~", paste(iv_list, collapse = " + ")))
  vif_model <- lm(formula_vif, data = data)
  vif_results <- vif(vif_model)
  
  # Print as a data frame with nice formatting
  vif_df <- data.frame(
    Variable = names(vif_results),
    VIF = round(vif_results, 4),
    row.names = NULL
  )
  print(vif_df)
  cat("\n")
}

# =============================================================================
# 0. READ AND PREPARE AGGREGATED DATA
# =============================================================================
agg_raw <- read_csv("aggregated_lending.csv")
agg_raw$Date <- ymd(agg_raw$Date)

cat("\n--- Summary Statistics (raw) ---\n")
custom_summary(agg_raw, c(all_deps, all_ivs_raw), all_dummies)

cat("\n--- Correlation Matrix (raw) ---\n")
cor_raw <- cor(agg_raw[, all_ivs_raw], use = "complete.obs")
print(round(cor_raw, 6))

# VIF for raw aggregated data - with dummies
calculate_vif(agg_raw, A1, all_ivs_raw, "(with dummies)")

# VIF for raw aggregated data - without dummies
calculate_vif(agg_raw, A1, all_ivs_raw_no_dummies, "(without dummies)")

# =============================================================================
# 1. READ AND COMBINE PANEL DATA
# =============================================================================
panel_data <- bind_rows(
  read_csv("ethereum_lending.csv") %>% mutate(Network = "network1"),
  read_csv("L2_lending.csv") %>% mutate(Network = "network2"),
  read_csv("altL1_lending.csv") %>% mutate(Network = "network3")
)

panel_data$Date <- ymd(panel_data$Date)
panel_data$Network <- factor(panel_data$Network)

# =============================================================================
# 2. PANEL DATA FIXED EFFECTS REGRESSIONS
# =============================================================================

cat("\n\n=============================================================================")
cat("\n1. PANEL DATA (FIXED EFFECTS) with volETH (replacing ETHreturn)")
cat("\n=============================================================================\n")

# 1.a Logarithmic transformations (CREATE LOG VARIABLES FIRST)
panel_data <- panel_data %>%
  mutate(
    log_A1 = log(!!sym(A1) + 1),
    log_A2 = log(!!sym(A2) + 1),
    log_B1 = log(!!sym(B1) + 1),
    log_B2 = log(!!sym(B2) + 1),
    log_B3 = log(!!sym(B3) + 1)
  )

# Define log-transformed variable names AFTER creating them
log_ivs_reg <- c(all_dummies, all_controls_reg, "log_B1", "log_B2", "log_B3", B4)
log_ivs_reg_no_dummies <- c(all_controls_reg, "log_B1", "log_B2", "log_B3", B4)

cat("\n--- Correlation Matrix (log‑transformed independent variables, using volETH) ---\n")
cor_panel <- cor(panel_data[, log_ivs_reg], use = "complete.obs")
print(round(cor_panel, 6))

# VIF for panel data - with dummies
panel_vif_data <- panel_data[, c("log_A1", log_ivs_reg)]
calculate_vif(panel_vif_data, "log_A1", log_ivs_reg, "(with dummies)")

# VIF for panel data - without dummies
calculate_vif(panel_vif_data, "log_A1", log_ivs_reg_no_dummies, "(without dummies)")

# 1.c Interaction terms
panel_data <- panel_data %>%
  mutate(
    B1_net2 = log_B1 * (Network == "network2"),
    B1_net3 = log_B1 * (Network == "network3")
  )

# Prepare pdata.frame
panel_fe <- pdata.frame(panel_data, index = c("Network", "Date"))

# 1.d Fixed effects with log_A1 (uses volETH, not ETHreturn)
cat("\n--- Fixed Effects Regression: log(A1) ---\n")
formula_fe_a1 <- as.formula(paste(
  "log_A1 ~ log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +",
  B4, "+",
  paste(c(all_dummies, all_controls_reg), collapse = " + ")
))
fe_a1 <- plm(formula_fe_a1, data = panel_fe, model = "within", effect = "individual")
print(summary(fe_a1))

# 1.e Fixed effects with log_A2 (uses volETH, not ETHreturn)
cat("\n--- Fixed Effects Regression: log(A2) ---\n")
formula_fe_a2 <- as.formula(paste(
  "log_A2 ~ log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3+",
  B4, "+",
  paste(c(all_dummies, all_controls_reg), collapse = " + ")
))
fe_a2 <- plm(formula_fe_a2, data = panel_fe, model = "within", effect = "individual")
print(summary(fe_a2))

# =============================================================================
# 3. AGGREGATED OLS REGRESSIONS
# =============================================================================

cat("\n\n=============================================================================")
cat("\n2. AGGREGATED OLS REGRESSIONS with volETH (replacing ETHreturn)")
cat("\n=============================================================================\n")

# 1.a Logarithmic transformations on aggregated data (CREATE LOG VARIABLES FIRST)
agg_data <- agg_raw %>%
  mutate(
    log_A1 = log(!!sym(A1) + 1),
    log_A2 = log(!!sym(A2) + 1),
    log_B1 = log(!!sym(B1) + 1),
    log_B2 = log(!!sym(B2) + 1),
    log_B3 = log(!!sym(B3) + 1)
  )

# Use the already-defined log_ivs_reg (from panel section)
# These variable names are the same for aggregated data

cat("\n--- Correlation Matrix (log‑transformed, using volETH) ---\n")
cor_agg_log <- cor(agg_data[, log_ivs_reg], use = "complete.obs")
print(round(cor_agg_log, 6))

# VIF for aggregated - with dummies
agg_vif_data <- agg_data[, c("log_A1", log_ivs_reg)]
calculate_vif(agg_vif_data, "log_A1", log_ivs_reg, "(with dummies)")

# VIF for aggregated - without dummies
calculate_vif(agg_vif_data, "log_A1", log_ivs_reg_no_dummies, "(without dummies)")

# 1.c OLS with log_A1 (uses volETH, not ETHreturn)
cat("\nOLS Regression: log(A1) \n")
formula_ols_a1 <- as.formula(paste(
  "log_A1 ~", paste(log_ivs_reg, collapse = " + ")
))
ols_agg_a1 <- lm(formula_ols_a1, data = agg_data)
print(summary(ols_agg_a1))

# 1.e OLS with log_A2 (uses volETH, not ETHreturn)
cat("\n OLS Regression: log(A2) \n")
formula_ols_a2 <- as.formula(paste(
  "log_A2 ~", paste(log_ivs_reg, collapse = " + ")
))
ols_agg_a2 <- lm(formula_ols_a2, data = agg_data)
print(summary(ols_agg_a2))

# =============================================================================
# 4. NETWORK-SPECIFIC OLS REGRESSIONS
# =============================================================================

cat("\n\n=============================================================================")
cat("\n3. NETWORK-SPECIFIC OLS REGRESSIONS with volETH (replacing ETHreturn)")
cat("\n=============================================================================\n")

net_results <- list()

for (i in 1:3) {
  net_name <- paste0("network", i)
  net_data <- panel_data %>% filter(Network == net_name)
  
  cat("\n", paste(rep("=", 60), collapse = ""))
  cat(sprintf("\n--- Network %d (%s) ---\n", i, net_name))
  
  # Network-specific VIFs (with and without dummies)
  net_vif_data <- net_data[, c("log_A1", log_ivs_reg)]
  calculate_vif(net_vif_data, "log_A1", log_ivs_reg, sprintf("(Network %d, with dummies)", i))
  calculate_vif(net_vif_data, "log_A1", log_ivs_reg_no_dummies, sprintf("(Network %d, without dummies)", i))
  
  # OLS with log_A1 (uses volETH, not ETHreturn)
  cat(sprintf("\nOLS: log(A1) for %s\n", net_name))
  formula_net_a1 <- as.formula(paste(
    "log_A1 ~", paste(log_ivs_reg, collapse = " + ")
  ))
  ols_net_a1 <- lm(formula_net_a1, data = net_data)
  print(summary(ols_net_a1))
  
  # OLS with log_A2 (uses volETH, not ETHreturn)
  cat(sprintf("\nOLS: log(A2) for %s\n", net_name))
  formula_net_a2 <- as.formula(paste(
    "log_A2 ~", paste(log_ivs_reg, collapse = " + ")
  ))
  ols_net_a2 <- lm(formula_net_a2, data = net_data)
  print(summary(ols_net_a2))
  
  net_results[[i]] <- list(a1 = ols_net_a1, a2 = ols_net_a2)
}

# =============================================================================
# 5. SUMMARY TABLE OF ALL MODELS
# =============================================================================

cat("\n\n=============================================================================")
cat("\n4. SUMMARY TABLE OF ALL 10 REGRESSIONS (using volETH)")
cat("\n=============================================================================\n")

all_models <- list(
  "Panel_FE_logA1" = fe_a1,
  "Panel_FE_logA2" = fe_a2,
  "Agg_OLS_logA1"  = ols_agg_a1,
  "Agg_OLS_logA2"  = ols_agg_a2,
  "Net1_logA1"     = net_results[[1]]$a1,
  "Net1_logA2"     = net_results[[1]]$a2,
  "Net2_logA1"     = net_results[[2]]$a1,
  "Net2_logA2"     = net_results[[2]]$a2,
  "Net3_logA1"     = net_results[[3]]$a1,
  "Net3_logA2"     = net_results[[3]]$a2
)

stargazer(all_models, type = "text",
          title = "Complete Regression Results (using volETH instead of ETHreturn)",
          column.labels = names(all_models),
          align = TRUE,
          digits = 6,
          omit.stat = c("ser", "f"),
          single.row = TRUE,
          no.space = TRUE)

# =============================================================================
# CLOSE OUTPUT REDIRECTION
# =============================================================================
sink()

cat("\n\nAll results have been saved to 'regression_results2.txt'\n")
cat("\nNote: \n")
cat("  - Summary statistics use ETHreturn\n")
cat("  - All regression analyses use volETH instead of ETHreturn\n")

# =============================================================================
# ADDITIONAL ROBUSTNESS CHECKS FOR ENDOGENEITY / IDENTIFICATION
# =============================================================================

# Load required packages for IV/2SLS
if (!require("ivreg")) install.packages("ivreg")
library(ivreg)

# -----------------------------------------------------------------------------
# 6. TWO-WAY FIXED EFFECTS (Individual + Time) - Omitted Variable Bias
# -----------------------------------------------------------------------------

cat("\n\n=============================================================================")
cat("\n6. TWO-WAY FIXED EFFECTS (Individual + Time) -- Omitted Variable Bias Check")
cat("\n=============================================================================\n")

tw_formula_a1 <- as.formula(paste(
  "log_A1 ~ log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +",
  B4, "+", paste(all_controls_reg, collapse = " + ")
))
tw_formula_a2 <- as.formula(paste(
  "log_A2 ~ log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +",
  B4, "+", paste(all_controls_reg, collapse = " + ")
))

tw_a1 <- plm(tw_formula_a1, data = panel_fe, model = "within", effect = "twoways")
tw_a2 <- plm(tw_formula_a2, data = panel_fe, model = "within", effect = "twoways")

cat("\n--- Two-Way FE: log(A1) [TVL] ---\n"); print(summary(tw_a1))
cat("\n--- Two-Way FE: log(A2) [Revenue] ---\n"); print(summary(tw_a2))

cat("\n--- Coefficient stability: Individual FE vs Two-Way FE (BridgeVolume) ---\n")
comp_tw <- data.frame(
  Model = c("Indiv FE (TVL)", "Two-way FE (TVL)", "Indiv FE (Rev)", "Two-way FE (Rev)"),
  BridgeVolume_coef = c(coef(fe_a1)["log_B1"], coef(tw_a1)["log_B1"],
                        coef(fe_a2)["log_B1"], coef(tw_a2)["log_B1"])
)
print(comp_tw)
cat("\nCaution: With only 3 cross-sectional units, two-way FE uses ~800 day dummies,\n")
cat("leaving very few residual degrees of freedom. Interpret changes cautiously.\n")

# -----------------------------------------------------------------------------
# 7. LAGGED-VARIABLE ROBUSTNESS SUITE - Reverse Causality / Simultaneity
# -----------------------------------------------------------------------------
# Create lagged variables (t-1, t-2, t-3) for all continuous regressors
panel_data <- panel_data %>%
  arrange(Network, Date) %>%
  group_by(Network) %>%
  mutate(
    # Bridge volume lags and interactions
    L1_log_B1  = dplyr::lag(log_B1, 1),
    L2_log_B1  = dplyr::lag(log_B1, 2),
    L3_log_B1  = dplyr::lag(log_B1, 3),
    L1_B1_net2 = dplyr::lag(B1_net2, 1),
    L1_B1_net3 = dplyr::lag(B1_net3, 1),
    L2_B1_net2 = dplyr::lag(B1_net2, 2),
    L2_B1_net3 = dplyr::lag(B1_net3, 2),
    L3_B1_net2 = dplyr::lag(B1_net2, 3),
    L3_B1_net3 = dplyr::lag(B1_net3, 3),
    # Other continuous regressors at lag 1 (for fully-lagged spec)
    L1_log_B2 = dplyr::lag(log_B2, 1),
    L1_log_B3 = dplyr::lag(log_B3, 1),
    L1_CER    = dplyr::lag(!!sym(B4), 1),
    L1_ETH_APY        = dplyr::lag(!!sym(C1), 1),
    L1_Stablecoin_APY = dplyr::lag(!!sym(C2), 1),
    L1_GasPrice        = dplyr::lag(!!sym(C3), 1),
    L1_FGI             = dplyr::lag(!!sym(C5), 1),
    L1_volETH          = dplyr::lag(!!sym(C6), 1)
  ) %>%
  ungroup()

panel_fe_lag <- pdata.frame(panel_data, index = c("Network", "Date"))

cat("\n\n=============================================================================")
cat("\n7. LAGGED-VARIABLE ROBUSTNESS SUITE -- Reverse Causality / Simultaneity")
cat("\n=============================================================================\n")

# 7.1 Single-lag models (lags 1, 2, 3)
cat("\n--- 7.1 Single-Lag Models: log(A1) [TVL] ---\n")
for (lag in 1:3) {
  lag_var <- paste0("L", lag, "_log_B1")
  lag_net2 <- paste0("L", lag, "_B1_net2")
  lag_net3 <- paste0("L", lag, "_B1_net3")
  fml <- as.formula(paste(
    "log_A1 ~", lag_var, "+", lag_net2, "+", lag_net3, "+ log_B2 + log_B3 +",
    B4, "+", paste(c(all_dummies, all_controls_reg), collapse = " + ")
  ))
  mod <- plm(fml, data = panel_fe_lag, model = "within", effect = "individual")
  cat(sprintf("\nLag %d:\n", lag)); print(summary(mod))
}

cat("\n--- 7.1 Single-Lag Models: log(A2) [Revenue] ---\n")
for (lag in 1:3) {
  lag_var <- paste0("L", lag, "_log_B1")
  lag_net2 <- paste0("L", lag, "_B1_net2")
  lag_net3 <- paste0("L", lag, "_B1_net3")
  fml <- as.formula(paste(
    "log_A2 ~", lag_var, "+", lag_net2, "+", lag_net3, "+ log_B2 + log_B3 +",
    B4, "+", paste(c(all_dummies, all_controls_reg), collapse = " + ")
  ))
  mod <- plm(fml, data = panel_fe_lag, model = "within", effect = "individual")
  cat(sprintf("\nLag %d:\n", lag)); print(summary(mod))
}

# 7.2 Distributed-lag model (lags 0, 1, 2 together)
cat("\n--- 7.2 Distributed-Lag Model (BridgeVolume lags 0+1+2) ---\n")
dl_fml_a1 <- as.formula(paste(
  "log_A1 ~ log_B1 + L1_log_B1 + L2_log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +",
  B4, "+", paste(c(all_dummies, all_controls_reg), collapse = " + ")
))
dl_a1 <- plm(dl_fml_a1, data = panel_fe_lag, model = "within", effect = "individual")
cat("\nlog(A1):\n"); print(summary(dl_a1))

dl_fml_a2 <- as.formula(paste(
  "log_A2 ~ log_B1 + L1_log_B1 + L2_log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +",
  B4, "+", paste(c(all_dummies, all_controls_reg), collapse = " + ")
))
dl_a2 <- plm(dl_fml_a2, data = panel_fe_lag, model = "within", effect = "individual")
cat("\nlog(A2):\n"); print(summary(dl_a2))

# Cumulative effects (sum of lags 0+1+2)
cum_a1 <- sum(coef(dl_a1)[c("log_B1", "L1_log_B1", "L2_log_B1")])
cum_a2 <- sum(coef(dl_a2)[c("log_B1", "L1_log_B1", "L2_log_B1")])
cat(sprintf("\nCumulative BridgeVolume effect (0+1+2): TVL = %.6f, Revenue = %.6f\n", cum_a1, cum_a2))

# 7.3 Fully-lagged specification (all continuous regressors at t-1)
cat("\n--- 7.3 Fully-Lagged Model (all continuous regressors at t-1) ---\n")
cat("(Event dummies kept contemporaneous, as they are instantaneous shocks.)\n")

full_fml_a1 <- as.formula(paste(
  "log_A1 ~ L1_log_B1 + L1_B1_net2 + L1_B1_net3 + L1_log_B2 + L1_log_B3 + L1_CER +",
  paste(all_dummies, collapse = " + "), "+",
  "L1_ETH_APY + L1_Stablecoin_APY + L1_GasPrice + L1_FGI + L1_volETH"
))
full_a1 <- plm(full_fml_a1, data = panel_fe_lag, model = "within", effect = "individual")
cat("\nlog(A1):\n"); print(summary(full_a1))

full_fml_a2 <- as.formula(paste(
  "log_A2 ~ L1_log_B1 + L1_B1_net2 + L1_B1_net3 + L1_log_B2 + L1_log_B3 + L1_CER +",
  paste(all_dummies, collapse = " + "), "+",
  "L1_ETH_APY + L1_Stablecoin_APY + L1_GasPrice + L1_FGI + L1_volETH"
))
full_a2 <- plm(full_fml_a2, data = panel_fe_lag, model = "within", effect = "individual")
cat("\nlog(A2):\n"); print(summary(full_a2))

# 7.4 Coefficient stability table
cat("\n--- 7.4 BridgeVolume Coefficient Across Lag Specifications ---\n")
lag_comp <- data.frame(
  Specification = c("Contemporaneous", "Lag 1", "Lag 2", "Lag 3",
                    "Distributed (cumulative 0+1+2)", "Fully lagged (t-1)"),
  TVL_coef = c(coef(fe_a1)["log_B1"], 
               coef(plm(as.formula(paste("log_A1 ~ L1_log_B1 + L1_B1_net2 + L1_B1_net3 + log_B2 + log_B3 +", B4, "+", paste(c(all_dummies, all_controls_reg), collapse=" + "))), data=panel_fe_lag, model="within", effect="individual"))["L1_log_B1"],
               coef(plm(as.formula(paste("log_A1 ~ L2_log_B1 + L2_B1_net2 + L2_B1_net3 + log_B2 + log_B3 +", B4, "+", paste(c(all_dummies, all_controls_reg), collapse=" + "))), data=panel_fe_lag, model="within", effect="individual"))["L2_log_B1"],
               coef(plm(as.formula(paste("log_A1 ~ L3_log_B1 + L3_B1_net2 + L3_B1_net3 + log_B2 + log_B3 +", B4, "+", paste(c(all_dummies, all_controls_reg), collapse=" + "))), data=panel_fe_lag, model="within", effect="individual"))["L3_log_B1"],
               cum_a1,
               coef(full_a1)["L1_log_B1"]),
  Revenue_coef = c(coef(fe_a2)["log_B1"],
                   coef(plm(as.formula(paste("log_A2 ~ L1_log_B1 + L1_B1_net2 + L1_B1_net3 + log_B2 + log_B3 +", B4, "+", paste(c(all_dummies, all_controls_reg), collapse=" + "))), data=panel_fe_lag, model="within", effect="individual"))["L1_log_B1"],
                   coef(plm(as.formula(paste("log_A2 ~ L2_log_B1 + L2_B1_net2 + L2_B1_net3 + log_B2 + log_B3 +", B4, "+", paste(c(all_dummies, all_controls_reg), collapse=" + "))), data=panel_fe_lag, model="within", effect="individual"))["L2_log_B1"],
                   coef(plm(as.formula(paste("log_A2 ~ L3_log_B1 + L3_B1_net2 + L3_B1_net3 + log_B2 + log_B3 +", B4, "+", paste(c(all_dummies, all_controls_reg), collapse=" + "))), data=panel_fe_lag, model="within", effect="individual"))["L3_log_B1"],
                   cum_a2,
                   coef(full_a2)["L1_log_B1"])
)
print(lag_comp)
cat("\nInterpretation: Stability of sign and magnitude across lags weakens the\n")
cat("concern that contemporaneous estimates are driven solely by reverse causality.\n")

# -----------------------------------------------------------------------------
# 8. INSTRUMENTAL VARIABLES (2SLS) - Endogeneity / Simultaneity
# -----------------------------------------------------------------------------

cat("\n\n=============================================================================")
cat("\n8. TWO-STAGE LEAST SQUARES (2SLS) -- Endogeneity Check")
cat("\n=============================================================================\n")

# Preparing data with no missing values for the instrument
iv_data <- panel_data %>% filter(!is.na(L2_log_B1))

# Defining RHS (including all exogenous regressors) and instruments
# We instrument only log_B1 (and its interactions must also be instrumented)
# But here we treat B1_net2 and B1_net3 as endogenous because they are functions of log_B1.
# Standard practice: instrument log_B1 with L2_log_B1, and use the same interactions
# of the instrument with network dummies.
iv_data <- iv_data %>%
  mutate(
    L2_B1_net2 = L2_log_B1 * (Network == "network2"),
    L2_B1_net3 = L2_log_B1 * (Network == "network3")
  )

# First-stage regressions (for diagnostics) are automatically reported by ivreg
iv_rhs <- paste(
  "log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +", B4, "+",
  paste(c(all_dummies, all_controls_reg), collapse = " + "), "+ factor(Network)"
)
iv_instruments <- paste(
  "L2_log_B1 + L2_B1_net2 + L2_B1_net3 + log_B2 + log_B3 +", B4, "+",
  paste(c(all_dummies, all_controls_reg), collapse = " + "), "+ factor(Network)"
)

iv_fml_a1 <- as.formula(paste("log_A1 ~", iv_rhs, "|", iv_instruments))
iv_a1 <- ivreg(iv_fml_a1, data = iv_data)
cat("\n--- 2SLS: log(A1) [TVL] ---\n")
print(summary(iv_a1, diagnostics = TRUE))

iv_fml_a2 <- as.formula(paste("log_A2 ~", iv_rhs, "|", iv_instruments))
iv_a2 <- ivreg(iv_fml_a2, data = iv_data)
cat("\n--- 2SLS: log(A2) [Revenue] ---\n")
print(summary(iv_a2, diagnostics = TRUE))

# Compare OLS vs IV coefficients for bridge volume
cat("\n--- OLS vs IV Comparison (BridgeVolume coefficient) ---\n")
comp_iv <- data.frame(
  Model = c("OLS (TVL)", "IV (TVL)", "OLS (Rev)", "IV (Rev)"),
  BridgeVolume_coef = c(coef(ols_agg_a1)["log_B1"], coef(iv_a1)["log_B1"],
                        coef(ols_agg_a2)["log_B1"], coef(iv_a2)["log_B1"])
)
print(comp_iv)
cat("\nIf IV coefficient differs substantially from OLS, endogeneity may be present.\n")
cat("Check first-stage F-statistic (should be >10 for strong instrument).\n")

# -----------------------------------------------------------------------------
# 9. DIFFERENCE-IN-DIFFERENCES - Event Dummies x Network Category
# -----------------------------------------------------------------------------
# Tests whether the impact of each event varies by network type (L1 is reference).
cat("\n\n=============================================================================")
cat("\n9. DIFFERENCE-IN-DIFFERENCES (Event Dummy x Network Category)")
cat("\n=============================================================================\n")

# Create interaction terms
panel_data <- panel_data %>%
  mutate(
    Net_L2    = as.numeric(Network == "network2"),
    Net_AltL1 = as.numeric(Network == "network3"),
    Hack_L2   = !!sym(D1) * Net_L2,
    Hack_AltL1= !!sym(D1) * Net_AltL1,
    Integ_L2  = !!sym(D2) * Net_L2,
    Integ_AltL1= !!sym(D2) * Net_AltL1,
    Mainnet_L2= !!sym(D3) * Net_L2,
    Mainnet_AltL1= !!sym(D3) * Net_AltL1
  )
panel_fe_did <- pdata.frame(panel_data, index = c("Network", "Date"))

did_fml_a1 <- as.formula(paste(
  "log_A1 ~ log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +", B4, "+",
  paste(all_controls_reg, collapse = " + "), "+",
  D1, "+ Hack_L2 + Hack_AltL1 +",
  D2, "+ Integ_L2 + Integ_AltL1 +",
  D3, "+ Mainnet_L2 + Mainnet_AltL1"
))
did_a1 <- plm(did_fml_a1, data = panel_fe_did, model = "within", effect = "individual")
cat("\n--- DiD: log(A1) [TVL] -- event effects by network (L1 = reference) ---\n")
print(summary(did_a1))

did_fml_a2 <- as.formula(paste(
  "log_A2 ~ log_B1 + B1_net2 + B1_net3 + log_B2 + log_B3 +", B4, "+",
  paste(all_controls_reg, collapse = " + "), "+",
  D1, "+ Hack_L2 + Hack_AltL1 +",
  D2, "+ Integ_L2 + Integ_AltL1 +",
  D3, "+ Mainnet_L2 + Mainnet_AltL1"
))
did_a2 <- plm(did_fml_a2, data = panel_fe_did, model = "within", effect = "individual")
cat("\n--- DiD: log(A2) [Revenue] -- event effects by network (L1 = reference) ---\n")
print(summary(did_a2))

cat("\nInterpretation: The coefficients on the interaction terms capture whether the\n")
cat("impact of each event differs significantly between L2/AltL1 and L1.\n")
cat("If they are statistically significant, it supports heterogeneous effects across architectures.\n")

# -----------------------------------------------------------------------------
# END OF ADDITIONAL CODE
# -----------------------------------------------------------------------------

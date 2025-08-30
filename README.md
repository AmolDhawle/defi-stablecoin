# 🏦 DeFi Stablecoin Project

A decentralized stablecoin protocol built with **Solidity** and **Foundry** that allows users to deposit collateral, mint stablecoins, burn them, redeem collateral, and handle liquidations. This project also integrates **Chainlink oracles** for price feeds, with additional safety checks for stale data.

---

## 📌 Features

- 💰 **Collateralized Minting** – Deposit approved assets as collateral to mint stablecoins.
- 🔥 **Burning Stablecoins** – Burn coins to reduce debt and free up collateral.
- 💳 **Collateral Redemption** – Redeem collateral once debt is cleared.
- ⚖️ **Liquidation Mechanism** – Liquidate unhealthy positions to maintain system stability.
- 🧪 **Comprehensive Testing** – Includes unit tests, fuzz testing, and edge-case handling.
- 📡 **Oracle Integration** – Uses Chainlink price feeds with a library to check for **stale data**.

---

## 📚 Learnings

Through this project, I gained hands-on experience with:

1. Understanding **DeFi** and the role of **stablecoins**.
2. Depositing collateral and managing balances.
3. Minting and burning stablecoins securely.
4. Redeeming collateral after debt repayment.
5. Implementing **liquidation** mechanisms for unhealthy positions.
6. Writing and running tests, including **fuzz testing** in Foundry.
7. Building a **custom library** to verify Chainlink oracle freshness (stale data checks).

---

## ⚙️ Tech Stack

- **Solidity (0.8.20+)**
- **Foundry (Forge, Cast, Anvil)**
- **Chainlink Oracles**

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/AmolDhawle/defi-stablecoin.git
cd defi-stablecoin
```

### 2.Install dependecies

```bash
forge install
```

### 3. Build the contracts

```bash
forge build
```

### 4. Run tests

```bash
forge test
```

To run fuzz tests:

```bash
forge test --fuzz-runs 1000
```

### 5. Run coverage

```bash
forge coverage
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Acknowledgements

Special thanks to Patrick Collins, Cyfrin Updraft and the Foundry community for their tutorials and guidance on building DeFi protocols.

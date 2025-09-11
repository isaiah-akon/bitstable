# BitStable Protocol

## Decentralized Bitcoin-Collateralized Stablecoin on Stacks

---

## 📖 Overview

**BitStable** is a decentralized stablecoin protocol built on the **Stacks blockchain**, secured by Bitcoin finality. It enables users to mint a **USD-pegged stablecoin** by locking **STX as collateral**, leveraging Bitcoin’s security model while introducing **trustless DeFi primitives** to the Bitcoin ecosystem.

The protocol ensures stability and solvency through:

* **Over-collateralization** mechanisms
* **Automated liquidation systems**
* **Multi-oracle price feeds**
* **Governance-driven parameter adjustment**
* **Emergency shutdown** safeguards

---

## ✨ Key Features

* **Bitcoin-settled stablecoin minting & redemption**
* **Dynamic collateral ratios** with liquidation protection
* **Decentralized liquidation system** via authorized liquidators
* **Oracle-based BTC/USD price aggregation**
* **Governance controls** for protocol parameters
* **Emergency shutdown** for crisis response

---

## ⚙️ Protocol Design

### **Vault System**

* Each user opens a **vault** by depositing **STX collateral**.
* Users can mint stablecoins (debt) against their collateral while maintaining the **minimum collateral ratio**.
* Vaults track:

  * Collateral amount
  * Debt amount
  * Accumulated fees
  * Last interaction block

### **Stability Mechanisms**

* **Minimum Collateral Ratio (MCR):** Default **150%**
* **Liquidation Threshold:** Default **125%**
* **Protocol Fee:** Default **5% annual**
* **Stability Fee Cap:** Maximum **50%**

### **Liquidation System**

* Vaults falling below the **liquidation threshold** become liquidatable.
* Authorized liquidators can trigger liquidation to seize collateral and burn outstanding debt.

### **Oracle System**

* BTC/USD price is updated by **authorized oracles**.
* Oracle updates must pass validation against **upper and lower bounds**.

### **Governance Parameters**

* Adjustable via governance or protocol owner:

  * Minimum collateral ratio
  * Liquidation threshold
  * Stability fee
  * Oracle and liquidator authorizations

### **Emergency Shutdown**

* Halts minting, liquidation, and withdrawals.
* Activated by protocol owner in case of catastrophic failure.

---

## 🛠️ Core Functions

### **Vault Management**

* `deposit-collateral(amount)` → Deposit STX into a vault
* `withdraw-collateral(amount)` → Withdraw collateral (if ratio is safe)
* `mint-stablecoin(amount)` → Mint stablecoin debt
* `repay-debt(amount)` → Repay debt to reduce exposure

### **Liquidation**

* `liquidate-vault(vault-owner)` → Liquidate an undercollateralized vault

### **Oracle**

* `update-btc-price(new-price)` → Update BTC/USD price feed

### **Governance**

* `update-minimum-collateral-ratio(new-ratio)`
* `update-liquidation-threshold(new-threshold)`
* `authorize-liquidator(address)`
* `authorize-oracle(address)`
* `trigger-emergency-shutdown()`

### **Read-Only Queries**

* `get-vault-info(user)` → Returns user vault data
* `get-vault-collateral-ratio(user)` → Returns vault health ratio
* `get-protocol-info()` → Returns protocol-wide state
* `get-protocol-version()` → Returns protocol metadata

---

## 🔒 Security Assumptions

* Collateral is always **over-collateralized** with strict liquidation rules.
* Oracle manipulation is mitigated via **multi-oracle authorization**.
* Protocol owner retains **administrative emergency powers**.
* All state transitions are validated via **error codes and assertions**.

---

## 🚀 Deployment

* **Protocol Name:** `BitStable`
* **Version:** `2.0.0`
* **Network:** `stacks-mainnet`

---

## 📊 Error Codes

| Code    | Description                    |
| ------- | ------------------------------ |
| `u1001` | Unauthorized caller            |
| `u1002` | Insufficient collateral        |
| `u1003` | Below minimum collateral ratio |
| `u1004` | Protocol not initialized       |
| `u1005` | Protocol already initialized   |
| `u1006` | Insufficient balance           |
| `u1007` | Invalid price feed             |
| `u1008` | Emergency shutdown active      |
| `u1009` | Invalid parameter              |
| `u1010` | Vault not found                |

---

## 📜 License

This protocol is open-sourced under the **MIT License**.

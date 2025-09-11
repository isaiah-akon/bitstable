;; BITSTABLE PROTOCOL

;; Title: BitStable - Decentralized Bitcoin-Collateralized Stablecoin
;; Summary: A trustless stablecoin protocol that leverages Bitcoin's security through Stacks Layer 2
;;
;; Description:
;; BitStable represents the evolution of decentralized finance on Bitcoin, enabling users to mint
;; USD-pegged stablecoins using STX as collateral. Built on Stacks, this protocol inherits Bitcoin's
;; security model while providing DeFi primitives previously unavailable to the Bitcoin ecosystem.
;;
;; The protocol implements over-collateralization mechanisms, automated liquidation systems, and
;; oracle-driven price feeds to maintain stability. Users can open collateralized debt positions,
;; mint stablecoins against their STX holdings, and participate in a decentralized lending market
;; that settles on Bitcoin's base layer.
;;
;; Key Features:
;; - Bitcoin-settled stablecoin minting and redemption
;; - Dynamic collateral ratios with liquidation protection
;; - Multi-oracle price aggregation for enhanced security
;; - Governance-driven parameter adjustment
;; - Emergency shutdown mechanisms for crisis management

;; PROTOCOL CONSTANTS

(define-constant CONTRACT_OWNER tx-sender)
(define-constant PROTOCOL_NAME "BitStable")

;; Error Constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1002))
(define-constant ERR_BELOW_MINIMUM_RATIO (err u1003))
(define-constant ERR_PROTOCOL_NOT_INITIALIZED (err u1004))
(define-constant ERR_PROTOCOL_ALREADY_INITIALIZED (err u1005))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1006))
(define-constant ERR_INVALID_PRICE_FEED (err u1007))
(define-constant ERR_EMERGENCY_SHUTDOWN_ACTIVE (err u1008))
(define-constant ERR_INVALID_PARAMETER (err u1009))
(define-constant ERR_VAULT_NOT_FOUND (err u1010))

;; Protocol Limits
(define-constant MAX_PRICE_USD u100000000000) ;; $100,000 max BTC price
(define-constant MIN_PRICE_USD u100000) ;; $1,000 min BTC price
(define-constant MAX_COLLATERAL_RATIO u500) ;; 500% maximum ratio
(define-constant MIN_COLLATERAL_RATIO u110) ;; 110% minimum ratio
(define-constant MAX_STABILITY_FEE u50) ;; 50% maximum annual fee

;; PROTOCOL PARAMETERS

(define-data-var minimum-collateral-ratio uint u150) ;; 150% minimum collateralization
(define-data-var liquidation-threshold uint u125) ;; 125% liquidation trigger
(define-data-var protocol-fee uint u5) ;; 5% annual stability fee
(define-data-var protocol-initialized bool false)
(define-data-var emergency-shutdown-enabled bool false)
(define-data-var btc-usd-price uint u0)
(define-data-var price-feed-active bool false)
(define-data-var total-collateral-locked uint u0)
(define-data-var total-stablecoin-supply uint u0)

;; DATA STRUCTURES

;; User Vault Structure
(define-map user-vaults
  principal
  {
    collateral-amount: uint,
    debt-amount: uint,
    last-interaction: uint,
    accumulated-fees: uint,
  }
)

;; Authorized Roles
(define-map authorized-liquidators
  principal
  bool
)
(define-map authorized-oracles
  principal
  bool
)

;; VALIDATION FUNCTIONS

(define-private (validate-price (price uint))
  (and (>= price MIN_PRICE_USD) (<= price MAX_PRICE_USD))
)

(define-private (validate-collateral-ratio (ratio uint))
  (and (>= ratio MIN_COLLATERAL_RATIO) (<= ratio MAX_COLLATERAL_RATIO))
)

(define-private (validate-fee-rate (fee uint))
  (<= fee MAX_STABILITY_FEE)
)

(define-private (is-protocol-active)
  (and (var-get protocol-initialized) (not (var-get emergency-shutdown-enabled)))
)

(define-private (calculate-collateral-ratio
    (collateral uint)
    (debt uint)
  )
  (if (is-eq debt u0)
    u0
    (/ (* (* collateral (var-get btc-usd-price)) u100) debt)
  )
)

;; CORE PROTOCOL FUNCTIONS

;; Initialize the BitStable Protocol
(define-public (initialize-protocol (initial-btc-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (var-get protocol-initialized))
      ERR_PROTOCOL_ALREADY_INITIALIZED
    )
    (asserts! (validate-price initial-btc-price) ERR_INVALID_PARAMETER)

    (var-set btc-usd-price initial-btc-price)
    (var-set price-feed-active true)
    (var-set protocol-initialized true)

    (print {
      event: "protocol-initialized",
      initial-price: initial-btc-price,
      protocol: PROTOCOL_NAME,
    })
    (ok true)
  )
)

;; Deposit STX collateral to create or expand vault
(define-public (deposit-collateral (amount uint))
  (let (
      (current-vault (default-to {
        collateral-amount: u0,
        debt-amount: u0,
        last-interaction: u0,
        accumulated-fees: u0,
      }
        (map-get? user-vaults tx-sender)
      ))
      (new-collateral (+ (get collateral-amount current-vault) amount))
    )
    (asserts! (is-protocol-active) ERR_PROTOCOL_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_INVALID_PARAMETER)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update vault and global state
    (map-set user-vaults tx-sender
      (merge current-vault {
        collateral-amount: new-collateral,
        last-interaction: burn-block-height,
      })
    )
    (var-set total-collateral-locked (+ (var-get total-collateral-locked) amount))

    (print {
      event: "collateral-deposited",
      user: tx-sender,
      amount: amount,
      total-collateral: new-collateral,
    })
    (ok true)
  )
)

;; Mint stablecoin against collateral
(define-public (mint-stablecoin (amount uint))
  (let (
      (vault (unwrap! (map-get? user-vaults tx-sender) ERR_VAULT_NOT_FOUND))
      (current-collateral (get collateral-amount vault))
      (current-debt (get debt-amount vault))
      (new-debt (+ current-debt amount))
      (collateral-ratio (calculate-collateral-ratio current-collateral new-debt))
    )
    (asserts! (is-protocol-active) ERR_PROTOCOL_NOT_INITIALIZED)
    (asserts! (var-get price-feed-active) ERR_INVALID_PRICE_FEED)
    (asserts! (> amount u0) ERR_INVALID_PARAMETER)
    (asserts! (>= collateral-ratio (var-get minimum-collateral-ratio))
      ERR_BELOW_MINIMUM_RATIO
    )

    ;; Update vault
    (map-set user-vaults tx-sender
      (merge vault {
        debt-amount: new-debt,
        last-interaction: burn-block-height,
      })
    )
    (var-set total-stablecoin-supply (+ (var-get total-stablecoin-supply) amount))

    (print {
      event: "stablecoin-minted",
      user: tx-sender,
      amount: amount,
      collateral-ratio: collateral-ratio,
    })
    (ok true)
  )
)

;; Repay stablecoin debt
(define-public (repay-debt (amount uint))
  (let (
      (vault (unwrap! (map-get? user-vaults tx-sender) ERR_VAULT_NOT_FOUND))
      (current-debt (get debt-amount vault))
    )
    (asserts! (is-protocol-active) ERR_PROTOCOL_NOT_INITIALIZED)
    (asserts! (>= current-debt amount) ERR_INSUFFICIENT_BALANCE)

    (map-set user-vaults tx-sender
      (merge vault {
        debt-amount: (- current-debt amount),
        last-interaction: burn-block-height,
      })
    )
    (var-set total-stablecoin-supply (- (var-get total-stablecoin-supply) amount))

    (print {
      event: "debt-repaid",
      user: tx-sender,
      amount: amount,
      remaining-debt: (- current-debt amount),
    })
    (ok true)
  )
)

;; Withdraw collateral from vault
(define-public (withdraw-collateral (amount uint))
  (let (
      (vault (unwrap! (map-get? user-vaults tx-sender) ERR_VAULT_NOT_FOUND))
      (current-collateral (get collateral-amount vault))
      (current-debt (get debt-amount vault))
      (new-collateral (- current-collateral amount))
      (new-ratio (calculate-collateral-ratio new-collateral current-debt))
    )
    (asserts! (is-protocol-active) ERR_PROTOCOL_NOT_INITIALIZED)
    (asserts! (var-get price-feed-active) ERR_INVALID_PRICE_FEED)
    (asserts! (>= current-collateral amount) ERR_INSUFFICIENT_BALANCE)
    (asserts!
      (or
        (is-eq current-debt u0)
        (>= new-ratio (var-get minimum-collateral-ratio))
      )
      ERR_BELOW_MINIMUM_RATIO
    )

    ;; Transfer STX back to user
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))

    (map-set user-vaults tx-sender
      (merge vault {
        collateral-amount: new-collateral,
        last-interaction: burn-block-height,
      })
    )
    (var-set total-collateral-locked (- (var-get total-collateral-locked) amount))

    (print {
      event: "collateral-withdrawn",
      user: tx-sender,
      amount: amount,
      new-ratio: new-ratio,
    })
    (ok true)
  )
)

;; LIQUIDATION SYSTEM

(define-public (liquidate-vault (vault-owner principal))
  (let (
      (vault (unwrap! (map-get? user-vaults vault-owner) ERR_VAULT_NOT_FOUND))
      (collateral (get collateral-amount vault))
      (debt (get debt-amount vault))
      (collateral-ratio (calculate-collateral-ratio collateral debt))
    )
    (asserts! (var-get protocol-initialized) ERR_PROTOCOL_NOT_INITIALIZED)
    (asserts! (var-get price-feed-active) ERR_INVALID_PRICE_FEED)
    (asserts! (is-authorized-liquidator tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> debt u0) ERR_INVALID_PARAMETER)
    (asserts! (< collateral-ratio (var-get liquidation-threshold))
      ERR_INSUFFICIENT_COLLATERAL
    )

    ;; Clear vault and transfer collateral to liquidator
    (map-delete user-vaults vault-owner)
    (var-set total-collateral-locked
      (- (var-get total-collateral-locked) collateral)
    )
    (var-set total-stablecoin-supply (- (var-get total-stablecoin-supply) debt))

    (try! (as-contract (stx-transfer? collateral (as-contract tx-sender) tx-sender)))

    (print {
      event: "vault-liquidated",
      vault-owner: vault-owner,
      liquidator: tx-sender,
      collateral: collateral,
      debt: debt,
      ratio: collateral-ratio,
    })
    (ok true)
  )
)
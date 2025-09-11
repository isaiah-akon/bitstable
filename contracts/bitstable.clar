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
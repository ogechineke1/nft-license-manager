;; Digital Asset Licensing System - A Comprehensive NFT-Based License Manager
;; This smart contract enables content creators to issue, track, transfer, and revoke digital asset licenses.
;; The license system represents permissions as non-fungible tokens with rich metadata support.
;; Features include single and batch issuance, ownership verification, and complete lifecycle management.

;; ======================================
;; SECTION 1: CONSTANTS AND ERROR CODES
;; ======================================

;; System administrator definition
(define-constant contract-owner tx-sender) 

;; System limitations
(define-constant batch-issuance-limit u50) 

;; Error response codes
(define-constant error-permission-denied (err u200))
(define-constant error-duplicate-license (err u201))
(define-constant error-license-missing (err u202))
(define-constant error-license-id-invalid (err u203))
(define-constant error-license-details-invalid (err u204))
(define-constant error-license-terminated (err u205))
(define-constant error-batch-size-exceeded (err u206))
(define-constant error-empty-license-details (err u207))

;; ======================================
;; SECTION 2: DATA STORAGE DEFINITIONS
;; ======================================

;; Primary token representation for licenses
(define-non-fungible-token license-nft uint)

;; System state tracking
(define-data-var license-counter uint u0)

;; License data storage maps
(define-map license-details uint (string-ascii 512))
(define-map terminated-licenses uint bool)
(define-map batch-license-details uint (string-ascii 512))

;; ======================================
;; SECTION 3: PRIVATE HELPER FUNCTIONS
;; ======================================

;; Ownership verification helper
(define-private (owner-verification (license-id uint) (potential-owner principal))
    (is-eq potential-owner (unwrap! (nft-get-owner? license-nft license-id) false)))

;; License details validation
(define-private (details-validation (details (string-ascii 512)))
    (let 
        (
            (details-length (len details))
        )
        (and 
            (> details-length u0) 
            (<= details-length u512)
            (not (is-eq details ""))
        )
    ))

;; License status checking
(define-private (license-terminated-check (license-id uint))
    (default-to false (map-get? terminated-licenses license-id)))

;; License details length verification
(define-private (verify-details-length (details (string-ascii 512)))
    (let
        (
            (details-length (len details))
        )
        (ok (and (> details-length u0) (<= details-length u512)))))

;; Single license issuance core function
(define-private (issue-single-license (details (string-ascii 512)))
    (let 
        (
            (new-id (+ (var-get license-counter) u1))
        )
        (asserts! (details-validation details) error-license-details-invalid)
        (try! (nft-mint? license-nft new-id tx-sender))
        (map-set license-details new-id details)
        (var-set license-counter new-id)
        (ok new-id)))

;; Batch details validation
(define-private (validate-batch-details (details (string-ascii 512)) (valid-so-far bool))
    (and valid-so-far (details-validation details)))

;; Batch license issuance processor
(define-private (process-batch-item (details (string-ascii 512)) (issued-so-far (list 50 uint)))
    (match (issue-single-license details)
        success (unwrap-panic (as-max-len? (append issued-so-far success) u50))
        error issued-so-far))

;; ======================================
;; SECTION 4: PUBLIC ADMINISTRATION FUNCTIONS
;; ======================================

;; Issue a single license with metadata
(define-public (issue-license (details (string-ascii 512)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) error-permission-denied)
        (asserts! (details-validation details) error-license-details-invalid)
        (issue-single-license details)))

;; Batch license issuance with validation
(define-public (bulk-issue-licenses (detail-list (list 50 (string-ascii 512))))
    (let 
        (
            (list-size (len detail-list))
        )
        (begin
            (asserts! (is-eq tx-sender contract-owner) error-permission-denied)
            (asserts! (<= list-size batch-issuance-limit) error-batch-size-exceeded)
            (asserts! (fold validate-batch-details detail-list true) error-license-details-invalid)
            (ok (fold process-batch-item detail-list (list))))))

;; Ownership verification public function
(define-public (verify-administrator)
    (ok (is-eq tx-sender contract-owner)))

;; Terminate an active license
(define-public (terminate-license (license-id uint))
    (let 
        (
            (current-holder (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
        )
        (asserts! (is-eq tx-sender current-holder) error-permission-denied)
        (asserts! (not (license-terminated-check license-id)) error-license-terminated)
        (try! (nft-burn? license-nft license-id current-holder))
        (map-set terminated-licenses license-id true)
        (ok true)))

;; Transfer license ownership between parties
(define-public (transfer-license-ownership (license-id uint) (current-owner principal) (new-owner principal))
    (begin
        (asserts! (is-eq new-owner tx-sender) error-permission-denied)
        (asserts! (not (license-terminated-check license-id)) error-license-terminated)
        (let 
            (
                (verified-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
            )
            (asserts! (is-eq verified-owner current-owner) error-permission-denied)
            (try! (nft-transfer? license-nft license-id current-owner new-owner))
            (ok true))))

;; Update license metadata
(define-public (modify-license-details (license-id uint) (updated-details (string-ascii 512)))
    (begin
        (let 
            (
                (license-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
            )
            (asserts! (is-eq license-owner tx-sender) error-permission-denied)
            (asserts! (details-validation updated-details) error-license-details-invalid)
            (map-set license-details license-id updated-details)
            (ok true))))

;; ======================================
;; SECTION 5: LICENSE MANAGEMENT UTILITIES
;; ======================================

(define-public (increment-license-counter)
  (let
      (
          (next-id (+ (var-get license-counter) u1))
      )
      (var-set license-counter next-id)
      (ok next-id)))

(define-public (get-total-license-count)
  (ok (var-get license-counter)))


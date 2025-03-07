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

(define-public (check-license-terminated (license-id uint))
  (let
      (
          (is-terminated (map-get? terminated-licenses license-id))
      )
      (ok (default-to false is-terminated))))

(define-public (verify-license-owner (license-id uint))
  (let
      ((owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing)))
    (ok (is-eq owner tx-sender))))


(define-public (check-license-exists (license-id uint))
  (let
      (
          (exists (is-some (map-get? license-details license-id)))
      )
      (ok exists)))

(define-public (validate-details-format (details (string-ascii 512)))
  (let
      (
          (details-len (len details))
      )
      (ok (and (> details-len u0) (<= details-len u512)))))

(define-public (terminate-license-simple (license-id uint))
  (let
      (
          (is-terminated (license-terminated-check license-id))
      )
      (asserts! (not is-terminated) error-license-terminated)
      (map-set terminated-licenses license-id true)
      (ok true)))

(define-public (reactivate-license (license-id uint))
  (begin
      (asserts! (is-some (map-get? terminated-licenses license-id)) error-license-missing)
      (map-set terminated-licenses license-id false)
      (ok true)))

(define-public (is-details-valid (details (string-ascii 512)))
  (ok (and (> (len details) u0) (<= (len details) u512))))

(define-public (get-license-counter-value)
  (ok (var-get license-counter)))

(define-public (reset-all-terminated)
  (begin
    (map-set terminated-licenses u0 false)
    (ok true)))

(define-public (verify-details-exists (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-public (check-license-ownership (license-id uint))
  (let 
      ((license-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing)))
    (ok (is-eq license-owner tx-sender))))

(define-public (confirm-owner-status (license-id uint))
  (let 
      (
          (license-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
      )
      (ok (is-eq license-owner tx-sender))))

(define-public (terminate-if-active (license-id uint))
  (let
      (
          (is-terminated (license-terminated-check license-id))
      )
      (asserts! (not is-terminated) error-license-terminated)
      (map-set terminated-licenses license-id true)
      (ok true)))

(define-public (verify-administrator-role)
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-permission-denied)
    (ok true)))

(define-public (reset-license-details (license-id uint))
  (begin
    (asserts! (is-some (map-get? license-details license-id)) error-license-missing)
    (map-set license-details license-id "")
    (ok true)))

(define-public (increment-counter)
  (let 
      (
          (next-id (+ (var-get license-counter) u1))
      )
      (var-set license-counter next-id)
      (ok next-id)))

(define-public (update-details-simple (license-id uint) (new-details (string-ascii 512)))
  (begin
      (let 
          (
              (license-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
          )
          (asserts! (is-eq license-owner tx-sender) error-permission-denied)
          (asserts! (details-validation new-details) error-license-details-invalid)
          (map-set license-details license-id new-details)
          (ok true))))

(define-public (check-license-validity (license-id uint))
  (let 
      (
          (details (map-get? license-details license-id))
      )
      (begin
          (asserts! (is-some details) error-license-missing)
          (let
              (
                  (is-terminated (license-terminated-check license-id))
              )
              (ok (and (not is-terminated) (is-some details)))))))


(define-public (verify-administrator-status)
  (ok (is-eq tx-sender contract-owner)))

(define-public (is-contract-admin)
  (ok (is-eq tx-sender contract-owner)))

(define-public (check-license-status (license-id uint))
  (let
      ((terminated (map-get? terminated-licenses license-id)))
    (ok (default-to false terminated))))

(define-public (does-license-record-exist (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-public (check-owner-or-admin (license-id uint))
  (let
      ((license-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing)))
    (ok (or (is-eq tx-sender license-owner) (is-eq tx-sender contract-owner)))))

(define-public (validate-license (license-id uint))
  (let 
      (
          (details (map-get? license-details license-id))
      )
      (begin
          (asserts! (is-some details) error-license-missing)
          (let
              (
                  (is-terminated (license-terminated-check license-id))
              )
              (ok (not is-terminated))))))

(define-public (get-license-owner (license-id uint))
  (ok (nft-get-owner? license-nft license-id)))

(define-public (reset-all-details)
  (begin

      (map-set license-details u0 "")
      (ok true)))

(define-public (increment-counter-safe)
  (begin
    (var-set license-counter (+ (var-get license-counter) u1))
    (ok (var-get license-counter))))

(define-public (verify-admin-with-msg (message (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-permission-denied)
    (ok message)))

(define-public (check-if-owner (license-id uint))
  (let 
      (
          (license-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
      )
      (ok (is-eq license-owner tx-sender))))

(define-public (terminate-if-not-terminated (license-id uint))
  (let 
      (
          (is-terminated (license-terminated-check license-id))
      )
      (asserts! (not is-terminated) error-license-terminated)
      (map-set terminated-licenses license-id true)
      (ok true)))

(define-public (validate-admin)
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-permission-denied)
    (ok true)))

;; ======================================
;; SECTION 6: READ-ONLY ACCESS FUNCTIONS
;; ======================================

(define-read-only (fetch-license-details (license-id uint))
    (ok (map-get? license-details license-id)))

(define-read-only (fetch-license-owner (license-id uint))
    (ok (nft-get-owner? license-nft license-id)))

(define-read-only (get-current-owner (license-id uint))
  (ok (nft-get-owner? license-nft license-id)))

(define-read-only (validate-license-existence (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-read-only (peek-next-license-id)
  (ok (+ (var-get license-counter) u1)))

(define-read-only (get-simple-owner (license-id uint))
  (ok (nft-get-owner? license-nft license-id)))

(define-read-only (basic-details-validation (details (string-ascii 512)))
  (ok (details-validation details)))

(define-read-only (check-owner-match (license-id uint) (potential-owner principal))
  (let 
      (
          (current-owner (unwrap! (nft-get-owner? license-nft license-id) error-license-missing))
      )
      (ok (is-eq current-owner potential-owner))))

(define-read-only (validate-authenticity (license-id uint))
  (let 
      (
          (details (map-get? license-details license-id))
          (terminated (license-terminated-check license-id))
      )
      (ok (and (is-some details) (not terminated)))))



(define-read-only (get-safe-details (license-id uint))
  (map-get? license-details license-id))

(define-read-only (next-id-preview)
  (ok (+ (var-get license-counter) u1)))

(define-read-only (get-basic-details (license-id uint))
  (ok (map-get? license-details license-id)))

(define-read-only (check-simple-termination (license-id uint))
  (ok (license-terminated-check license-id)))

(define-read-only (get-basic-owner (license-id uint))
  (ok (unwrap! (nft-get-owner? license-nft license-id) error-license-missing)))

(define-read-only (get-counter-simple)
  (ok (var-get license-counter)))

(define-read-only (get-counter)
    (ok (var-get license-counter)))

(define-read-only (calculate-license-percentage (license-id uint))
  (let 
      ((total-licenses (var-get license-counter)))
    (ok (if (> total-licenses u0)
            (/ (* license-id u100) total-licenses)
            u0))))

(define-read-only (is-details-empty (license-id uint))
  (let 
      ((details (map-get? license-details license-id)))
    (ok (is-eq details (some "")))))

(define-read-only (check-validity-basic (license-id uint))
  (let 
      (
          (details (map-get? license-details license-id))
      )
      (ok (and (is-some details) (not (license-terminated-check license-id))))))

(define-read-only (check-basic-existence (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-read-only (check-terminated-basic (license-id uint))
  (ok (license-terminated-check license-id)))

(define-read-only (is-id-in-range (license-id uint))
  (ok (and (> license-id u0) (<= license-id (var-get license-counter)))))

(define-read-only (get-total-issued)
  (ok (var-get license-counter)))

(define-read-only (is-terminated-quick (license-id uint))
  (ok (default-to false (map-get? terminated-licenses license-id))))

(define-read-only (get-termination-status (license-id uint))
  (ok (license-terminated-check license-id)))

(define-read-only (is-contract-administrator)
  (ok (is-eq tx-sender contract-owner)))

(define-read-only (fetch-details-direct (license-id uint))
  (ok (map-get? license-details license-id)))

(define-read-only (is-valid-bulk-size (bulk-size uint))
  (ok (<= bulk-size batch-issuance-limit)))

(define-read-only (check-termination-status (license-id uint))
  (ok (license-terminated-check license-id)))

(define-read-only (has-details (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-read-only (get-license-state (license-id uint))
  (if (is-some (map-get? license-details license-id))
      (if (license-terminated-check license-id)
          (ok "Terminated")
          (ok "Active"))
      (ok "Not Found")))

(define-read-only (get-license-count)
  (ok (var-get license-counter)))

(define-read-only (verify-details (details (string-ascii 512)))
  (ok (details-validation details)))

(define-read-only (licenses-issued)
  (ok (var-get license-counter)))

(define-read-only (check-details-length (details (string-ascii 512)))
  (ok (and (> (len details) u0) (<= (len details) u512))))

(define-read-only (get-license-owner-info (license-id uint))
  (ok (unwrap! (nft-get-owner? license-nft license-id) error-license-missing)))

(define-read-only (is-details-blank (details (string-ascii 512)))
  (ok (is-eq details "")))

(define-read-only (is-license-usable (license-id uint))
  (let 
      (
          (exists (is-some (map-get? license-details license-id)))
          (terminated (license-terminated-check license-id))
      )
      (ok (and exists (not terminated)))))

(define-read-only (check-system-status)
  (ok true))

(define-read-only (get-error-code)
  (ok error-permission-denied))

(define-read-only (admin-check)
  (ok (is-eq tx-sender contract-owner)))

(define-read-only (admin-active-status)
  (ok true))

(define-read-only (license-total-simple)
  (ok (var-get license-counter)))

(define-read-only (quick-details-check (details (string-ascii 512)))
  (ok (> (len details) u0)))


(define-read-only (get-complete-license-info (license-id uint))
  (let 
      (
          (details (map-get? license-details license-id))
          (owner (nft-get-owner? license-nft license-id))
          (terminated (license-terminated-check license-id))
      )
      (ok {
          details: details,
          owner: owner,
          is-terminated: terminated
      })))


(define-read-only (quick-existence-check (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-read-only (get-max-details-length)
  (ok u512))

(define-read-only (get-license-block)
  (ok (var-get license-counter)))

(define-read-only (basic-license-validation (license-id uint))
  (ok (and 
    (> license-id u0) 
    (<= license-id (var-get license-counter)))))

(define-read-only (check-details-existence (license-id uint))
  (ok (is-some (map-get? license-details license-id))))

(define-read-only (is-license-current (license-id uint))
  (let 
      ((current-count (var-get license-counter)))
    (ok (and 
      (> license-id u0) 
      (<= license-id current-count)))))



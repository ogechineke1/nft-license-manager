# NFT License Manager

## Overview

NFT License Manager is a smart contract that enables the issuance, tracking, transfer, and revocation of digital asset licenses using non-fungible tokens (NFTs). This contract is designed to help content creators manage their licensing processes securely and efficiently.

## Features

- **NFT-Based Licensing**: Each license is represented as an NFT with rich metadata.
- **Single & Batch Issuance**: Issue individual or multiple licenses in a single transaction.
- **Ownership Verification**: Check the ownership of a license at any time.
- **License Transfer**: Securely transfer ownership between parties.
- **License Revocation**: Terminate licenses when necessary.
- **Lifecycle Management**: Track issued, active, and revoked licenses.

## Installation & Deployment

1. Clone the repository:
   ```sh
   git clone https://github.com/yourusername/nft-license-manager.git
   ```
2. Navigate into the directory:
   ```sh
   cd nft-license-manager
   ```
3. Deploy the contract using your preferred blockchain environment (e.g., Clarity for Stacks blockchain).

## Usage

### Issuing a License
Call the `issue-license` function with the license details:
```lisp
(define-public (issue-license (details (string-ascii 512))))
```

### Transferring Ownership
To transfer a license from one owner to another:
```lisp
(define-public (transfer-license-ownership (license-id uint) (current-owner principal) (new-owner principal)))
```

### Revoking a License
To revoke (terminate) an existing license:
```lisp
(define-public (terminate-license (license-id uint)))
```

### Checking License Status
To check if a license exists and its current status:
```lisp
(define-read-only (get-license-state (license-id uint)))
```

## Error Codes

| Code  | Meaning                      |
|-------|------------------------------|
| `200` | Permission denied            |
| `201` | Duplicate license detected   |
| `202` | License not found            |
| `203` | Invalid license ID           |
| `204` | Invalid license details      |
| `205` | License already terminated   |
| `206` | Batch size exceeded          |
| `207` | Empty license details        |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Submit a pull request for review.

## Contact

For inquiries or support, please reach out via GitHub Issues.

# Local provider-document services

This development-only stack runs private SeaweedFS object storage and ClamAV. It is not approved for real KYC data or production use.

1. Copy `.env.example` to an untracked `.env` and replace the local object-storage secret.
2. Ensure Docker has at least 4 GB of memory available for ClamAV.
3. Start the services from the repository root:

   ```powershell
   docker compose --env-file .env -f infrastructure/local/provider-documents.compose.yml up -d
   ```

4. Stop them without deleting stored development objects:

   ```powershell
   docker compose --env-file .env -f infrastructure/local/provider-documents.compose.yml down
   ```

To delete the local volume, obtain explicit approval and use the documented Docker volume workflow. Never place real identity documents in this stack.

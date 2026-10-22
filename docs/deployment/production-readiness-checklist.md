# FixNow — Production Deployment & External Integration Readiness Checklist

**Document Version:** 1.0.0  
**Status:** Authoritative Operational Guide  
**Reference Reconciliation:** [FIXNOW_REMEDIATION_STATUS.md](../../audit_reports/FIXNOW_REMEDIATION_STATUS.md)  
**Task Anchor:** Post-FN-146 Production Operational Boundary  

---

## 1. Executive Summary & Purpose

The FixNow codebase has completed local code remediation and validation under **FN-146** across backend, admin web, and mobile Flutter clients. All code-actionable findings, authorization guards, concurrency protections, schema integrity probes, and honest client UI fallbacks are implemented and covered by local tests.

However, **local passing tests do not establish production readiness**. Critical statutory, cloud provider, network, and business operational gates remain external boundaries that cannot be mocked or faked in a live production environment. 

This document defines the authoritative, step-by-step checklist and operational runbook required before deploying FixNow to staging and production infrastructure.

---

## 2. Checklist Matrix Overview

| Area | Component / Boundary | Requirement | Verification Gate |
|---|---|---|---|
| **Database** | PostgreSQL Migrations | Forward migration `1789750600000-RemainingDomainForeignKeys.ts` with `NOT VALID` FKs | Pre-migration orphan check + schema verify |
| **Storage** | AWS S3 / Private Storage | Provision private S3 bucket for documents & job proofs | S3 head-bucket + TLS presign stream |
| **Malware** | ClamAV Daemon | Running antivirus daemon for uploaded provider docs & photos | TCP ping + EICAR test stream probe |
| **Push** | Firebase Cloud Messaging | Production service account JSON + FCM provider setup | Device push token registration & receipt |
| **Payments** | Gateway (Razorpay) | Production API keys, webhook secret, TLS endpoint | Webhook signature verification + live order test |
| **Tax / Legal** | GSTIN & Invoice Config | Statutory registered entity details compiled into Mobile | Regex match `^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$` |
| **Hardware** | Mobile Device Verification | Real iOS and Android physical devices | Dialer fallback + push wakeup from sleep |
| **Policy** | Provider Reverification | Legal/Product determination of 365-day reverification | Signed policy approval record |
| **AI Governance** | ADR-0014 Release Gate | Signed DPA, vendor terms, EXIF sanitizer, HF token | Disabled by default until explicit release gate |

---

## 3. Phase 1: Database Migration & Schema Integrity

### 3.1 Pre-Migration Orphan Data Inspection
Before applying migration `1789750600000-RemainingDomainForeignKeys.ts` to an active production database, execute orphan validation queries. Because the migration enforces strict foreign keys across domain tables, pre-existing orphan records will cause constraint validation to fail.

Execute the following read-only queries against PostgreSQL:

```sql
-- 1. Check for orphaned guarantee claims without valid bookings
SELECT id, booking_id, customer_id 
FROM guarantee_claims 
WHERE booking_id NOT IN (SELECT id FROM bookings);

-- 2. Check for orphaned review photos without valid reviews
SELECT id, review_id 
FROM review_photos 
WHERE review_id NOT IN (SELECT id FROM booking_reviews);

-- 3. Check for orphaned job proof photos without valid bookings
SELECT id, booking_id, uploader_id 
FROM job_proof_photos 
WHERE booking_id NOT IN (SELECT id FROM bookings) 
   OR uploader_id NOT IN (SELECT id FROM users);

-- 4. Check for orphaned complaints
SELECT id, booking_id, complainant_id 
FROM complaints 
WHERE (booking_id IS NOT NULL AND booking_id NOT IN (SELECT id FROM bookings))
   OR complainant_id NOT IN (SELECT id FROM users);
```

> [!IMPORTANT]
> If any query returns rows, resolve or purge those orphan records in a database maintenance transaction **prior** to running migrations.

### 3.2 Applying Forward Migrations
FixNow database migrations must be applied using TypeORM CLI:

```bash
# Verify pending migrations without executing
npm --prefix backend run migration:show

# Execute migrations inside deployment transaction
npm --prefix backend run migration:run
```

The migration `1789750600000-RemainingDomainForeignKeys.ts` adds foreign keys using `ADD CONSTRAINT ... NOT VALID` to avoid prolonged table locks on high-volume tables. After deployment and transaction commit, validate each constraint asynchronously during an off-peak maintenance window:

```sql
ALTER TABLE guarantee_claims VALIDATE CONSTRAINT FK_guarantee_claims_booking;
ALTER TABLE review_photos VALIDATE CONSTRAINT FK_review_photos_review;
ALTER TABLE complaints VALIDATE CONSTRAINT FK_complaints_booking;
```

---

## 4. Phase 2: Live External Cloud Services & Infrastructure

### 4.1 Firebase Cloud Messaging (FCM)
The backend push notification engine (`backend/src/notifications/`) uses `PUSH_PROVIDER=fcm` in production.

1. **Service Account Provisioning**:
   - Access Google Firebase Console > Project Settings > Service Accounts.
   - Generate a new private key JSON.
   - Securely transfer the file to the backend host (e.g., `/etc/fixnow/secrets/firebase-service-account.json`).
   - Restrict file permissions: `chmod 400 /etc/fixnow/secrets/firebase-service-account.json`.

2. **Environment Configuration**:
   ```ini
   PUSH_PROVIDER=fcm
   FCM_CREDENTIALS_FILE=/etc/fixnow/secrets/firebase-service-account.json
   NOTIFICATION_QUIET_HOURS_UTC=22-06
   NOTIFICATION_REMINDER_LEAD_MINUTES=60
   ```

3. **Production Validation**:
   - Register a device token from a physical device via `POST /notifications/push-token`.
   - Verify that test dispatch reaches the APNs/FCM transport and receives an HTTP 200 message ID.
   - Confirm invalid tokens return `NOT_REGISTERED` and are pruned from the database.

### 4.2 S3-Compatible Private Object Storage
Provider KYC identity documents and Before/After job proof photos are stored privately in S3 (never public buckets).

1. **Bucket Configuration**:
   - Create private bucket: `fixnow-provider-documents-prod`.
   - Enable S3 Default Encryption (AES-256 / SSE-S3 or KMS).
   - Block all public access (BlockPublicAcls, IgnorePublicAcls, BlockPublicPolicy, RestrictPublicBuckets = True).
   - Configure Lifecycle Rule: expire unverified temporary documents after 30 days (`PROVIDER_DOCUMENT_RETENTION_DAYS=30`).

2. **Backend IAM / Credentials**:
   ```ini
   PROVIDER_DOCUMENT_S3_ENDPOINT=https://s3.ap-south-1.amazonaws.com
   PROVIDER_DOCUMENT_S3_REGION=ap-south-1
   PROVIDER_DOCUMENT_S3_ACCESS_KEY=<AWS_ACCESS_KEY_ID>
   PROVIDER_DOCUMENT_S3_SECRET_KEY=<AWS_SECRET_ACCESS_KEY>
   PROVIDER_DOCUMENT_BUCKET=fixnow-provider-documents-prod
   PROVIDER_DOCUMENT_RETENTION_DAYS=30
   ```

3. **Validation**:
   - Upload a test provider document via `POST /provider/documents`.
   - Verify bytes are received, verified for magic bytes, and written to S3.
   - Confirm `GET /provider/documents/:id/content` streams bytes with `Content-Type: application/pdf`, `X-Content-Type-Options: nosniff`, and `Cache-Control: no-store`.

### 4.3 ClamAV Antivirus Daemon
All uploaded files (KYC documents, before/after proof photos, review photos) must pass a malware scan before database row creation.

1. **Daemon Provisioning**:
   - Deploy ClamAV daemon container with active daily `freshclam` signature sync.
   - Expose TCP port (default `3310`) accessible only within the internal VPC.

2. **Configuration**:
   ```ini
   CLAMAV_HOST=clamav-internal.vpc.local
   CLAMAV_PORT=3310
   ```

3. **Validation**:
   - Verify connection health check passes on backend startup.
   - Attempt upload of the harmless EICAR standard antivirus test string:
     ```text
     X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
     ```
   - Verify the request is immediately rejected with HTTP 400 `MALWARE_DETECTED` and no file is stored in S3.

### 4.4 Payment Gateway (Razorpay)
In production, `PAYMENT_PROVIDER=fake` is prohibited by `env.validation.ts` and will prevent backend startup.

1. **Configuration**:
   ```ini
   PAYMENT_PROVIDER=razorpay
   RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxxx
   RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
   RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
   ```

2. **Webhook Endpoint Setup**:
   - In Razorpay Dashboard > Settings > Webhooks, add:
     `https://api.fixnow.app/payments/webhook`
   - Active events: `payment.captured`, `payment.failed`, `refund.processed`.
   - Set Secret matching `RAZORPAY_WEBHOOK_SECRET`.

3. **Validation**:
   - Initiate a test transaction in staging mode.
   - Verify webhook receives raw buffer payload and validates HMAC-SHA256 signature.
   - Verify payment transitions atomically to `PAID` and triggers invoice generation.

---

## 5. Phase 3: Statutory Tax & Entity Configuration

Per statutory requirements in India, issuing a "Tax Invoice" without a valid Goods and Services Tax Identification Number (GSTIN) and registered entity identity carries legal penalties. 

FixNow code implements an **honest fallback**: if any tax parameter is missing or invalid, the app renders a **"Payment Receipt"** instead of an illegal "Tax Invoice".

### 5.1 Mobile Compilation Environment Defines
When building the Flutter release bundle (APK / AAB / IPA), pass the real corporate details:

```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=COMPANY_NAME="FixNow Technologies Private Limited" \
  --dart-define=COMPANY_GSTIN="29AAAAA0000A1Z5" \
  --dart-define=COMPANY_SAC="9987" \
  --dart-define=COMPANY_ADDRESS="Floor 4, Tech Park, Outer Ring Road, Bengaluru 560103" \
  --dart-define=SUPPORT_EMAIL="support@fixnow.app" \
  --dart-define=INVOICE_VERIFY_URL="https://fixnow.app/verify-invoice" \
  --dart-define=EMERGENCY_HOTLINE="+918000000000"
```

### 5.2 Verification Rule
The client checks:
```dart
RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$').hasMatch(companyGstin) &&
companyName.trim().isNotEmpty &&
companyAddress.trim().isNotEmpty &&
companySac.trim().isNotEmpty
```
Ensure the build pipeline tests this validation before releasing the mobile artifact to the Google Play Store or Apple App Store.

---

## 6. Phase 4: Physical Device & Operating System Verification

Automated integration tests and crawler tests verify widget trees and stub protocols. Physical hardware validation is mandatory for the following workflows:

1. **Native Phone Calling Fallback**:
   - Supported call buttons in the customer and provider apps invoke `url_launcher` with authorized `tel:<phoneNumber>`.
   - Test on physical Android (Samsung/Pixel) and physical iOS device:
     - Verify device phone dialer opens with number pre-filled.
     - Verify cancellation/return to app restores clean state without freezing.
   - *Note:* In-app WebRTC VoIP audio streaming is a future roadmap item; current production behavior is explicitly dialer fallback.

2. **Push Wakeup & Background Handlers**:
   - Send background booking dispatch push while mobile app is terminated.
   - Verify system tray heads-up alert displays with sound and vibration.
   - Tapping notification launches app directly into the corresponding Booking Tracking screen.

3. **Location Services & GPS Accuracy**:
   - Verify background location prompt complies with Apple App Store / Google Play background location disclosure policies.
   - Test provider moving state: verify `PUT /provider-profile/me/location` throttles updates per `PROVIDER_LOCATION_THROTTLE_LIMIT=60/min` and handles transient network loss cleanly.

---

## 7. Phase 5: Business Decisions & Legal Policy Ratification

Before production launch, product leadership and legal counsel must sign off on the following operational rules:

1. **365-Day Provider Reverification Policy**:
   - *Current State:* No automatic background cron suspension of providers after 365 days is implemented, to avoid unintended mass deactivations without verified business procedures.
   - *Decision Needed:* Establish whether provider background checks require annual re-upload, manual admin review, or automated renewal reminders.

2. **Cancellation Fee & Refund Schedules**:
   - The UI currently displays truthful, non-fabricated fee terms.
   - Legal counsel must review the customer cancellation terms in `terms_of_service.md` to ensure payment gateway dispute timeframes align with internal customer support capacity.

3. **Governed Multimodal AI Activation (ADR-0014 Gate)**:
   - AI features (`AI_ENABLED`, `AI_VOICE_ENABLED`, `AI_VISION_ENABLED`) default to `false`.
   - Before setting `AI_PROVIDER=huggingface`:
     - Verify Data Processing Agreement (DPA) is signed with AI model host.
     - Confirm EXIF/metadata sanitizer (`stripImageMetadata`) is enabled.
     - Ratify that all AI outputs remain strictly advisory and cannot bind customer pricing without human confirmation.

---

## 8. Phase 6: Pre-Deployment Runbook

Before deploying changes to live production containers:

```bash
# 1. Run environment variable validation script
npm --prefix backend run deploy:verify-env

# 2. Verify all DTO body validation schemas
npm --prefix backend run check:body-dtos

# 3. Verify backend and admin production builds
npm --prefix backend run build
npm --prefix admin run build

# 4. Verify clean linting across monorepo
npm --prefix backend run lint
npm --prefix admin run lint
cd mobile && flutter analyze

# 5. Run full test suites
npm --prefix backend test
npm --prefix admin test
cd mobile && flutter test

# 6. Check git diff for whitespace or conflict markers
git diff --check
```

---

## 9. Sign-Off Record

| Role | Name | Signature / Approval ID | Date |
|---|---|---|---|
| Lead Platform Engineer | | | |
| Security & Compliance Officer | | | |
| Mobile Release Engineer | | | |
| Product Operations Lead | | | |

*This document must be signed and archived in release records alongside each production deployment tag.*

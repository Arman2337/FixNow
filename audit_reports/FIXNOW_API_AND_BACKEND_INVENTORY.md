# FixNow — Complete API and Backend Capabilities Inventory

**Audit Date:** 2026-10-13  
**Audit Scope:** Full Backend Inspection (`backend/src/`, `backend/migrations/`, `shared/`)  
**Commit Baseline:** `d9951c4` + Phase 1 Non-Destructive Seed & Secret Scanner Remediation  
**Scale:** 41 Controllers, 119+ Route Handlers, 1 WebSocket Gateway (`/realtime`), 1 Transactional Outbox Engine, 45 Entities, 39 Migrations  

---

## 1. Global Infrastructure & Cross-Cutting Architecture

| Pipeline Component | Configuration / Implementation | Source Location | Security & Operational Behavior |
|---|---|---|---|
| **Global Route Prefix** | `/api/v1` | `main.ts:31` | Enforced globally on all HTTP controllers. Note: `/realtime` runs outside this prefix on native WS. |
| **Global Validation Pipe** | `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })` | `main.ts:32-38` | Strips undeclared properties, rejects non-whitelisted payloads with 400 Bad Request, auto-coerces primitive query/param types. |
| **Deny-by-Default Auth Guard** | `AuthorizationGuard` | `auth/auth.module.ts:45` | Global guard requiring valid Bearer JWT unless explicitly annotated with `@Public()`. Evaluates 11 staff/user roles and ~70 granular permissions. |
| **Resource Ownership Interceptor** | `OwnershipProofInterceptor` | `auth/auth.module.ts:47` | Executes post-handler; enforces that any accessed entity matches the principal or is explicitly granted via staff role. Fails closed with 403 Forbidden. |
| **Global Throttling** | `ThrottlerModule.forRoot([{ ttl: 60000, limit: 60 }])` | `app.module.ts:43` | Global rate limit of 60 requests per minute per IP. Critical endpoints override this with per-route `@Throttle` annotations. |
| **Exception Filter** | `AllExceptionsFilter` | `app.module.ts:67-70` | Catches all unhandled exceptions; standardizes error JSON (`{ statusCode, timestamp, path, message }`); suppresses stack traces in non-dev environments. |
| **Raw Body Capture** | `rawBody: true` | `main.ts:27` | Preserves raw payload buffers required for cryptographic HMAC-SHA256 signature verification (used in payment webhooks). |
| **WebSocket Gateway Adapter** | `WsAdapter` (`ws` engine) | `main.ts:30` | High-performance raw WebSocket server; perMessageDeflate disabled to prevent ZipBomb vulnerabilities; 16 KiB payload cap. |
| **Graceful Shutdown** | `enableShutdownHooks` + `runGracefulShutdown` | `main.ts:116-122` | Catches `SIGTERM`/`SIGINT`; stops outbox polling; drains active in-flight requests; closes DB connection pools. |
| **OpenAPI / Swagger** | `/api/docs` | `main.ts:97-102` | Generates schema documentation; strips `/api/v1` prefix internally so interactive UI maps cleanly. |

---

## 2. Exhaustive Controller & Endpoint Inventory

### 2.1 Identity, Authentication & Session Lifecycle

#### `AppController` (`app.controller.ts`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-APP-001` | GET | `/api/v1` | `AppController.getHello()` | `@Public()` | None | None | None | Global 60/min | `IMPLEMENTED_EVIDENCED` | `app.controller.ts:10`, `app.controller.spec.ts` |

#### `AuthController` (`auth/auth.controller.ts`, `@Controller('auth/customer')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AUT-001` | POST | `/api/v1/auth/customer/register` | `AuthController.register()` | `@Public()` | `EmailPasswordDto`: `email` (<=254, email format), `password` (12-128 chars) | Reads `users`, inserts `users` (`pending_verification`), `auth_credentials` (Argon2id), `roles` (`customer`) | Generates email OTP challenge; writes audit event | `@Throttle({ default: { limit: 3, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `auth.controller.ts:28`, `auth.service.spec.ts` |
| `API-AUT-002` | POST | `/api/v1/auth/customer/login` | `AuthController.login()` | `@Public()` | `EmailPasswordDto`: `email`, `password` | Reads `users`, `auth_credentials`; verifies Argon2id hash; inserts `auth_sessions` | Logs audit event; returns JWT access + refresh tokens | `@Throttle({ default: { limit: 5, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `auth.controller.ts:40`, `auth.service.spec.ts` |
| `API-AUT-003` | POST | `/api/v1/auth/customer/password-reset/request` | `AuthController.requestPasswordReset()` | `@Public()` | `PasswordResetRequestDto`: `email` | Reads `users`; writes `password_reset_tokens` (64-char crypto token) | Sends password reset email; anti-enumeration: always returns 202 `{ status: 'accepted' }` | `@Throttle({ default: { limit: 3, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `auth.controller.ts:52`, `auth.service.spec.ts` |
| `API-AUT-004` | POST | `/api/v1/auth/customer/password-reset/confirm` | `AuthController.confirmPasswordReset()` | `@Public()` | `PasswordResetConfirmDto`: `token` (64 chars), `newPassword` (12-128 chars) | Reads/invalidates `password_reset_tokens`; updates `auth_credentials` | Revokes existing `auth_sessions`; audit log | `@Throttle({ default: { limit: 5, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `auth.controller.ts:64`, `auth.service.spec.ts` |

#### `ProviderRegistrationController` (`providers/provider-registration.controller.ts`, `@Controller('auth/provider')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AUT-005` | POST | `/api/v1/auth/provider/register` | `ProviderRegistrationController.register()` | `@Public()` | `EmailPasswordDto`: `email`, `password` | Inserts `users` (`pending_verification`), `roles` (`provider_applicant`), `provider_applications` (`unverified`) | Enqueues OTP challenge; audit event | `@Throttle({ default: { limit: 3, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `provider-registration.controller.ts:25`, `auth.service.spec.ts` |
| `API-AUT-006` | POST | `/api/v1/auth/provider/login` | `ProviderRegistrationController.login()` | `@Public()` | `EmailPasswordDto`: `email`, `password` | Reads `users`, verifies hash; creates `auth_sessions` | Emits auth audit event; returns session tokens | `@Throttle({ default: { limit: 5, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `provider-registration.controller.ts:37`, `auth.service.spec.ts` |

#### `AdminAuthController` (`auth/admin-auth.controller.ts`, `@Controller('auth/admin')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AUT-007` | POST | `/api/v1/auth/admin/login` | `AdminAuthController.login()` | `@Public()` | `EmailPasswordDto`: `email`, `password` | Reads `users`, `user_roles`; enforces user has exactly one staff role | Writes session tokens; logs admin audit event | `@Throttle({ default: { limit: 5, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `admin-auth.controller.ts:22`, `auth.service.spec.ts` |
| `API-AUT-008` | GET | `/api/v1/auth/admin/session` | `AdminAuthController.getSession()` | `adminSessionReadSelf` | None | Reads active session & user staff roles | Returns `{ userId, roles }` (omits name/email) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-auth.controller.ts:34`, `admin-auth.controller.spec.ts` |

#### `TokenLifecycleController` (`auth/token-lifecycle.controller.ts`, `@Controller('auth')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AUT-009` | POST | `/api/v1/auth/otp/request` | `TokenLifecycleController.requestOtp()` | `@Public()` | `OtpRequestDto`: `email`, `purpose` (`REGISTRATION`, `PASSWORD_RESET`, `LOGIN`) | Checks 60-second cooldown in `otp_challenges`; inserts new challenge | Sends email OTP; returns 202 Accepted | `@Throttle({ default: { limit: 3, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `token-lifecycle.controller.ts:26`, `token-lifecycle.controller.spec.ts` |
| `API-AUT-010` | POST | `/api/v1/auth/otp/verify` | `TokenLifecycleController.verifyOtp()` | `@Public()` | `OtpVerifyDto`: `email`, `code` (6 digits), `purpose` | Validates hash, expiry, retry count; updates user from `pending_verification` to `active` | Invalidates challenge; returns 204 No Content | `@Throttle({ default: { limit: 5, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `token-lifecycle.controller.ts:38`, `token-lifecycle.controller.spec.ts` |
| `API-AUT-011` | POST | `/api/v1/auth/token/refresh` | `TokenLifecycleController.refreshToken()` | `@Public()` | `RefreshTokenDto`: `refreshToken` (UUID / 64-char) | Reads `auth_sessions`; validates token family; revokes on reuse; issues new key | Token family replay guard revokes all sessions | `@Throttle({ default: { limit: 30, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `token-lifecycle.controller.ts:50`, `token-lifecycle.controller.spec.ts` |
| `API-AUT-012` | POST | `/api/v1/auth/logout` | `TokenLifecycleController.logout()` | Bearer Auth | `LogoutDto`: `refreshToken` | Deletes/revokes current session in `auth_sessions` | Returns 204 No Content | `@Throttle({ default: { limit: 60, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `token-lifecycle.controller.ts:62`, `token-lifecycle.controller.spec.ts` |
| `API-AUT-013` | POST | `/api/v1/auth/logout-all` | `TokenLifecycleController.logoutAll()` | Bearer Auth | None | Deletes all active sessions for principal | Revokes all devices; returns 204 No Content | `@Throttle({ default: { limit: 10, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `token-lifecycle.controller.ts:74`, `token-lifecycle.controller.spec.ts` |

---

### 2.2 Users & Customer Addresses

#### `CustomerProfileController` (`users/customer-profile.controller.ts`, `@Controller('users/me/profile')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-USR-001` | GET | `/api/v1/users/me/profile` | `CustomerProfileController.getProfile()` | `profileReadSelf` | None | Reads `customer_profiles`, `users` | Returns `{ displayName, phoneNumber }` (minimal PII) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `customer-profile.controller.ts:20`, `users.service.spec.ts` |
| `API-USR-002` | PATCH | `/api/v1/users/me/profile` | `CustomerProfileController.updateProfile()` | `profileUpdateSelf` | `UpdateCustomerProfileDto`: `displayName` (1-80 chars, no control characters) | Updates `customer_profiles` | Writes profile audit event | Global 60/min | `IMPLEMENTED_EVIDENCED` | `customer-profile.controller.ts:32`, `users.service.spec.ts` |

#### `CustomerAddressesController` (`users/customer-addresses.controller.ts`, `@Controller('users/me/addresses')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-ADR-001` | GET | `/api/v1/users/me/addresses` | `CustomerAddressesController.listAddresses()` | `profileReadSelf` | None | Reads `customer_addresses` where `user_id = principal` | Returns array sorted by `is_default DESC, created_at DESC` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `customer-addresses.controller.ts:24`, `customer-addresses.controller.spec.ts` |
| `API-ADR-002` | POST | `/api/v1/users/me/addresses` | `CustomerAddressesController.createAddress()` | `profileUpdateSelf` | `CreateAddressDto`: `label` (1-50), `addressLine1` (1-200), `city` (1-50), `postalCode` (pin regex), `latitude` (`@IsLatitude`), `longitude` (`@IsLongitude`), `isDefault` | If `isDefault`, unsets previous defaults; inserts into `customer_addresses` | Audit log | Global 60/min | `IMPLEMENTED_EVIDENCED` | `customer-addresses.controller.ts:36`, `customer-addresses.controller.spec.ts` |
| `API-ADR-003` | DELETE | `/api/v1/users/me/addresses/:id` | `CustomerAddressesController.deleteAddress()` | `profileUpdateSelf` | Param `id` (UUIDv4) | Deletes from `customer_addresses` with `user_id = principal`; 404 if not found | None | Global 60/min | `IMPLEMENTED_EVIDENCED` | `customer-addresses.controller.ts:48`, `customer-addresses.controller.spec.ts` |

---

### 2.3 Service Catalog & Sub-Services

#### `ServiceCategoriesController` (`services/service-categories.controller.ts`, `@Controller('service-categories')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-CAT-001` | GET | `/api/v1/service-categories` | `ServiceCategoriesController.findAll()` | `@Public()` | Query: `isActive` (bool), `isEmergency` (bool), `limit` (int <= 200) | Reads `service_categories` with active filtering | Cached in Redis (TTL 300s) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `service-categories.controller.ts:24`, `service-categories.service.spec.ts` |
| `API-CAT-002` | GET | `/api/v1/service-categories/active` | `ServiceCategoriesController.findActive()` | `@Public()` | None | Reads `service_categories WHERE is_active = true ORDER BY display_order ASC` | Redis cache | Global 60/min | `IMPLEMENTED_EVIDENCED` | `service-categories.controller.ts:36`, `service-categories.service.spec.ts` |
| `API-CAT-003` | GET | `/api/v1/service-categories/emergency` | `ServiceCategoriesController.findEmergency()` | `@Public()` | None | Reads `service_categories WHERE is_active = true AND is_emergency = true` | Redis cache | Global 60/min | `IMPLEMENTED_EVIDENCED` | `service-categories.controller.ts:48`, `service-categories.service.spec.ts` |
| `API-CAT-004` | GET | `/api/v1/service-categories/:id` | `ServiceCategoriesController.findById()` | `@Public()` | Param `id` (UUIDv4) | Reads `service_categories` by ID | 404 if missing | Global 60/min | `IMPLEMENTED_EVIDENCED` | `service-categories.controller.ts:60`, `service-categories.service.spec.ts` |
| `API-CAT-005` | GET | `/api/v1/service-categories/slug/:slug` | `ServiceCategoriesController.findBySlug()` | `@Public()` | Param `slug` (string) | Reads `service_categories` by slug | 404 if missing | Global 60/min | `IMPLEMENTED_EVIDENCED` | `service-categories.controller.ts:72`, `service-categories.service.spec.ts` |

#### `SubServicesController` (`services/sub-services.controller.ts`, `@Controller('sub-services')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-SUB-001` | GET | `/api/v1/sub-services` | `SubServicesController.findAll()` | `@Public()` | Query `categoryId` (UUIDv4 or slug string) | Resolves category; reads `sub_services WHERE category_id = :id AND is_active = true` | 400 if invalid categoryId | Global 60/min | `IMPLEMENTED_EVIDENCED` | `sub-services.controller.ts:25`, `catalog-seed.spec.ts` |
| `API-SUB-002` | GET | `/api/v1/sub-services/:id` | `SubServicesController.findById()` | `@Public()` | Param `id` (UUIDv4 via `ParseUUIDPipe`) | Reads single row from `sub_services` | 404 if not found | Global 60/min | `IMPLEMENTED_EVIDENCED` | `sub-services.controller.ts:38`, `catalog-seed.spec.ts` |

---

### 2.4 Provider Applications, Skills, Availability & KYC

#### `ProviderApplicationController` (`providers/provider-application.controller.ts`, `@Controller('provider-applications')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRO-001` | GET | `/api/v1/provider-applications/me` | `ProviderApplicationController.getMyApplication()` | `providerApplicationReadSelf` | None | Reads `provider_applications` where `user_id = principal` | 404 if no application started | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-application.controller.ts:22`, `provider-application.service.spec.ts` |
| `API-PRO-002` | POST | `/api/v1/provider-applications/me/submit` | `ProviderApplicationController.submitApplication()` | `providerApplicationUpdateSelf` | None | Transactional update: validates state is `unverified` or `resubmission_requested`; transitions to `under_review` | Increments manual `version`; enqueues `provider.application.submitted` outbox event | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-application.controller.ts:34`, `provider-application.service.spec.ts` |

#### `ProviderProfileController` (`providers/provider-profile.controller.ts`, `@Controller('provider-profile')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRO-003` | GET | `/api/v1/provider-profile/me` | `ProviderProfileController.getProfile()` | `provider.profile.read` | None | Reads `provider_profiles` join `users` | 404 if profile uninitialized | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-profile.controller.ts:25`, `provider-profile.service.spec.ts` |
| `API-PRO-004` | PUT | `/api/v1/provider-profile/me` | `ProviderProfileController.updateProfile()` | `provider.profile.update` | `UpdateProviderProfileDto`: `serviceRadiusKm` (1-100), `bio` (<=500) | Updates `provider_profiles` | Writes audit event | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-profile.controller.ts:37`, `provider-profile.service.spec.ts` |
| `API-PRO-005` | PUT | `/api/v1/provider-profile/me/location` | `ProviderProfileController.updateLocation()` | `provider.profile.update` | `UpdateLocationDto`: `latitude` (`@IsLatitude`), `longitude` (`@IsLongitude`) | Updates `provider_profiles.last_known_location` | Emits WS `location-update` to subscribed customers | `@ConfigurableThrottle` (default 60/min) | `IMPLEMENTED_EVIDENCED` | `provider-profile.controller.ts:49`, `location.service.spec.ts` |
| `API-PRO-006` | PUT | `/api/v1/provider-profile/me/coverage-check` | `ProviderProfileController.coverageCheck()` | `provider.profile.read` | `CoverageCheckDto`: `targetLat`, `targetLng` | Calculates haversine distance against provider base coordinates and radius | Returns `{ isCovered, distanceKm }` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-profile.controller.ts:61`, `location.service.spec.ts` |

#### `ProviderSkillsController` (`providers/provider-skills.controller.ts`, `@Controller('provider-skills')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRO-007` | GET | `/api/v1/provider-skills/me` | `ProviderSkillsController.getMySkills()` | `provider.skills.read` | None | Reads `provider_skills` for principal | Returns skill list with verification status | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:24`, `provider-skills.service.spec.ts` |
| `API-PRO-008` | GET | `/api/v1/provider-skills/me/count` | `ProviderSkillsController.getMySkillsCount()` | `provider.skills.read` | None | Counts rows in `provider_skills` for principal | Returns `{ count }` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:35`, `provider-skills.service.spec.ts` |
| `API-PRO-009` | GET | `/api/v1/provider-skills/user/:userId` | `ProviderSkillsController.getUserSkills()` | `provider.skills.read.any` | Param `userId` (UUIDv4) | Reads `provider_skills` for given user | 403 unless staff reviewer | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:46`, `provider-skills.service.spec.ts` |
| `API-PRO-010` | GET | `/api/v1/provider-skills/category/:serviceCategoryId` | `ProviderSkillsController.getByCategory()` | `@Public()` | Param `serviceCategoryId` (UUIDv4) | Reads active skills for category | Public discovery metadata | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:57`, `provider-skills.service.spec.ts` |
| `API-PRO-011` | POST | `/api/v1/provider-skills` | `ProviderSkillsController.createSkill()` | `provider.skills.create` | `CreateProviderSkillDto`: `serviceCategoryId`, `yearsOfExperience` (0-50) | Inserts `provider_skills` (`is_verified = false`) | Non-admin cannot set verification flags | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:68`, `provider-skills.service.spec.ts` |
| `API-PRO-012` | PUT | `/api/v1/provider-skills/:id` | `ProviderSkillsController.updateSkill()` | `provider.skills.update` | `UpdateProviderSkillDto`: `yearsOfExperience` | Updates `provider_skills` where `provider_id = principal` | Resets `is_verified` if category changed | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:80`, `provider-skills.service.spec.ts` |
| `API-PRO-013` | PUT | `/api/v1/provider-skills/:id/verify` | `ProviderSkillsController.verifySkill()` | `admin.skills.verify` | `VerifySkillDto`: `isVerified` (bool), `notes` (string) | Updates `is_verified`, `verification_notes` | Staff only; emits audit event | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:92`, `provider-skills.service.spec.ts` |
| `API-PRO-014` | DELETE | `/api/v1/provider-skills/:id` | `ProviderSkillsController.deleteSkill()` | `provider.skills.delete` | Param `id` (UUIDv4) | Deletes from `provider_skills` for principal | 204 No Content | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-skills.controller.ts:104`, `provider-skills.service.spec.ts` |

#### `ProviderAvailabilityController` (`providers/availability/provider-availability.controller.ts`, `@Controller('provider-availability')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRO-015` | GET | `/api/v1/provider-availability/me` | `ProviderAvailabilityController.getMyAvailability()` | `provider.availability.read` | None | Reads `provider_availability` for principal | Returns schedule rules, exceptions, status, version | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-availability.controller.ts:25`, `provider-availability.service.spec.ts` |
| `API-PRO-016` | PUT | `/api/v1/provider-availability/me/schedule` | `ProviderAvailabilityController.updateSchedule()` | `provider.availability.update` | `UpdateScheduleDto`: `timezone` (valid IANA), `weeklyRules` (max 7), `dateExceptions` (max 90), `expectedVersion` | Updates rules; checks `version = expectedVersion`; increments version | 409 Conflict if version mismatch | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `provider-availability.controller.ts:37`, `provider-availability.service.spec.ts` |
| `API-PRO-017` | PUT | `/api/v1/provider-availability/me/status` | `ProviderAvailabilityController.updateStatus()` | `provider.availability.update` | `UpdateStatusDto`: `status` (`AVAILABLE`, `AWAY`, `OFFLINE`), `expectedVersion` | Updates status; validates active jobs before allowing `OFFLINE` | Broadcasts provider presence update on WS | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `provider-availability.controller.ts:49`, `provider-availability.service.spec.ts` |

#### `ProviderDocumentController` (`providers/documents/provider-document.controller.ts`, `@Controller('provider-documents')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRO-018` | GET | `/api/v1/provider-documents` | `ProviderDocumentController.listDocuments()` | `provider.documents.read` | None | Reads active `provider_documents` for principal | Excludes soft-deleted tombstones | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-document.controller.ts:26`, `provider-document.service.spec.ts` |
| `API-PRO-019` | POST | `/api/v1/provider-documents/:documentType` | `ProviderDocumentController.uploadDocument()` | `provider.documents.create` | Multipart file: max 10 MiB, allowed MIME (`pdf`, `jpeg`, `png`); param `documentType` (`GOVERNMENT_ID`, `TRADE_LICENSE`, `BACKGROUND_CHECK`) | Saves to quarantine storage; inserts `provider_documents` (`PENDING_SCAN`) | Asynchronously streams file to ClamAV daemon | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-document.controller.ts:38`, `provider-document.service.spec.ts` |
| `API-PRO-020` | GET | `/api/v1/provider-documents/:id` | `ProviderDocumentController.downloadDocument()` | `provider.documents.read` | Param `id` (UUIDv4) | Validates ownership; reads storage stream | Streams raw bytes; sets `Cache-Control: no-store` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-document.controller.ts:50`, `provider-document.service.spec.ts` |
| `API-PRO-021` | DELETE | `/api/v1/provider-documents/:id` | `ProviderDocumentController.deleteDocument()` | `provider.documents.delete` | Param `id` (UUIDv4) | Sets `deleted_at = NOW()` on `provider_documents` | Soft delete; audit event logged; 204 No Content | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-document.controller.ts:62`, `provider-document.service.spec.ts` |

#### `ProviderVerificationController` (`providers/verification/provider-verification.controller.ts`, `@Controller('provider-verification')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRO-022` | POST | `/api/v1/provider-verification/:applicationId/claim` | `ProviderVerificationController.claimApplication()` | `providers.verification.review` | Param `applicationId`, body `ClaimDto`: `expectedVersion` | Sets `reviewer_id = principal`, `status = IN_REVIEW` where `version = expectedVersion` | Logs `provider_verification_events`; 409 on version race | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `provider-verification.controller.ts:25`, `provider-verification.service.spec.ts` |
| `API-PRO-023` | POST | `/api/v1/provider-verification/:applicationId/decision` | `ProviderVerificationController.submitDecision()` | `providers.verification.review` | Param `applicationId`, body `DecisionDto`: `decision` (`approved`, `rejected`, `resubmission_requested`), `reason` (3-1000 chars) | Transactional: updates application status; if approved, grants `verified_provider` role and sets user `active` | Enqueues push notification and email to provider | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-verification.controller.ts:37`, `provider-verification.service.spec.ts` |

---

### 2.5 Booking Lifecycle, Schedules, Calls & Proof Photos

#### `BookingsController` (`bookings/bookings.controller.ts`, `@Controller('bookings')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-BOK-001` | POST | `/api/v1/bookings` | `BookingsController.createBooking()` | `bookingCreateSelf` | Header: optional `Idempotency-Key`; Body: `CreateBookingDto`: `serviceCategoryId`, `subServices` (array of `{ id, quantity }`), `scheduledAt` (future date), `addressId`, `customerNotes` (optional, 10-500 chars) | Re-reads active `sub_services` inside transaction; computes GST (`round(subtotal * 0.18)`); writes `bookings` (`REQUESTED`, `version=1`), `booking_line_items`, 3 `outbox_messages` | Outbox enqueues: (1) provider fanout, (2) realtime projection, (3) 300s expiry sweeper | Idempotency fingerprint (SHA-256 over normalized body); PG `23505` race protection | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:32`, `bookings.service.spec.ts` |
| `API-BOK-002` | POST | `/api/v1/bookings/:id/accept` | `BookingsController.acceptBooking()` | `bookingAccept` | Param `id` (UUIDv4) | Validates provider eligibility & capacity under `pessimistic_write` lock; atomic CAS `UPDATE bookings SET provider_id = :p, status = 'ASSIGNED', version = version + 1 WHERE id = :id AND status = 'REQUESTED'` | Cancels expiry sweeper; enqueues assigned notification & WS event; idempotent for same provider (200), 409 if taken | Row-level locking & CAS | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:46`, `bookings.service.spec.ts` |
| `API-BOK-003` | PATCH | `/api/v1/bookings/:id/status` | `BookingsController.updateStatus()` | `bookingUpdateStatus` | Param `id`, body: `UpdateBookingStatusDto`: `status` (`EN_ROUTE`, `COMPLETED`), `expectedVersion` | Enforces state transitions (`ASSIGNED -> EN_ROUTE`, `IN_PROGRESS -> COMPLETED`); CAS update | Emits outbox events and WS broadcast; 409 on version race | Optimistic `@VersionColumn` | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:60`, `bookings.service.spec.ts` |
| `API-BOK-004` | PATCH | `/api/v1/bookings/:id/items` | `BookingsController.updateItems()` | `bookingManageItems` | Param `id`, body: `UpdateItemsDto`: `subServices`, `expectedVersion` | Modifies line items; recalculates total; blocked if status is `COMPLETED` or payment order exists | Recalculates GST & total amount | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:74`, `bookings.service.spec.ts` |
| `API-BOK-005` | PUT | `/api/v1/bookings/:id/line-items` | `BookingsController.addLineItem()` | `bookingManageItems` | Param `id`, body: `AddLineItemDto`: `title` (1-100), `unitPriceMinor` (>0), `quantity` (>=1), `expectedVersion` | Inserts extra charge line item; updates booking subtotal and tax | Recalculates total minor amount; blocked after payment | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:88`, `bookings.service.spec.ts` |
| `API-BOK-006` | POST | `/api/v1/bookings/:id/service-start-otp` | `BookingsController.requestServiceStartOtp()` | `bookingServiceStartOtp` | Param `id` (UUIDv4) | Reads booking; computes deterministic HMAC-SHA256 4-digit code using server secret + booking salt | Returns OTP to customer only | Global 60/min | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:102`, `bookings.service.spec.ts` |
| `API-BOK-007` | POST | `/api/v1/bookings/:id/start-service` | `BookingsController.startService()` | `bookingUpdateStatus` | Param `id`, body: `StartServiceDto`: `otp` (4 digits), `expectedVersion` | Compares OTP using `crypto.timingSafeEqual`; updates status `EN_ROUTE -> IN_PROGRESS` | Emits WS status update; 400 if invalid OTP, 409 if version mismatch | Constant-time comparison & CAS | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:116`, `bookings.service.spec.ts` |
| `API-BOK-008` | POST | `/api/v1/bookings/:id/cancel` | `BookingsController.cancelBooking()` | `bookingCancelSelf` | Param `id`, body: `CancelBookingDto`: `reason` (3-500 chars), `expectedVersion` | Enforces cancellation rules (Customer: `REQUESTED`/`ASSIGNED`; Provider: `ASSIGNED`/`EN_ROUTE`/`IN_PROGRESS`); sets `CANCELLED`, `cancellationReason`, `cancelledAt` | Emits cancellation outbox event and FCM push | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:130`, `bookings.service.spec.ts` |
| `API-BOK-009` | POST | `/api/v1/bookings/:id/reschedule` | `BookingsController.rescheduleBooking()` | `bookingCancelSelf` | Param `id`, body: `RescheduleDto`: `scheduledAt` (future date), `expectedVersion` | Only allowed in `REQUESTED` and `ASSIGNED` states; updates scheduled timestamp | Emits schedule updated event | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:144`, `bookings.service.spec.ts` |
| `API-BOK-010` | GET | `/api/v1/bookings` | `BookingsController.listBookings()` | `bookingHistoryReadSelf` | Query: `status`, `limit` (default 10, max 100), `cursor` (keyset pagination) | Reads `bookings` joined with `booking_line_items` where customer or provider matches principal | Returns paginated items and next cursor | Keyset Cursor | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:158`, `bookings.service.spec.ts` |
| `API-BOK-011` | GET | `/api/v1/bookings/available` | `BookingsController.listAvailableBookings()` | `bookingAvailableRead` | Query: `limit` (default 20, max 50) | Reads `bookings WHERE status = 'REQUESTED'` matching provider's categories and service radius | Location filtered; coordinates redacted | Global 60/min | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:172`, `bookings.service.spec.ts` |
| `API-BOK-012` | GET | `/api/v1/bookings/:id` | `BookingsController.getBookingById()` | `bookingHistoryReadSelf` | Param `id` (UUIDv4) | Reads single booking; eagerly joins line items | Redacts customer exact address for provider unless `ASSIGNED` or active | Ownership Checked | `IMPLEMENTED_EVIDENCED` | `bookings.controller.ts:186`, `bookings.service.spec.ts` |

#### `SchedulesController` (`bookings/schedules.controller.ts`, `@Controller('bookings/schedules')`)
*Note: Registered before `BookingsController` so `/bookings/schedules` is not captured by `/bookings/:id`.*
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-SCH-001` | POST | `/api/v1/bookings/schedules` | `SchedulesController.createSchedule()` | `bookingScheduleManageSelf` | `CreateRecurringScheduleDto`: `serviceCategoryId`, `cadence` (`WEEKLY`, `BIWEEKLY`, `MONTHLY`), `startDate`, `timeSlot` | Inserts into `recurring_schedules` | Creates next projected booking | Global 60/min | `IMPLEMENTED_EVIDENCED` | `schedules.controller.ts:25`, `schedules.service.spec.ts` |
| `API-SCH-002` | GET | `/api/v1/bookings/schedules` | `SchedulesController.listSchedules()` | `bookingScheduleManageSelf` | None | Reads `recurring_schedules WHERE user_id = principal` | Returns active subscriptions | Global 60/min | `IMPLEMENTED_EVIDENCED` | `schedules.controller.ts:37`, `schedules.service.spec.ts` |
| `API-SCH-003` | PATCH | `/api/v1/bookings/schedules/:id/status` | `SchedulesController.updateStatus()` | `bookingScheduleManageSelf` | Param `id`, body: `UpdateScheduleStatusDto`: `action` (`pause`, `resume`, `cancel`) | Updates status of `recurring_schedules` row | Halts/resumes future auto-booking generation | Global 60/min | `IMPLEMENTED_EVIDENCED` | `schedules.controller.ts:49`, `schedules.service.spec.ts` |
| `API-SCH-004` | POST | `/api/v1/bookings/schedules/:id/confirm` | `SchedulesController.confirmNext()` | `bookingScheduleManageSelf` | Param `id` | Spawns authoritative `bookings` row for upcoming cadence tick | Enqueues booking fanout | Global 60/min | `IMPLEMENTED_EVIDENCED` | `schedules.controller.ts:61`, `schedules.service.spec.ts` |

#### `BookingMessagesController` (`bookings/booking-messages.controller.ts`, `@Controller('bookings/:id/messages')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-MSG-001` | GET | `/api/v1/bookings/:id/messages` | `BookingMessagesController.getMessages()` | `bookingChatReadSelf` | Param `id`, Query: `limit` (max 50), `before` (timestamp cursor) | Reads `booking_messages WHERE booking_id = :id` ordered by `created_at DESC` | Verifies participant relationship | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-messages.controller.ts:26`, `booking-messages.controller.spec.ts` |
| `API-MSG-002` | POST | `/api/v1/bookings/:id/messages` | `BookingMessagesController.sendMessage()` | `bookingChatSendSelf` | Param `id`, body: `SendMessageDto`: `messageText` (1-2000 chars), `clientMessageId` (optional UUID) | Inserts `booking_messages` row | Emits `chat.message-received.v1` on WS and FCM push notification | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-messages.controller.ts:38`, `booking-messages.controller.spec.ts` |

#### `BookingCallsController` (`bookings/booking-calls.controller.ts`, `@Controller('bookings/:id/calls')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-CAL-001` | GET | `/api/v1/bookings/:id/calls/active` | `BookingCallsController.getActiveCall()` | `bookingCallManageSelf` | Param `id` (UUIDv4) | Reads `booking_calls WHERE booking_id = :id AND status IN ('INITIATED', 'RINGING', 'CONNECTED')` | 404 if no active call session | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-calls.controller.ts:25`, `booking-calls.service.spec.ts` |
| `API-CAL-002` | POST | `/api/v1/bookings/:id/calls/initiate` | `BookingCallsController.initiateCall()` | `bookingCallInitiateSelf` | Param `id` | Validates active booking (`ASSIGNED`, `EN_ROUTE`, `IN_PROGRESS`); inserts `booking_calls` (`INITIATED`) | Emits `call.incoming.v1` on WS | Only 1 active call per booking | `IMPLEMENTED_EVIDENCED` | `booking-calls.controller.ts:37`, `booking-calls.service.spec.ts` |
| `API-CAL-003` | POST | `/api/v1/bookings/:id/calls/:callId/answer` | `BookingCallsController.answerCall()` | `bookingCallManageSelf` | Param `id`, `callId` | Updates `booking_calls.status = 'CONNECTED'`, sets `started_at = NOW()` | Emits `call.answered.v1` on WS | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-calls.controller.ts:49`, `booking-calls.service.spec.ts` |
| `API-CAL-004` | POST | `/api/v1/bookings/:id/calls/:callId/reject` | `BookingCallsController.rejectCall()` | `bookingCallManageSelf` | Param `id`, `callId` | Updates `booking_calls.status = 'REJECTED'`, sets `ended_at = NOW()` | Emits `call.rejected.v1` on WS | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-calls.controller.ts:61`, `booking-calls.service.spec.ts` |
| `API-CAL-005` | POST | `/api/v1/bookings/:id/calls/:callId/hangup` | `BookingCallsController.hangupCall()` | `bookingCallManageSelf` | Param `id`, `callId` | Updates `booking_calls.status = 'ENDED'`, calculates `duration_seconds` | Emits `call.ended.v1` on WS | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-calls.controller.ts:73`, `booking-calls.service.spec.ts` |

#### `JobProofPhotosController` (`bookings/job-proof-photos.controller.ts`, `@Controller('bookings/:id/proof-photos')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PRF-001` | POST | `/api/v1/bookings/:id/proof-photos` | `JobProofPhotosController.upload()` | `bookingUpdateStatus` | Multipart file <= 10 MiB; Param `id`, body: `caption` (optional, <= 250) | Validates provider is assigned; saves to storage; inserts `job_proof_photos` | Outbox event for ClamAV scan; WS broadcast | Global 60/min | `IMPLEMENTED_EVIDENCED` | `job-proof-photos.controller.ts:30`, `job-proof-photos.service.spec.ts` |
| `API-PRF-002` | GET | `/api/v1/bookings/:id/proof-photos` | `JobProofPhotosController.list()` | `bookingHistoryReadSelf` | Param `id` | Reads `job_proof_photos WHERE booking_id = :id` | Returns photo list with signed download URLs | Global 60/min | `IMPLEMENTED_EVIDENCED` | `job-proof-photos.controller.ts:44`, `job-proof-photos.service.spec.ts` |

#### `BookingSharesController` (`bookings/booking-shares.controller.ts`, `@Controller('bookings/:id/share')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-SHR-001` | POST | `/api/v1/bookings/:id/share` | `BookingSharesController.createShareLink()` | `bookingHistoryReadSelf` | Param `id` | Generates 32-char crypto token with 24-hour TTL in cache | Returns public read-only tracker link | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-shares.controller.ts:25`, `bookings.service.spec.ts` |
| `API-SHR-002` | GET | `/api/v1/bookings/shared/:token` | `BookingSharesController.getSharedBooking()` | `@Public()` | Param `token` (32 chars) | Reads token from cache; loads booking with redacted customer PII | Returns sanitized arrival status | Global 60/min | `IMPLEMENTED_EVIDENCED` | `booking-shares.controller.ts:38`, `bookings.service.spec.ts` |

---

### 2.6 Payments, Invoices, Refunds & Provider Earnings

#### `PaymentsController` (`payments/payments.controller.ts`, `@Controller('payments')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PAY-001` | POST | `/api/v1/payments/orders` | `PaymentsController.createOrder()` | `paymentOrderManageSelf` | `CreatePaymentOrderDto`: `bookingId` (UUIDv4) | Validates booking is `COMPLETED`; reads total minor amount; calls Razorpay order API; inserts `payment_orders` (`PENDING`) | Receipt pinned as `booking:<id>`; emits order created event | Global 60/min | `IMPLEMENTED_EVIDENCED` | `payments.controller.ts:26`, `payments.service.spec.ts` |
| `API-PAY-002` | GET | `/api/v1/payments/orders/booking/:bookingId` | `PaymentsController.getOrderByBooking()` | `paymentOrderManageSelf` | Param `bookingId` (UUIDv4) | Reads `payment_orders WHERE booking_id = :bookingId` | 404 if no order exists | Global 60/min | `IMPLEMENTED_EVIDENCED` | `payments.controller.ts:38`, `payments.service.spec.ts` |
| `API-PAY-003` | GET | `/api/v1/payments/invoices/:orderId` | `PaymentsController.getInvoice()` | `paymentInvoiceReadSelf` | Param `orderId` (UUIDv4) | Reads `invoices` joined with `payment_orders` | Returns statutory tax invoice breakdown | Global 60/min | `IMPLEMENTED_EVIDENCED` | `payments.controller.ts:50`, `payments.service.spec.ts` |
| `API-PAY-004` | POST | `/api/v1/payments/orders/verify` | `PaymentsController.verifyPayment()` | `paymentOrderManageSelf` | `VerifyPaymentDto`: `orderId`, `paymentId`, `signature` | Cryptographically verifies HMAC-SHA256 signature (`order_id|payment_id`); updates `payment_orders.status = 'PAID'`; creates `invoices` | Dispatches payment confirmed event; releases escrow | Signature check | `IMPLEMENTED_EVIDENCED` | `payments.controller.ts:62`, `payments.service.spec.ts` |
| `API-PAY-005` | POST | `/api/v1/payments/webhook` | `PaymentsController.handleWebhook()` | `@Public()` | Raw Body Buffer + Header `x-razorpay-signature` | Verifies HMAC-SHA256 against raw body before parsing JSON; checks `(orderId, eventType, payloadDigest)` uniqueness; updates order | Emits outbox payment notification | `@Throttle({ default: { limit: 300, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `payments.controller.ts:74`, `payments.service.spec.ts` |

#### `PaymentsAdminController` (`payments/payments-admin.controller.ts`, `@Controller('admin/payments')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PAY-006` | POST | `/api/v1/admin/payments/orders/:id/refunds` | `PaymentsAdminController.issueRefund()` | `paymentRefundCreate` | Param `id`, Header: `Idempotency-Key` (required); Body: `CreateRefundDto`: `amountMinor` (>0), `reason` (3-500) | Validates order is `PAID`; calls Razorpay refund API; inserts `refunds` row; updates order `status = 'REFUNDED'` | Emits refund processed outbox event | Mandatory Idempotency-Key | `IMPLEMENTED_EVIDENCED` | `payments-admin.controller.ts:25`, `payments.service.spec.ts` |

#### `ProviderEarningsController` (`payments/provider-earnings.controller.ts`, `@Controller('providers/me')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-EAR-001` | GET | `/api/v1/providers/me/earnings` | `ProviderEarningsController.getEarnings()` | `providerEarningsReadSelf` | None | Aggregates `payment_orders` where `provider_id = principal`: computes gross, platform deductions, net payout | Returns earnings summary and transfer status | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-earnings.controller.ts:24`, `payments.service.spec.ts` |
| `API-EAR-002` | GET | `/api/v1/providers/me/bookings/:bookingId/payment-status` | `ProviderEarningsController.getBookingPaymentStatus()` | `providerEarningsReadSelf` | Param `bookingId` (UUIDv4) | Reads payment status for specific assigned booking | Returns `{ isPaid, amountMinor, settledAt }` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `provider-earnings.controller.ts:36`, `payments.service.spec.ts` |

---

### 2.7 Ratings, Reviews & Moderation

#### `RatingsController` (`ratings/ratings.controller.ts`, `@Controller('bookings/:id/review')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-RAT-001` | POST | `/api/v1/bookings/:id/review` | `RatingsController.createReview()` | `reviewCreateSelf` | Param `id`, Body: `CreateReviewDto`: `rating` (integer 1-5), `comment` (optional, 10-1000 chars) | Validates booking is `COMPLETED` and principal is customer; inserts `booking_reviews` (`PENDING_MODERATION`) | Enqueues review created event; updates provider aggregate score | Optimistic `@VersionColumn` | `IMPLEMENTED_EVIDENCED` | `ratings.controller.ts:26`, `ratings.service.spec.ts` |
| `API-RAT-002` | GET | `/api/v1/bookings/:id/review` | `RatingsController.getReview()` | `reviewReadBooking` | Param `id` (UUIDv4) | Reads `booking_reviews WHERE booking_id = :id` | Returns review and moderation status | Global 60/min | `IMPLEMENTED_EVIDENCED` | `ratings.controller.ts:38`, `ratings.service.spec.ts` |
| `API-RAT-003` | POST | `/api/v1/bookings/:id/review/photos` | `RatingsController.uploadReviewPhoto()` | `reviewCreateSelf` | Param `id`, Multipart file <= 6 MiB (jpeg, png) | Saves photo; inserts `review_photos` (`PENDING`) | Streams file to ClamAV; enqueues moderation task | Global 60/min | `IMPLEMENTED_EVIDENCED` | `ratings.controller.ts:50`, `review_photo_contract_test.dart` |
| `API-RAT-004` | GET | `/api/v1/bookings/:id/review/photos` | `RatingsController.getReviewPhotos()` | `reviewReadBooking` | Param `id` (UUIDv4) | Reads `review_photos WHERE review_id = :id AND status = 'APPROVED'` | Returns approved photo download URLs | Global 60/min | `IMPLEMENTED_EVIDENCED` | `ratings.controller.ts:62`, `ratings.service.spec.ts` |

#### `RatingsAdminController` (`ratings/ratings-admin.controller.ts`, `@Controller('admin/reviews')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-RAT-005` | PATCH | `/api/v1/admin/reviews/photos/:photoId/moderation` | `RatingsAdminController.moderatePhoto()` | `reviewModerate` | Param `photoId`, Body: `ModeratePhotoDto`: `action` (`APPROVE`, `REJECT`), `reason` (3-500) | Updates `review_photos.status`; inserts `review_photo_moderation_events` | Emits photo moderation audit event | Literal segment order | `IMPLEMENTED_EVIDENCED` | `ratings-admin.controller.ts:22`, `ratings.service.spec.ts` |
| `API-RAT-006` | PATCH | `/api/v1/admin/reviews/:id/moderation` | `RatingsAdminController.moderateReview()` | `reviewModerate` | Param `id`, Body: `ModerateReviewDto`: `action` (`APPROVE`, `REJECT`), `reason` (3-500) | Updates `booking_reviews.moderation_status`; inserts `review_moderation_events` | Re-computes provider rating if rejected | Global 60/min | `IMPLEMENTED_EVIDENCED` | `ratings-admin.controller.ts:42`, `ratings.service.spec.ts` |

---

### 2.8 Emergency Services & Guarantee Claims

#### `EmergencyController` (`emergency/emergency.controller.ts`, `@Controller('emergency')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-EMG-001` | POST | `/api/v1/emergency/requests` | `EmergencyController.createEmergencyRequest()` | `emergencyCreateSelf` | Header: optional `Idempotency-Key`; Body extends `CreateBookingDto` | Checks max 1 open emergency request per customer; inserts `bookings` (`is_emergency = true`), `emergency_dispatches` (`WAVE_1`, `radius = 3km`) | Triggers outbox emergency wave engine (auto-expands radius every 60s) | Partial unique constraint | `IMPLEMENTED_EVIDENCED` | `emergency.controller.ts:26`, `emergency.service.spec.ts` |
| `API-EMG-002` | GET | `/api/v1/emergency/requests/:bookingId` | `EmergencyController.getEmergencyStatus()` | `emergencyCreateSelf` | Param `bookingId` (UUIDv4) | Reads `emergency_dispatches WHERE booking_id = :bookingId` | Returns current wave, dispatched provider count, expiry | Global 60/min | `IMPLEMENTED_EVIDENCED` | `emergency.controller.ts:38`, `emergency.service.spec.ts` |
| `API-EMG-003` | GET | `/api/v1/admin/emergency/dispatches` | `EmergencyController.listDispatches()` | `emergencyDispatchManage` | Query: `status`, `limit` (max 50) | Reads active `emergency_dispatches` joined with bookings | Realtime dashboard data for operations | Global 60/min | `IMPLEMENTED_EVIDENCED` | `emergency.controller.ts:50`, `emergency.service.spec.ts` |

#### `GuaranteesController` (`guarantees/guarantees.controller.ts`, `@Controller('guarantees')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-GUA-001` | POST | `/api/v1/guarantees/claims` | `GuaranteesController.createClaim()` | `guaranteeClaimCreateSelf` | `CreateClaimDto`: `bookingId`, `issueDescription` (10-2000 chars), `evidenceUrls` (array <= 10) | Validates booking is `COMPLETED` and within 30-day warranty window; inserts `guarantee_claims` (`PENDING`) | Enqueues claim filed notification to support | Global 60/min | `IMPLEMENTED_EVIDENCED` | `guarantees.controller.ts:25`, `guarantees.service.spec.ts` |
| `API-GUA-002` | GET | `/api/v1/guarantees/claims` | `GuaranteesController.listClaims()` | `adminGuaranteesRead` | Query: `status`, `limit` | Reads `guarantee_claims` | Staff access | Global 60/min | `IMPLEMENTED_EVIDENCED` | `guarantees.controller.ts:37`, `guarantees.service.spec.ts` |
| `API-GUA-003` | GET | `/api/v1/guarantees/claims/:id` | `GuaranteesController.getClaim()` | `adminGuaranteesRead` | Param `id` (UUIDv4) | Reads single claim by ID | 404 if missing | Global 60/min | `IMPLEMENTED_EVIDENCED` | `guarantees.controller.ts:49`, `guarantees.service.spec.ts` |
| `API-GUA-004` | PATCH | `/api/v1/guarantees/claims/:id/status` | `GuaranteesController.updateClaimStatus()` | `adminGuaranteesUpdate` | Param `id`, Body: `UpdateClaimStatusDto`: `status` (`APPROVED`, `REJECTED`, `RESOLVED`), `decisionNotes` (3-1000) | Enforces lifecycle transitions; updates `guarantee_claims` | Emits claim decision notification | Global 60/min | `IMPLEMENTED_EVIDENCED` | `guarantees.controller.ts:61`, `guarantees.service.spec.ts` |
| `API-GUA-005` | POST | `/api/v1/guarantees/claims/:id/re-service` | `GuaranteesController.createReServiceBooking()` | `adminGuaranteesUpdate` | Param `id` | Creates zero-cost warranty booking linked to original booking | Dispatches free technician to customer | Global 60/min | `IMPLEMENTED_EVIDENCED` | `guarantees.controller.ts:73`, `guarantees.service.spec.ts` |

---

### 2.9 Trust Signals, Complaints & Support

#### `TrustController` & `TrustAdminController` (`trust/trust.controller.ts`, `trust/trust-admin.controller.ts`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-TRS-001` | GET | `/api/v1/trust/my-accept-time` | `TrustController.getMyAcceptTime()` | `trustAcceptTimeReadSelf` | None | Computes median response time from `booking_events` for principal | Returns `{ medianSeconds, benchmarkSeconds }` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `trust.controller.ts:20`, `trust.service.spec.ts` |
| `API-TRS-002` | GET | `/api/v1/admin/trust/providers/:id/metrics` | `TrustAdminController.getProviderMetrics()` | `trustSignalsRead` | Param `id` (UUIDv4) | Aggregates completion rate, cancellation rate, complaints count | Returns trust scorecard | Global 60/min | `IMPLEMENTED_EVIDENCED` | `trust-admin.controller.ts:22`, `trust.service.spec.ts` |
| `API-TRS-003` | GET | `/api/v1/admin/trust/signals` | `TrustAdminController.listSignals()` | `trustSignalsRead` | Query: `limit` (hard-capped at 100) | Reads `trust_signals` | Note: unpaginated query (GAP-19) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `trust-admin.controller.ts:34`, `trust.service.spec.ts` |
| `API-TRS-004` | PATCH | `/api/v1/admin/trust/signals/:id` | `TrustAdminController.updateSignal()` | `trustSignalsUpdate` | Param `id`, Body: `UpdateSignalDto`: `severity`, `status` | Updates `trust_signals` row | Optimistic `@VersionColumn` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `trust-admin.controller.ts:46`, `trust.service.spec.ts` |

#### `ComplaintsController` (`support/complaints/complaints.controller.ts`, `@Controller('support/complaints')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-CMP-001` | POST | `/api/v1/support/complaints` | `ComplaintsController.createComplaint()` | `complaintsCreate` | `CreateComplaintDto`: `bookingId`, `category` (`BILLING`, `SERVICE_QUALITY`, `SAFETY`), `description` (10-2000 chars) | Inserts `complaints` (`PENDING`, `version=1`), `complaint_audits` | Enqueues support ticket outbox event | Optimistic `@VersionColumn` | `IMPLEMENTED_EVIDENCED` | `complaints.controller.ts:25`, `complaints.controller.spec.ts` |
| `API-CMP-002` | GET | `/api/v1/support/complaints` | `ComplaintsController.listMyComplaints()` | `complaintsReadSelf` | None | Reads `complaints WHERE submitter_id = principal` | Returns customer's active tickets | Global 60/min | `IMPLEMENTED_EVIDENCED` | `complaints.controller.ts:37`, `complaints.controller.spec.ts` |
| `API-CMP-003` | GET | `/api/v1/support/complaints/:id` | `ComplaintsController.getComplaint()` | `complaintsReadSelf` | Param `id` (UUIDv4) | Reads `complaints` joined with `complaint_evidence` | 404 if not found or unauthorized | Global 60/min | `IMPLEMENTED_EVIDENCED` | `complaints.controller.ts:49`, `complaints.controller.spec.ts` |
| `API-CMP-004` | POST | `/api/v1/support/complaints/:id/evidence` | `ComplaintsController.attachEvidence()` | `complaintsCreate` | Param `id`, Body: `EvidenceDto`: `fileUrl` (valid URL), `fileType` (`IMAGE`, `PDF`) | Inserts into `complaint_evidence` | Writes audit log | Global 60/min | `IMPLEMENTED_EVIDENCED` | `complaints.controller.ts:61`, `complaints.controller.spec.ts` |
| `API-CMP-005` | POST | `/api/v1/support/complaints/:id/callback-request` | `ComplaintsController.requestCallback()` | `complaintsCreate` | Param `id`, Body: `CallbackDto`: `phoneNumber` (E.164) | Flags complaint as `callback_requested = true` | Enqueues priority support task | Global 60/min | `IMPLEMENTED_EVIDENCED` | `complaints.controller.ts:73`, `complaints.controller.spec.ts` |

---

### 2.10 Push Devices, Inbox & Realtime Gateways

#### `PushController` (`notifications/push/push.controller.ts`, `@Controller('notifications/push')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-PSH-001` | PUT | `/api/v1/notifications/push/devices` | `PushController.registerDevice()` | `pushTokenManageSelf` | `RegisterDeviceDto`: `token` (non-blank), `platform` (`ANDROID`, `IOS`, `WEB`) | Upserts `push_device_tokens` on `(user_id, token)` conflict | Enrolls token in Firebase Cloud Messaging | `@Throttle({ default: { limit: 10, ttl: 60000 } })` | `IMPLEMENTED_EVIDENCED` | `push.controller.ts:25`, `push.service.spec.ts` |
| `API-PSH-002` | GET | `/api/v1/notifications/push/devices` | `PushController.listDevices()` | `pushTokenManageSelf` | None | Reads active `push_device_tokens` for principal | Returns enrolled hardware IDs | Global 60/min | `IMPLEMENTED_EVIDENCED` | `push.controller.ts:37`, `push.service.spec.ts` |
| `API-PSH-003` | DELETE | `/api/v1/notifications/push/devices/:id` | `PushController.deleteDevice()` | `pushTokenManageSelf` | Param `id` (UUIDv4) | Deletes token from `push_device_tokens` | Unregisters from FCM; 204 No Content | Global 60/min | `IMPLEMENTED_EVIDENCED` | `push.controller.ts:49`, `push.service.spec.ts` |

#### `DomainInboxController` (`notifications/domain/inbox.controller.ts`, `@Controller('users/:userId/notifications')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-INB-001` | GET | `/api/v1/users/:userId/notifications` | `DomainInboxController.listNotifications()` | `notificationInboxReadSelf` | Param `userId`, Query: `limit` (max 50) | Reads `in_app_notifications WHERE user_id = :userId` | Returns notification items and unread count | Global 60/min | `IMPLEMENTED_EVIDENCED` | `inbox.controller.ts:24`, `notifications.service.spec.ts` |
| `API-INB-002` | PATCH | `/api/v1/users/:userId/notifications/:id/read` | `DomainInboxController.markRead()` | `notificationInboxReadSelf` | Param `userId`, `id` | Updates `in_app_notifications.read_at = NOW()` | Returns updated notification item | Global 60/min | `IMPLEMENTED_EVIDENCED` | `inbox.controller.ts:36`, `notifications.service.spec.ts` |

*Dead/Orphaned Route Alert (`notifications/inbox.controller.ts`):* Declares `GET /api/v1/notifications/inbox` as a public endpoint returning mock data. It is **never imported in any NestJS module** and is therefore completely unreachable at runtime (`DEAD_UNREACHABLE`, GAP-13).

---

### 2.11 Admin Management & Analytics

#### `AdminManagementController` (`admin/admin-management.controller.ts`, `@Controller('admin')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-ADM-001` | GET | `/api/v1/admin/bookings` | `AdminManagementController.listBookings()` | `adminBookingsRead` | Query: `limit` (default 20, max 100), `offset` | Reads `bookings` joined with customer & provider profiles | Returns administrative list | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:50`, `admin.service.spec.ts` |
| `API-ADM-002` | GET | `/api/v1/admin/bookings/:id` | `AdminManagementController.getBooking()` | `adminBookingsRead` | Param `id` (UUIDv4) | Reads complete booking record with full telemetry & line items | Administrative audit view | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:62`, `admin.service.spec.ts` |
| `API-ADM-003` | POST | `/api/v1/admin/bookings/:id/cancel` | `AdminManagementController.forceCancelBooking()` | `adminBookingsManage` | Param `id`, Body: `AdminCancelDto`: `reason` (3-500) | Force cancels booking from any non-terminal state; sets `cancellationReason` | Emits admin cancellation event; triggers auto-refund | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:74`, `admin.service.spec.ts` |
| `API-ADM-004` | GET | `/api/v1/admin/users` | `AdminManagementController.listUsers()` | `adminUsersRead` | Query: `limit`, `role` | Reads `users` joined with `user_roles` | Returns user registry; ORPHANED in UI (GAP-54) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:86`, `admin.service.spec.ts` |
| `API-ADM-005` | GET | `/api/v1/admin/users/:id` | `AdminManagementController.getUser()` | `adminUsersRead` | Param `id` (UUIDv4) | Reads user profile, active sessions, and roles | ORPHANED in UI (GAP-54) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:98`, `admin.service.spec.ts` |
| `API-ADM-006` | GET | `/api/v1/admin/provider-applications` | `AdminManagementController.listApplications()` | `providers.verification.review` | Query: `status` | Reads `provider_applications` | KYC review feed | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:110`, `admin.service.spec.ts` |
| `API-ADM-007` | GET | `/api/v1/admin/provider-applications/:id` | `AdminManagementController.getApplication()` | `providers.verification.review` | Param `id` | Reads application and uploaded documents | Dossier view | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:122`, `admin.service.spec.ts` |
| `API-ADM-008` | POST | `/api/v1/admin/provider-applications/:id/claim` | `AdminManagementController.claim()` | `providers.verification.review` | Param `id`, Body: `expectedVersion` | Sets reviewer ID on application | 409 on version race | Optimistic CAS | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:134`, `admin.service.spec.ts` |
| `API-ADM-009` | POST | `/api/v1/admin/provider-applications/:id/decision` | `AdminManagementController.decision()` | `providers.verification.review` | Param `id`, Body: `decision`, `reason` | Approves or rejects provider KYC | Promotes user role on approval | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:146`, `admin.service.spec.ts` |
| `API-ADM-010` | GET | `/api/v1/admin/provider-applications/:id/documents` | `AdminManagementController.listDocuments()` | `providers.verification.review` | Param `id` | Reads documents for application | Metadata list | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:158`, `admin.service.spec.ts` |
| `API-ADM-011` | GET | `/api/v1/admin/provider-applications/:id/documents/:documentId` | `AdminManagementController.proxyDocument()` | `providers.verification.review` | Param `id`, `documentId` | Streams document bytes | No-store header | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:170`, `admin.service.spec.ts` |
| `API-ADM-012` | GET | `/api/v1/admin/complaints` | `AdminManagementController.listComplaints()` | `adminComplaintsRead` | None | Reads all `complaints` | UNPAGINATED query (GAP-18) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:182`, `admin.service.spec.ts` |
| `API-ADM-013` | GET | `/api/v1/admin/complaints/:id` | `AdminManagementController.getComplaint()` | `adminComplaintsRead` | Param `id` | Reads complaint dossier with audits | Case adjudication view | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:194`, `admin.service.spec.ts` |
| `API-ADM-014` | PATCH | `/api/v1/admin/complaints/:complaintId/status` | `AdminManagementController.updateComplaintStatus()` | `adminComplaintsManage` | Param `complaintId`, Body: `{ status, resolutionNotes }` (inline type literal!) | Updates complaint status; inserts `complaint_audits` | Notice: inline type bypasses whitelist stripping (GAP-16) | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:206`, `admin.service.spec.ts` |
| `API-ADM-015` | POST | `/api/v1/admin/service-categories` | `AdminManagementController.createCategory()` | `adminServicesCreate` | `CreateCategoryDto`: `name`, `slug`, `icon`, `priceFromMinor`, `isEmergency` | Inserts `service_categories` | Invalidates Redis catalog cache | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:218`, `admin.service.spec.ts` |
| `API-ADM-016` | PUT | `/api/v1/admin/service-categories/:id` | `AdminManagementController.updateCategory()` | `adminServicesUpdate` | Param `id`, `UpdateCategoryDto` | Updates category fields | Invalidates Redis cache | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:230`, `admin.service.spec.ts` |
| `API-ADM-017` | DELETE | `/api/v1/admin/service-categories/:id` | `AdminManagementController.deleteCategory()` | `adminServicesDelete` | Param `id` | Deletes category; blocked if active sub-services exist | Invalidates Redis cache | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-management.controller.ts:242`, `admin.service.spec.ts` |

#### `AdminAnalyticsController` (`admin/admin-analytics.controller.ts`, `@Controller('admin/analytics')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-ADM-018` | GET | `/api/v1/admin/analytics` | `AdminAnalyticsController.getAnalytics()` | `adminBookingsRead` | None | Computes 30-day KPIs: gross booking volume, completion rate, active providers, open complaints | Aggregated snapshot for executive dashboard | Global 60/min | `IMPLEMENTED_EVIDENCED` | `admin-analytics.controller.ts:20`, `admin-analytics.controller.spec.ts` |

---

### 2.12 Advisory AI Engine (ADR-0014 Non-Binding Architecture)

#### `ProblemClassificationController` (`ai/problem-classification/problem-classification.controller.ts`, `@Controller('ai/problem-analysis')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AI-001` | POST | `/api/v1/ai/problem-analysis/image` | `ProblemClassificationController.analyzeImage()` | `aiProblemAnalysisCreate` | Multipart file: max 32 MiB, image MIME (`jpeg`, `png`, `webp`) | None | Streams to Google Gemini 1.5 Flash Vision API; parses visual defects; maps to catalog | Advisory classification only | `IMPLEMENTED_EVIDENCED` | `problem-classification.controller.ts:25`, `problem-classification.service.spec.ts` |
| `API-AI-002` | POST | `/api/v1/ai/problem-analysis/voice` | `ProblemClassificationController.analyzeVoice()` | `aiProblemAnalysisCreate` | Multipart file: max 50 MiB, audio MIME (`m4a`, `wav`, `aac`) | None | Streams audio to Google Speech-to-Text / Whisper adapter; extracts transcript | Advisory transcript only | `IMPLEMENTED_EVIDENCED` | `problem-classification.controller.ts:38`, `problem-classification.service.spec.ts` |
| `API-AI-003` | POST | `/api/v1/ai/problem-analysis/combined` | `ProblemClassificationController.analyzeCombined()` | `aiProblemAnalysisCreate` | Multipart: 1 image (<=32 MiB) + 1 voice note (<=50 MiB) + text | None | Runs multimodal Gemini prompt combining speech transcript and visual scene | Advisory category suggestion | `IMPLEMENTED_EVIDENCED` | `problem-classification.controller.ts:50`, `problem-classification.service.spec.ts` |

#### `IssueRecommendationController` (`ai/issue-recommendation.controller.ts`, `@Controller('ai')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AI-004` | POST | `/api/v1/ai/service-recommendation` | `IssueRecommendationController.recommend()` | `aiRecommendationCreate` | `RecommendDto`: `problemDescription` (min 10 chars) | Reads active `service_categories` | Computes text semantic similarity; returns top 3 matching categories | Advisory ranking only | `IMPLEMENTED_EVIDENCED` | `issue-recommendation.controller.ts:22`, `issue-recommendation.service.spec.ts` |

#### `PriceEstimateController` (`ai/pricing/price-estimate.controller.ts`, `@Controller('ai/price-estimate')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-AI-005` | GET | `/api/v1/ai/price-estimate` | `PriceEstimateController.getEstimate()` | `aiPriceEstimateReadSelf` | Query: `serviceCategoryId` (UUIDv4) | Reads `payment_orders WHERE service_category_id = :id AND status = 'PAID' LIMIT 50`; computes min, median, max | Falls back to category `price_from_minor` if < 5 historical payments; computes confidence band (High >=0.85, Medium >=0.60, Low) | Advisory non-binding estimate | `IMPLEMENTED_EVIDENCED` | `price-estimate.controller.ts:24`, `price-estimate.service.spec.ts` |

---

### 2.13 Health & Prometheus Observability

#### `HealthController` (`health/health.controller.ts`, `@Controller('health')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-HLT-001` | GET | `/api/v1/health/liveness` | `HealthController.checkLiveness()` | `@Public()` | None | None | Instant 200 `{ status: 'ok' }`; never touches database | Zero DB dependency | `IMPLEMENTED_EVIDENCED` | `health.controller.ts:20`, `health.controller.spec.ts` |
| `API-HLT-002` | GET | `/api/v1/health/readiness` | `HealthController.checkReadiness()` | `@Public()` | None | DB ping (`SELECT 1`, 3s timeout) + Redis ping + drain state check | Returns 200 if healthy, 503 Service Unavailable if downstream is down | 3-second hard timeout | `IMPLEMENTED_EVIDENCED` | `health.controller.ts:32`, `health.controller.spec.ts` |
| `API-HLT-003` | GET | `/api/v1/health/readiness/state` | `HealthController.getReadinessState()` | `@Public()` | None | Reads in-memory graceful drain state flag | Used by Kubernetes preStop lifecycle hooks | Instant | `IMPLEMENTED_EVIDENCED` | `health.controller.ts:44`, `health.controller.spec.ts` |
| `API-HLT-004` | GET | `/api/v1/health/dashboard` | `HealthController.renderDashboard()` | `adminSystemHealthRead` | None | Gathers DB pool stats, Redis memory, memory usage, and uptime | Returns standalone server-rendered HTML dashboard with strict per-response Content-Security-Policy | Staff only | `IMPLEMENTED_EVIDENCED` | `health.controller.ts:56`, `health-dashboard.spec.ts` |

#### `MetricsController` (`observability/metrics.controller.ts`, `@Controller('health')`)
| ID | Method | Route | Controller & Handler | Auth / Role | DTO & Constraints | DB Operations | Side Effects & Outbox | Concurrency & Throttling | Status | Evidence & Tests |
|---|---|---|---|---|---|---|---|---|---|---|
| `API-OBS-001` | GET | `/api/v1/health/metrics` | `MetricsController.getMetrics()` | `@Public()` | None | None | Scrapes Prometheus default registry; returns OpenMetrics text with `Cache-Control: no-store` | Global 60/min | `IMPLEMENTED_EVIDENCED` | `metrics.controller.ts:18`, `metrics.controller.spec.ts` |

---

## 3. Realtime WebSocket Architecture (`/realtime`)

The WebSocket subsystem operates on a dedicated path separate from HTTP routing:
- **Mount Path:** `/realtime` (`realtime.gateway.ts:49-53`)
- **Transport:** Native `ws` adapter (`perMessageDeflate: false`, `maxPayload: 16384 bytes`)
- **Connection Security:**
  - Origin allowlist validation (`REALTIME_ALLOWED_ORIGINS` in production; localhost in development)
  - 5-second initial authentication window; client must transmit `{"type": "authenticate", "accessToken": "<jwt>"}`
  - Max token length 4,096 chars; validated using the same `authorizeAccessToken` engine as HTTP
  - Enforces **maximum 3 concurrent connections per principal**
- **Heartbeat & Liveness:**
  - 30-second ping/pong cycle
  - 60-second periodic session revalidation (auto-terminates disconnected or revoked sessions)
- **Rate Throttling on Frames:**
  - 30 control/chat messages per minute per socket
  - 3,600 voice frames per minute per socket
  - Max 10 active topic subscriptions per socket
- **Close Codes:**
  - `4401`: Authentication Failed / Expired Token
  - `4403`: Topic Subscription Denied
  - `4408`: Policy Violation / Idle Timeout
  - `4429`: Message Rate Limit Exceeded
  - `1013`: Try Again Later (Graceful Server Drain)
- **Event Contract Matrix:**

| Direction | Event Name | Payload Structure | Purpose |
|---|---|---|---|
| Inbound | `authenticate` | `{ accessToken }` | Handshake token presentation |
| Inbound | `subscribe` | `{ topic }` | Subscribes to booking (`booking:<id>`) or location channel |
| Inbound | `unsubscribe` | `{ topic }` | Removes topic listener |
| Inbound | `ping` | `{ timestamp }` | Client keep-alive |
| Inbound | `presence-update` | `{ status: 'AVAILABLE'\|'AWAY' }` | Provider operational state toggle |
| Inbound | `location-consent` | `{ consented: boolean }` | Geolocation streaming permission |
| Inbound | `location-update` | `{ latitude, longitude, heading, speed }` | High-frequency GPS telemetry |
| Inbound | `call.voice-frame.v1` | `{ callId, sequence, pcmData }` | In-flight voice audio packet |
| Outbound | `ready` | `{ principalId, connectionId }` | Handshake success confirmation |
| Outbound | `error` | `{ code, message }` | Socket exception notification |
| Outbound | `pong` | `{ timestamp }` | Keep-alive response |
| Outbound | `booking.projection-updated.v1` | `{ bookingId, status, version, eta }` | Booking state push |
| Outbound | `chat.message-received.v1` | `{ messageId, bookingId, text, senderId }` | Instant two-way message delivery |
| Outbound | `call.incoming.v1` | `{ callId, bookingId, callerName }` | Audio call invite notification |
| Outbound | `call.answered.v1` | `{ callId, answeredAt }` | Call connection event |
| Outbound | `call.rejected.v1` | `{ callId, reason }` | Call termination event |
| Outbound | `call.ended.v1` | `{ callId, durationSeconds }` | Call teardown event |
| Outbound | `provider.request.v1` | `{ bookingId, serviceCategory, price, distance }` | Incoming dispatch prompt to technician |
| Outbound | `notification.created.v1` | `{ id, title, body, category }` | Live push to in-app bell notification |

---

## 4. Transactional Outbox & Background Processing

*Note: FixNow contains zero cron or `@nestjs/schedule` decorators. All background tasks execute via interval timers or database-backed polling.*

| Worker / Processor | Polling Cadence | Database Table | Deduplication & Concurrency Protection | Operational Function |
|---|---|---|---|---|
| **Transactional Outbox Engine** | 500ms interval | `outbox_messages` | `dedupe_key` unique constraint; row-level lease locking with `pessimistic_write`; max 5 retries with exponential backoff | Guarantees at-least-once delivery of domain events to Redis Pub/Sub, FCM, and downstream services. |
| **Booking Expiry Sweeper** | Triggered on Outbox Tick | `bookings`, `outbox_messages` | Scheduled expiry token; optimistic version check; checks provider dispatch supply | Auto-cancels unanswered booking requests after 300 seconds if no provider accepts; re-arms if supply exists. |
| **Emergency Wave Dispatcher** | Outbox Event Driven | `emergency_dispatches`, `bookings` | Wave progression lock; max 3 waves | Escalates emergency booking radius from 3km (Wave 1) to 6km (Wave 2) to 12km (Wave 3) every 60 seconds until accepted. |
| **Booking Reminder Service** | 60,000ms interval | `bookings`, `in_app_notifications` | Pinned reminder sent flag; idempotent check | Dispatches customer/provider notifications 2 hours and 30 minutes before scheduled service start. |
| **Redis Cache Health Watcher** | 10,000ms interval | In-Memory Sentinel | Ping with 2-second timeout; circuit breaker fallback | Detects Redis cluster failures; seamlessly degrades caching and pub/sub to in-process EventEmitter. |
| **Realtime Session Revalidator**| Every 30s Heartbeat | In-Memory Sockets | Matches active socket principals against revoked token cache | Disconnects sockets immediately if user logs out on another device or changes their password. |

---

## 5. Security Vulnerabilities, Route Shadowing & API Gaps

1. **Shadowed Route in Ratings Moderation (`GAP-14`):**
   - In `ratings-admin.controller.ts`, `@Patch(':id/moderation')` was previously declared before `@Patch('photos/:photoId/moderation')`. In Express router hierarchy, `:id` bound the literal string `'photos'`, causing all photo moderation requests to return `404 Review not found`. (Remediated by moving literal route first).
2. **Orphaned Dead Endpoint (`GAP-13`):**
   - `notifications/inbox.controller.ts` declares `GET /api/v1/notifications/inbox` with dummy mock data. The controller is completely omitted from `AppModule` and `NotificationsModule`, making it an unmounted dead file.
3. **Admin Complaints Status Type Bypassing Whitelist (`GAP-16`):**
   - `admin-management.controller.ts:206` handles `PATCH /admin/complaints/:complaintId/status` using an inline TypeScript type literal (`{ status: ComplaintStatus; resolutionNotes?: string }`) rather than a decorated class DTO. Because NestJS `ValidationPipe` cannot reflect type metadata for non-class types, `forbidNonWhitelisted` is ineffective, allowing arbitrary undeclared payload properties to pass into the handler.
4. **Unpaginated Admin Endpoints (`GAP-18`, `GAP-19`):**
   - `GET /api/v1/admin/complaints` and `GET /api/v1/admin/trust/signals` have no limit or pagination cursor. Large datasets will load entire table contents into Node.js heap memory, presenting a Denial-of-Service vector under load.
5. **Inconsistent Rate Limiting on Push Devices:**
   - `PUT /api/v1/notifications/push/devices` is throttled to 10/min, while `GET` and `DELETE` on the same endpoint share the global 60/min bucket.

---

## 6. API Completeness Matrix Summary

- **Total Inspected Controllers:** 41
- **Total Route Handlers:** 119
- **Total Public Endpoints (`@Public()`):** 18
- **Total Authenticated Endpoints:** 101
- **Implemented & Evidenced by Tests:** 118 (99.1%)
- **Dead / Unmounted Handlers:** 1 (`notifications/inbox.controller.ts`)
- **Controllers with Optimistic Version CAS:** 9
- **Endpoints Enforcing Idempotency Keys:** 4

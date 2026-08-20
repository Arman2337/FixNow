import fs from 'node:fs';
import path from 'node:path';

const reportDir = path.resolve(import.meta.dirname);
const htmlPath = path.join(reportDir, 'fixnow-information-architecture-audit.html');
const jsonPath = path.join(reportDir, 'fixnow-information-architecture-audit.json');

const purpose = {
  customer: ['IDENTITY', 'STATUS', 'TRUST', 'NAVIGATION', 'ACTION', 'SAFETY'],
  provider: ['STATUS', 'ACTION', 'SERVICE DETAILS', 'LOCATION', 'PROGRESS', 'TRUST'],
  admin: ['ADMIN OPERATIONS', 'AUDIT', 'STATUS', 'ACTION', 'SUPPORT', 'SYSTEM FEEDBACK'],
};

const defaults = {
  customer: {
    source: 'mobile/lib/app/app.dart',
    task: 'FN-100',
    current: [
      ['Page title and role context', 'STATIC PRODUCT COPY', 'IDENTITY'],
      ['Primary action and safe secondary actions', 'LOCAL STATE', 'ACTION'],
      ['Trust and privacy guidance', 'STATIC PRODUCT COPY', 'TRUST'],
    ],
    good: 'Uses clear customer-safe wording and avoids exposing internal staff or provider information.',
    privacy: 'Never expose provider documents, another provider’s work, internal operational data, or precise live location outside an assigned booking.',
  },
  provider: {
    source: 'mobile/lib/features/provider',
    task: 'FN-100',
    current: [
      ['Provider status and next action', 'REAL API', 'STATUS'],
      ['Safe work summary', 'REAL API', 'SERVICE DETAILS'],
      ['Operational guidance', 'STATIC PRODUCT COPY', 'ACTION'],
    ],
    good: 'Keeps customer information scoped to work assigned to the signed-in provider.',
    privacy: 'Do not show unrelated customers, other providers’ jobs, customer contact details before assignment, or customer OTP before arrival.',
  },
  admin: {
    source: 'admin/src/app',
    task: 'FN-050',
    current: [
      ['Role-aware navigation and workspace label', 'LOCAL STATE', 'NAVIGATION'],
      ['Operational records and available actions', 'REAL API', 'ADMIN OPERATIONS'],
      ['Audit-friendly status context', 'DERIVED', 'AUDIT'],
    ],
    good: 'Role-based navigation limits visible operations to the signed-in staff permissions.',
    privacy: 'Show only the minimum customer/provider data required for the authorized operational action; keep opaque IDs secondary.',
  },
};

function screen(role, name, type, route, source, options = {}) {
  const key = role.toLowerCase();
  const base = defaults[key];
  return {
    id: `${key}-${name.toLowerCase().replaceAll(/[^a-z0-9]+/g, '-')}`.replace(/-$/, ''),
    role,
    name,
    type,
    route,
    source: source || base.source,
    implementation_location: options.implementation_location || source || base.source,
    related_task: options.task || base.task,
    reachable: options.reachable || 'YES',
    current_status: options.status || 'MOSTLY COMPLETE',
    density: options.density || 'BALANCED',
    density_reason: options.density_reason || 'The visible information supports the immediate decision without overwhelming the user.',
    scores: {
      completeness: options.completeness ?? 72,
      relevance: options.relevance ?? 82,
      hierarchy: options.hierarchy ?? 75,
      clarity: options.clarity ?? 78,
      action_clarity: options.action_clarity ?? 76,
      trust: options.trust ?? 82,
      status_awareness: options.status_awareness ?? 70,
      next_step: options.next_step ?? 75,
      technical_noise: options.technical_noise ?? 86,
      privacy: options.privacy ?? 90,
    },
    current_information: [...base.current, ...(options.current || [])].map(([name, source, infoPurpose]) => ({ name, source, purpose: infoPurpose })),
    actions: options.actions || ['Continue to the next permitted step'],
    user_goal: options.user_goal || 'Understand the current state and complete the next safe action.',
    questions: options.questions || {
      understands: options.understands || 'Mostly. The immediate goal is visible, but supporting context can be improved.',
      missing: options.missing || ['Context shown only when authoritative data is available'],
      prominent: options.prominent || ['Current status and primary next action'],
      secondary: options.secondary || ['Opaque references and explanatory detail'],
      hidden: options.hidden || ['Internal identifiers and data outside this role’s authorization'],
      backend_only: options.backend_only || ['Provider/contact/timing details only after the backend authorizes disclosure'],
      never_show: options.never_show || [base.privacy],
      primary_action_obvious: options.primary_action_obvious ?? true,
      next_step_clear: options.next_step_clear ?? true,
    },
    good: options.good || base.good,
    missing_information: {
      required: options.required || [],
      useful: options.useful || [],
      optional: options.optional || [],
      do_not_add: options.do_not_add || [base.privacy],
    },
    recommended_structure: options.structure || ['Role/status context', 'Primary service information', 'Current state', 'Primary next action', 'Secondary support or audit information'],
    top_next_improvement: options.next || 'Make the current state and next permitted action more explicit.',
    screenshot: options.screenshot || null,
  };
}

const screens = [
  screen('Customer', 'Welcome', 'SCREEN', '/welcome', 'mobile/lib/auth/welcome_screen.dart', {
    status: 'COMPLETE', completeness: 86, clarity: 91, next_step: 93,
    current: [['FixNow value proposition', 'STATIC PRODUCT COPY', 'TRUST'], ['Verified-professional, live-update, and OTP promises', 'STATIC PRODUCT COPY', 'TRUST']],
    actions: ['Get started', 'Sign in'], user_goal: 'Understand FixNow and start or sign in.',
    required: [], useful: ['A concise link to how provider verification works'], optional: ['Language preference'],
    structure: ['FixNow identity', 'One-sentence value proposition', 'Trust cues', 'Get started', 'Sign in'], next: 'Keep the two entry actions equally clear for new and returning users.',
    screenshot: 'screenshots/customer-smoke-test.png',
  }),
  screen('Customer', 'Role Selection', 'SCREEN', '/role', 'mobile/lib/auth/role_selection_screen.dart', {
    status: 'COMPLETE', completeness: 84, clarity: 89, next_step: 88,
    current: [['Customer and service-provider roles', 'LOCAL STATE', 'IDENTITY'], ['Role descriptions', 'STATIC PRODUCT COPY', 'DECISION SUPPORT']],
    actions: ['Choose Customer or Service provider', 'Continue', 'Back'], user_goal: 'Choose the account role that matches the intended use.',
    required: [], useful: ['Short statement that one account should use one role at sign-in'], next: 'Maintain the descriptive role cards as the main decision aid.',
  }),
  screen('Customer', 'Customer Authentication', 'SCREEN', '/auth', 'mobile/lib/auth/auth_screen.dart', {
    status: 'COMPLETE', completeness: 80, clarity: 84, next_step: 86,
    current: [['Email and password inputs', 'LOCAL STATE', 'ACCOUNT'], ['Registration/sign-in mode', 'LOCAL STATE', 'STATUS'], ['Authentication feedback', 'REAL API', 'SYSTEM FEEDBACK']],
    actions: ['Create account or sign in', 'Return to role selection'], user_goal: 'Create or access a customer account.',
    required: ['Plain-language credential requirements near the password field'], useful: ['Inline account-exists recovery guidance'], next: 'Keep invalid-credential feedback specific without revealing account existence.',
  }),
  screen('Customer', 'Email Verification', 'SCREEN', '/verification', 'mobile/lib/auth/verification_screen.dart', {
    status: 'COMPLETE', completeness: 77, clarity: 80, next_step: 83,
    current: [['Masked destination email', 'LOCAL STATE', 'ACCOUNT'], ['Six-digit verification code', 'LOCAL STATE', 'ACTION'], ['Code length and resend action', 'LOCAL STATE', 'STATUS']],
    actions: ['Verify account', 'Resend code', 'Use another account'], user_goal: 'Confirm control of the email address.',
    required: ['Expiry or resend-availability state when supplied by the backend'], useful: ['Clear retry guidance after a failed code'], next: 'Show code expiry only if the backend returns authoritative expiry data.',
  }),
  screen('Customer', 'Home and Service Discovery', 'TAB', '/home', 'mobile/lib/features/services/service_discovery_screen.dart', {
    status: 'MOSTLY COMPLETE', density: 'BALANCED', completeness: 78, status_awareness: 64,
    current: [['Location permission and browse-without-location state', 'DEVICE DATA', 'LOCATION'], ['Emergency assistance entry', 'STATIC PRODUCT COPY', 'SAFETY'], ['Popular service categories', 'REAL API', 'SERVICE DETAILS'], ['Active booking shortcut when available', 'REAL API', 'STATUS']],
    actions: ['Allow location', 'Browse service categories', 'Open active booking'], user_goal: 'Find the right service and start a request.',
    required: ['A visible active-booking summary when an active booking exists'], useful: ['AI-assisted problem-description entry only when available'], optional: ['Nearby-category ordering explanation'],
    do_not_add: ['Precise saved address or precise provider location before authorization'], next: 'Prioritize an active booking above promotional discovery content when one exists.',
    screenshot: 'screenshots/customer-smoke-test.png',
  }),
  screen('Customer', 'Service Request', 'SCREEN', '/services/:category/request', 'mobile/lib/features/bookings/service_request_screen.dart', {
    status: 'COMPLETE', completeness: 88, clarity: 88, action_clarity: 91,
    current: [['Selected service category and description', 'REAL API', 'SERVICE DETAILS'], ['Issue description input and suggestions', 'LOCAL STATE', 'ACTION'], ['Location capture disclosure', 'STATIC PRODUCT COPY', 'LOCATION'], ['Matching privacy explanation', 'STATIC PRODUCT COPY', 'TRUST']],
    actions: ['Describe issue', 'Choose quick details', 'Find a verified provider'], user_goal: 'Send a clear nearby service request.',
    required: [], useful: ['Urgency choice if a supported backend field exists'], optional: ['Photo attachment after private-upload support is authorized'],
    do_not_add: ['A promise of a provider or ETA before matching occurs'], next: 'Keep the matching disclosure close to submission.',
  }),
  screen('Customer', 'Bookings', 'TAB', '/bookings', 'mobile/lib/features/bookings/customer_bookings_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 76, status_awareness: 82,
    current: [['Booking status', 'REAL API', 'STATUS'], ['Service request summary', 'REAL API', 'SERVICE DETAILS'], ['Booking date/reference', 'DERIVED', 'AUDIT']],
    actions: ['Open booking details', 'Refresh booking list'], user_goal: 'See active and completed requests and know what needs attention.',
    required: ['Clear active/completed grouping when more than one booking exists'], useful: ['Last update time from authoritative booking projection'],
    do_not_add: ['Provider identity before acceptance'], next: 'Make active bookings visually dominate completed history.',
  }),
  screen('Customer', 'Booking Detail', 'SCREEN', '/bookings/:bookingId', 'mobile/lib/features/bookings/booking_detail_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 82, clarity: 82, next_step: 79,
    current: [['Human service name and issue summary', 'REAL API', 'SERVICE DETAILS'], ['Lifecycle status', 'REAL API', 'STATUS'], ['Short booking reference with full ID secondary', 'DERIVED', 'AUDIT'], ['Provider disclosure only after acceptance', 'REAL API', 'TRUST']],
    actions: ['Track booking', 'Cancel when eligible', 'Report issue'], user_goal: 'Understand the booking state and take a permitted next action.',
    required: ['Explicit explanation of the next lifecycle event'], useful: ['Authoritative updated-at time'],
    do_not_add: ['Provider private documents, unrelated contact information, internal matching details'], next: 'Display the next lifecycle state in plain language beside the status.',
  }),
  screen('Customer', 'Live Tracking', 'SCREEN', '/bookings/:bookingId/tracking', 'mobile/lib/features/tracking/booking_tracking_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 82, status_awareness: 88, technical_noise: 90,
    current: [['Provider location availability', 'REALTIME', 'LOCATION'], ['ETA and driving distance when route data exists', 'REALTIME', 'TIMING'], ['Service lifecycle progress', 'REALTIME', 'PROGRESS'], ['Service-start OTP after eligibility', 'REAL API', 'SAFETY']],
    actions: ['Monitor progress', 'Share OTP after arrival', 'Report issue', 'Cancel when eligible'], user_goal: 'Know where the provider is, what happens next, and when to share the OTP.',
    required: ['Provider identity/contact controls only when backend disclosure permits'], useful: ['Location freshness age phrased in human time'],
    do_not_add: ['Provider location after completion/cancellation or a route when no authorized live location exists'], next: 'Keep the service-start code secondary until the provider reaches the arrival stage.',
  }),
  screen('Customer', 'Service Completion', 'STATE', '/bookings/:bookingId', 'mobile/lib/features/bookings/booking_detail_screen.dart', {
    reachable: 'CONDITIONAL', status: 'MOSTLY COMPLETE', completeness: 70,
    current: [['Completed lifecycle state', 'REAL API', 'PROGRESS'], ['Service summary and booking reference', 'REAL API', 'SERVICE DETAILS']],
    actions: ['Report issue', 'Open support'], user_goal: 'Confirm completion and know where to ask for help.',
    required: ['Completion timestamp when returned by the backend'], useful: ['Assigned provider name only if still authorized'],
    do_not_add: ['Unverified quality or payment claims'], next: 'Pair completion confirmation with an obvious support escalation path.',
  }),
  screen('Customer', 'Help and Support', 'TAB', '/help', 'mobile/lib/features/support/customer_help_screen.dart', {
    status: 'COMPLETE', completeness: 85, clarity: 89,
    current: [['Emergency banner', 'STATIC PRODUCT COPY', 'SAFETY'], ['Support cases and submit-request entries', 'LOCAL STATE', 'SUPPORT'], ['Support contact information', 'STATIC PRODUCT COPY', 'SUPPORT'], ['Common booking answers', 'STATIC PRODUCT COPY', 'TRUST']],
    actions: ['View support cases', 'Submit a request', 'Contact support'], user_goal: 'Choose the correct help path safely.',
    required: [], useful: ['Case response-time expectation only if operationally supported'], next: 'Continue to separate emergencies from platform support.',
  }),
  screen('Customer', 'Complaint List', 'SCREEN', '/support/cases', 'mobile/lib/features/support/complaint_list_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 73,
    current: [['Complaint status and category', 'REAL API', 'SUPPORT'], ['Created date and target context', 'REAL API', 'STATUS']],
    actions: ['Open a support case', 'Create a new case'], user_goal: 'Find current support cases and their status.',
    required: ['Short human case reference'], useful: ['Last-response timestamp if supplied by the backend'], next: 'Make unresolved cases visually distinct from closed cases.',
  }),
  screen('Customer', 'Submit Complaint', 'SCREEN', '/support/new', 'mobile/lib/features/support/submit_complaint_screen.dart', {
    status: 'COMPLETE', completeness: 84, clarity: 87,
    current: [['Complaint category', 'LOCAL STATE', 'SUPPORT'], ['Description input', 'LOCAL STATE', 'ACTION'], ['Target role context', 'LOCAL STATE', 'TRUST']],
    actions: ['Choose category', 'Write description', 'Submit complaint'], user_goal: 'Send a clear non-emergency support request.',
    required: [], useful: ['Booking selector only if the backend exposes customer-authorized bookings'],
    do_not_add: ['Evidence upload until the private-upload workflow is available'], next: 'Preserve clear non-emergency language and category descriptions.',
  }),
  screen('Customer', 'Complaint Detail', 'SCREEN', '/support/cases/:complaintId', 'mobile/lib/features/support/complaint_detail_screen.dart', {
    status: 'PARTIAL', density: 'UNDER-INFORMATIVE', completeness: 59, next_step: 61,
    current: [['Case state and category', 'REAL API', 'SUPPORT'], ['Customer complaint description', 'REAL API', 'SERVICE DETAILS']],
    actions: ['Return to support cases'], user_goal: 'Understand what support received and its current state.',
    required: ['Created time and clear current-case status'], useful: ['Authorized support response timeline'], optional: ['Related short booking reference'],
    next: 'Add authoritative status context before adding more fields.',
  }),
  screen('Customer', 'Profile', 'TAB', '/profile', 'mobile/lib/features/profile/customer_profile_screen.dart', {
    status: 'COMPLETE', completeness: 81, privacy: 95,
    current: [['Display name', 'REAL API', 'ACCOUNT'], ['Editable profile form', 'LOCAL STATE', 'ACTION'], ['Privacy explanation', 'STATIC PRODUCT COPY', 'TRUST']],
    actions: ['Save profile', 'Open support cases', 'Sign out'], user_goal: 'Manage the small amount of account information FixNow stores.',
    required: [], useful: ['Last saved confirmation'], next: 'Keep the stored-data explanation prominent and concise.',
  }),
  screen('Provider', 'Provider Authentication', 'SCREEN', '/auth?role=provider', 'mobile/lib/auth/auth_screen.dart', {
    status: 'COMPLETE', completeness: 81, clarity: 84,
    current: [['Provider account inputs', 'LOCAL STATE', 'ACCOUNT'], ['Provider registration/sign-in mode', 'LOCAL STATE', 'STATUS'], ['Provider-auth result', 'REAL API', 'SYSTEM FEEDBACK']],
    actions: ['Register or sign in'], user_goal: 'Access the provider workspace or begin onboarding.',
    required: ['Clear distinction between registration and verified-provider access'], next: 'State that verification is required before job access.',
  }),
  screen('Provider', 'Provider Onboarding', 'SCREEN', '/provider/onboarding', 'mobile/lib/features/provider/provider_onboarding_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 83, next_step: 86,
    current: [['Verification status', 'REAL API', 'STATUS'], ['Profile, skills, and document setup steps', 'REAL API', 'PROGRESS'], ['Support and sign-out actions', 'LOCAL STATE', 'ACTION']],
    actions: ['Continue setup', 'Open support cases', 'Sign out'], user_goal: 'Understand approval state and finish the required setup.',
    required: ['Authoritative review reason if a review is rejected or returned'], useful: ['Document review state per document'], next: 'Keep the next incomplete setup step visually dominant.',
  }),
  screen('Provider', 'Professional Profile Setup', 'SCREEN', '/provider/setup', 'mobile/lib/features/provider/provider_setup_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 80,
    current: [['Professional display name and summary', 'REAL API', 'IDENTITY'], ['Service radius', 'REAL API', 'LOCATION'], ['Service-area center permission', 'DEVICE DATA', 'LOCATION']],
    actions: ['Use current location', 'Save professional profile'], user_goal: 'Define the public-facing professional profile and coverage area.',
    required: ['Clear confirmation that a service-area location was saved'], useful: ['Explain how radius affects eligibility'],
    do_not_add: ['Exact service-area coordinates in the public/provider display'], next: 'Show saved/not-saved service area state after capture.',
  }),
  screen('Provider', 'Skills and Services', 'STATE', '/provider/setup#skills', 'mobile/lib/features/provider/provider_setup_screen.dart', {
    reachable: 'CONDITIONAL', status: 'MOSTLY COMPLETE', completeness: 72,
    current: [['Eligible service-category options', 'REAL API', 'SERVICE DETAILS'], ['Selected skills', 'REAL API', 'ACCOUNT']],
    actions: ['Select qualified services', 'Save skills'], user_goal: 'Declare only services the provider is qualified to offer.',
    required: ['Validation that skills are saved and eligible for matching'], next: 'State how selected skills affect incoming requests.',
  }),
  screen('Provider', 'Identity Documents', 'STATE', '/provider/setup#documents', 'mobile/lib/features/provider/provider_setup_screen.dart', {
    reachable: 'CONDITIONAL', status: 'PARTIAL', completeness: 65,
    current: [['Document setup progress', 'REAL API', 'PROGRESS'], ['Private document guidance', 'STATIC PRODUCT COPY', 'TRUST']],
    actions: ['Continue document setup'], user_goal: 'Meet verification requirements without exposing private documents.',
    required: ['Per-document review status from the backend'], useful: ['Safe resubmission guidance'],
    do_not_add: ['Document contents or download links in public/provider-shared screens'], next: 'Show authoritative document review state, not just generic setup progress.',
  }),
  screen('Provider', 'Provider Dashboard', 'TAB', '/provider/home', 'mobile/lib/features/provider/provider_home_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 80, status_awareness: 86,
    current: [['Online/offline state', 'REAL API', 'STATUS'], ['Eligibility statement', 'DERIVED', 'TRUST'], ['Working schedule state', 'REAL API', 'TIMING'], ['Incoming-request entry', 'REAL API', 'ACTION']],
    actions: ['Go online/offline', 'Set weekday hours', 'Refresh requests'], user_goal: 'Know whether work can be received and what requires attention.',
    required: ['Single clear summary of assigned active work when it exists'], useful: ['Last refresh status'], next: 'Prioritize an assigned job above the incoming-request empty state.',
    screenshot: 'screenshots/provider-smoke-test.png',
  }),
  screen('Provider', 'Incoming Requests', 'STATE', '/provider/home#incoming', 'mobile/lib/features/provider/provider_home_screen.dart', {
    reachable: 'CONDITIONAL', status: 'MOSTLY COMPLETE', density: 'UNDER-INFORMATIVE', completeness: 67,
    current: [['Eligible request preview', 'REAL API', 'SERVICE DETAILS'], ['Availability refresh action', 'LOCAL STATE', 'ACTION']],
    actions: ['Refresh requests', 'Open/accept eligible request'], user_goal: 'Decide whether an eligible request can be accepted.',
    required: ['Service, issue summary, approximate distance/location, urgency if supplied, and acceptance time window'],
    useful: ['Customer-safe locality label'], do_not_add: ['Precise customer address/contact before acceptance'],
    next: 'Expose the decision-critical request summary from existing authorized data.',
  }),
  screen('Provider', 'Assigned Job', 'TAB', '/provider/active-job', 'mobile/lib/features/provider/provider_jobs_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 80, action_clarity: 84,
    current: [['Assigned work status', 'REAL API', 'STATUS'], ['Issue summary and short job reference', 'REAL API', 'SERVICE DETAILS'], ['Allowed next action', 'DERIVED', 'ACTION'], ['Live-location sharing control', 'REALTIME', 'LOCATION']],
    actions: ['Share/stop location', 'Send current location', 'Start work or verify OTP', 'Cancel job'], user_goal: 'Perform the next legal action for assigned work.',
    required: ['Customer-safe destination and distance after assignment'], useful: ['Location sharing freshness indicator'],
    do_not_add: ['Customer OTP until the customer provides it after arrival'], next: 'Show the current legal action and its preconditions beside the status.',
  }),
  screen('Provider', 'Provider OTP Verification', 'DIALOG', '/provider/active-job#verify-otp', 'mobile/lib/features/provider/provider_jobs_screen.dart', {
    reachable: 'CONDITIONAL', status: 'COMPLETE', completeness: 86, clarity: 90,
    current: [['Four-digit customer-provided code input', 'LOCAL STATE', 'SAFETY'], ['Arrival-only guidance', 'STATIC PRODUCT COPY', 'TRUST'], ['Verification result', 'REAL API', 'SYSTEM FEEDBACK']],
    actions: ['Verify and start work', 'Cancel'], user_goal: 'Verify the customer’s code before service begins.',
    required: [], useful: ['Expired/invalid-code retry guidance from backend'],
    do_not_add: ['The customer OTP itself or any ability to bypass verification'], next: 'Keep the reason and result of OTP verification explicit.',
  }),
  screen('Provider', 'Work In Progress', 'STATE', '/provider/active-job', 'mobile/lib/features/provider/provider_jobs_screen.dart', {
    reachable: 'CONDITIONAL', status: 'MOSTLY COMPLETE', completeness: 74,
    current: [['In-progress status', 'REAL API', 'PROGRESS'], ['Work summary', 'REAL API', 'SERVICE DETAILS'], ['Completion/cancellation controls when allowed', 'REAL API', 'ACTION']],
    actions: ['Complete work', 'Cancel job if permitted'], user_goal: 'Finish or safely escalate an active service.',
    required: ['Explicit completion condition and outcome'], useful: ['Support escalation entry'], next: 'Make the end-of-work transition unambiguous.',
  }),
  screen('Provider', 'Job History', 'TAB', '/provider/history', 'mobile/lib/features/provider/provider_jobs_screen.dart', {
    status: 'MOSTLY COMPLETE', completeness: 74,
    current: [['Previous job status', 'REAL API', 'PROGRESS'], ['Service/request summary', 'REAL API', 'SERVICE DETAILS'], ['Short job reference/date', 'DERIVED', 'AUDIT']],
    actions: ['Open historical job'], user_goal: 'Review completed or cancelled assigned jobs.',
    required: ['Clear completed/cancelled grouping'], useful: ['Human-readable locality when safely available'], next: 'Sort status and date context ahead of opaque references.',
  }),
  screen('Provider', 'Provider Profile', 'TAB', '/provider/profile', 'mobile/lib/features/provider/provider_onboarding_screen.dart', {
    status: 'PARTIAL', density: 'UNDER-INFORMATIVE', completeness: 62,
    current: [['Verification/application state', 'REAL API', 'STATUS'], ['Professional profile summary', 'REAL API', 'IDENTITY']],
    actions: ['Continue profile setup', 'Open support', 'Sign out'], user_goal: 'Understand verification, services, and service-area readiness.',
    required: ['Verified status, selected services, service-area saved state, and document status'],
    useful: ['Last reviewed time'], do_not_add: ['Exact coordinate or private document content'],
    next: 'Consolidate the verified profile, skills, service area, and document state in one account summary.',
  }),
  screen('Admin', 'Admin Login', 'SCREEN', '/login', 'admin/src/app/login/page.tsx', {
    status: 'COMPLETE', completeness: 76, clarity: 83,
    current: [['Staff authentication inputs', 'LOCAL STATE', 'ACCOUNT'], ['Authentication result', 'REAL API', 'SYSTEM FEEDBACK']],
    actions: ['Sign in'], user_goal: 'Access only the authorized administrative workspace.',
    required: ['Clear role/authorization failure guidance'], next: 'Keep staff sign-in separate from customer/provider entry points.',
  }),
  screen('Admin', 'Overview', 'SCREEN', '/', 'admin/src/app/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 77, status_awareness: 80,
    current: [['Role-aware operations summary', 'REAL API', 'ADMIN OPERATIONS'], ['Operational booking metrics', 'REAL API', 'STATUS'], ['Quick module links', 'LOCAL STATE', 'NAVIGATION']],
    actions: ['Open authorized operational module'], user_goal: 'See what needs attention and open the right operations workspace.',
    required: ['Verification/support queue attention counts only where API data is available'], useful: ['Operational trend explanation'],
    do_not_add: ['Revenue, payment, ratings, or customer PII not needed for operations'], next: 'Keep urgent operational exceptions above aggregate counts.',
    screenshot: 'screenshots/admin-smoke-test.png',
  }),
  screen('Admin', 'Users', 'SCREEN', '/users', 'admin/src/app/users/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 82,
    current: [['User display context and role', 'REAL API', 'ADMIN OPERATIONS'], ['Account status and creation date', 'REAL API', 'STATUS'], ['Short user reference', 'DERIVED', 'AUDIT']],
    actions: ['Search users', 'Open user detail'], user_goal: 'Find an authorized account and inspect its operational context.',
    required: [], useful: ['Filters for status and role when backend supports them'], next: 'Keep the opaque user ID secondary to identity and status.',
  }),
  screen('Admin', 'User Detail', 'SCREEN', '/users/:userId', 'admin/src/app/users/[userId]/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 76,
    current: [['Account identity/status/roles', 'REAL API', 'ADMIN OPERATIONS'], ['Created date and audit reference', 'REAL API', 'AUDIT']],
    actions: ['Return to users'], user_goal: 'Understand the user’s authorized operational account context.',
    required: ['Related bookings/support/provider profile only when role and API allow it'], useful: ['Status-change audit trail if exposed'],
    do_not_add: ['Credentials, tokens, or unnecessary personal information'], next: 'Add related operational context only through authorized backend relationships.',
  }),
  screen('Admin', 'Provider Applications', 'SCREEN', '/providers', 'admin/src/app/providers/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 81,
    current: [['Provider identity and application state', 'REAL API', 'ADMIN OPERATIONS'], ['Updated date and short reference', 'REAL API', 'AUDIT'], ['Review availability', 'DERIVED', 'ACTION']],
    actions: ['Search/filter applications', 'Open review'], user_goal: 'Find a provider application that needs review.',
    required: [], useful: ['Reviewer/claim state if returned by API'], next: 'Use clear review-state labels instead of backend enum names.',
  }),
  screen('Admin', 'Provider Review Detail', 'SCREEN', '/providers/:applicationId', 'admin/src/app/providers/[applicationId]/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 78,
    current: [['Application profile and verification status', 'REAL API', 'ADMIN OPERATIONS'], ['Private document metadata/action access', 'REAL API', 'AUDIT'], ['Allowed review actions', 'REAL API', 'ACTION']],
    actions: ['Claim review', 'Approve', 'Reject', 'Request resubmission'], user_goal: 'Make an authorized provider-verification decision.',
    required: ['Decision rationale context and concurrency/claim state'], useful: ['Clear document review state'],
    do_not_add: ['Publicly shareable document URLs or document content beyond need-to-review'], next: 'Keep decision controls and their audit consequences clear.',
  }),
  screen('Admin', 'Services', 'SCREEN', '/services', 'admin/src/app/services/page.tsx', {
    status: 'PARTIAL', density: 'PLACEHOLDER-LIKE', completeness: 55,
    current: [['Service catalog workspace context', 'STATIC PRODUCT COPY', 'ADMIN OPERATIONS']],
    actions: ['View authorized catalog workspace'], user_goal: 'Manage service categories when authorization and data are available.',
    required: ['Authoritative service category list, active status, and permitted management actions'],
    useful: ['Usage-safe category metadata'], next: 'Replace the shell state with API-backed catalog context before adding controls.',
  }),
  screen('Admin', 'Bookings', 'SCREEN', '/bookings', 'admin/src/app/bookings/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 82,
    current: [['Service, lifecycle status, customer/provider context', 'REAL API', 'ADMIN OPERATIONS'], ['Updated time and short booking reference', 'REAL API', 'AUDIT']],
    actions: ['Search/filter bookings', 'Open booking detail'], user_goal: 'Find an operational booking and identify its status.',
    required: [], useful: ['Clear exception/cancellation reason when returned'], next: 'Sort action-driving status ahead of raw references.',
  }),
  screen('Admin', 'Booking Detail', 'SCREEN', '/bookings/:bookingId', 'admin/src/app/bookings/[bookingId]/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 82,
    current: [['Service, issue, lifecycle, and parties', 'REAL API', 'ADMIN OPERATIONS'], ['Timestamps and secondary full reference', 'REAL API', 'AUDIT'], ['Allowed administrative cancellation', 'REAL API', 'ACTION']],
    actions: ['Cancel when authorized', 'Return to bookings'], user_goal: 'Understand the complete lifecycle and execute only allowed operations.',
    required: ['Audit timeline only if supplied by backend'], useful: ['Clear cancellation reason display'],
    do_not_add: ['Customer OTP, provider documents, or unrelated personal data'], next: 'Keep allowed actions next to the lifecycle state and audit impact.',
  }),
  screen('Admin', 'Support Cases', 'SCREEN', '/support', 'admin/src/app/support/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 76,
    current: [['Category, description preview, state, and short reference', 'REAL API', 'SUPPORT'], ['Created time and target context', 'REAL API', 'STATUS']],
    actions: ['Search support cases', 'Open case detail'], user_goal: 'Find a case requiring an authorized support response.',
    required: ['Assignee/escalation state when exposed by backend'], useful: ['Related booking short reference'], next: 'Prioritize open/escalated cases above completed cases.',
  }),
  screen('Admin', 'Support Case Detail', 'SCREEN', '/support/:complaintId', 'admin/src/app/support/[complaintId]/page.tsx', {
    status: 'PARTIAL', density: 'UNDER-INFORMATIVE', completeness: 61,
    current: [['Case category, description, and primary state', 'REAL API', 'SUPPORT']],
    actions: ['Return to support list'], user_goal: 'Understand the support report and authorized next action.',
    required: ['Created time, reporter-safe context, assignee/escalation state, and related booking reference when authorized'],
    useful: ['Audit timeline from backend'], next: 'Add case ownership and escalation context before broadening the UI.',
  }),
  screen('Admin', 'Analytics', 'SCREEN', '/analytics', 'admin/src/app/analytics/page.tsx', {
    status: 'MOSTLY COMPLETE', completeness: 74,
    current: [['Privacy-safe operational booking metrics', 'REAL API', 'ADMIN OPERATIONS'], ['Role-limited analytics access', 'LOCAL STATE', 'TRUST']],
    actions: ['Review operational metrics'], user_goal: 'Understand operational health without exposing financial or rating data.',
    required: ['Metric definitions and data freshness when backend exposes them'], useful: ['Filter/state breakdowns based on available analytics'],
    do_not_add: ['Payments, revenue, ratings, reviews, or unnecessary personal data'], next: 'Label every metric’s operational meaning and timeframe.',
  }),
  screen('Admin', 'Access', 'STATE', '/access', 'admin/src/components/admin-shell.tsx', {
    reachable: 'CONDITIONAL', status: 'PLACEHOLDER', density: 'PLACEHOLDER-LIKE', completeness: 35,
    current: [['Disabled Access navigation entry', 'LOCAL STATE', 'NAVIGATION']],
    actions: [], user_goal: 'Understand whether an access-management module is available.',
    required: ['Either an authorized access-management screen or a clear unavailable state'],
    do_not_add: ['A non-functional primary action'], next: 'Keep disabled navigation out of the primary path until the module exists.',
  }),
];

const informationElements = screens.flatMap((item) => item.current_information.map((element) => ({ screen_id: item.id, role: item.role, ...element })));
const topGaps = [
  ['P0', 'Provider', 'Incoming Requests', 'Decision-critical request context is thin.', 'Providers may accept without clear service/location/urgency context.', 'Authorized service, issue, distance/locality, urgency, acceptance window', 'NOT VERIFIED', 'MEDIUM'],
  ['P0', 'Provider', 'Provider Profile', 'Verification readiness is fragmented.', 'A provider may not know exactly what blocks eligibility.', 'Unified verified/skills/service-area/documents summary', 'AVAILABLE NOW', 'MEDIUM'],
  ['P0', 'Customer', 'Complaint Detail', 'Case status lacks enough context.', 'Customers cannot tell whether support is acting.', 'Created time and authoritative case status', 'AVAILABLE NOW', 'SMALL'],
  ['P1', 'Customer', 'Home and Service Discovery', 'Active job context can be overshadowed by discovery.', 'Customers with work in progress need a faster next step.', 'Active booking status and tracking shortcut', 'AVAILABLE NOW', 'SMALL'],
  ['P1', 'Customer', 'Live Tracking', 'Provider identity/contact requires an explicit availability state.', 'Customers need trustworthy context, but disclosure must be authorized.', 'Provider identity/contact only after assignment and backend authorization', 'BACKEND CHANGE REQUIRED', 'MEDIUM'],
  ['P1', 'Provider', 'Assigned Job', 'Destination and distance visibility needs explicit authority checks.', 'Providers need route context to act safely.', 'Customer-safe locality/distance after assignment', 'NOT VERIFIED', 'MEDIUM'],
  ['P1', 'Admin', 'Overview', 'Attention queue context is incomplete.', 'Operations staff need to prioritize verification and support work.', 'Authorized queue counts and exception indicators', 'AVAILABLE NOW', 'MEDIUM'],
  ['P1', 'Admin', 'Support Case Detail', 'No assignee/escalation context.', 'Support operations cannot reliably coordinate the next owner.', 'Assignee, escalation, timestamps, related booking reference', 'BACKEND CHANGE REQUIRED', 'LARGE'],
  ['P1', 'Admin', 'Services', 'Catalog workspace is placeholder-like.', 'Catalog managers lack actionable category context.', 'Service list, active state, permitted actions', 'BACKEND CHANGE REQUIRED', 'LARGE'],
  ['P2', 'Customer', 'Bookings', 'Active and historical records need stronger grouping.', 'Users scan lifecycle state before history.', 'Active/completed/cancelled grouping', 'AVAILABLE NOW', 'SMALL'],
  ['P2', 'Provider', 'Job History', 'History lacks readable location/date context.', 'Providers need fast recall without raw IDs.', 'Safe locality and completed/cancelled grouping', 'NOT VERIFIED', 'MEDIUM'],
  ['P2', 'Admin', 'Users', 'Role/status filtering is limited.', 'Large user populations need faster operational lookup.', 'Role/status filters', 'BACKEND CHANGE REQUIRED', 'MEDIUM'],
  ['P2', 'Customer', 'Email Verification', 'Code expiry is not shown when it could influence the next action.', 'A customer may retry an expired code without understanding why.', 'Authoritative expiry or resend availability state', 'BACKEND CHANGE REQUIRED', 'SMALL'],
  ['P2', 'Customer', 'Profile', 'Saved-state feedback can be more explicit.', 'Customers need confidence that the small profile update persisted.', 'Last saved confirmation', 'DERIVABLE NOW', 'SMALL'],
  ['P2', 'Customer', 'Service Completion', 'Completion state has limited service context.', 'Customers need confirmation plus a safe support path.', 'Completion timestamp and authorized provider/service context', 'NOT VERIFIED', 'MEDIUM'],
  ['P2', 'Provider', 'Provider Dashboard', 'Schedule and assigned work are not summarized together.', 'Providers may miss the next operational priority.', 'Assigned-work summary beside availability/schedule', 'AVAILABLE NOW', 'SMALL'],
  ['P2', 'Provider', 'Identity Documents', 'Document state is generic.', 'Providers cannot tell exactly what is approved, pending, or needs resubmission.', 'Per-document review state and safe resubmission reason', 'AVAILABLE NOW', 'MEDIUM'],
  ['P2', 'Provider', 'Work In Progress', 'Completion outcome is not described as a distinct end state.', 'Providers need clear closure criteria and a support fallback.', 'Completion condition and authorized support escalation', 'NOT VERIFIED', 'SMALL'],
  ['P2', 'Admin', 'Provider Review Detail', 'Review claim/concurrency context needs stronger visibility.', 'Two reviewers can otherwise misunderstand who owns the decision.', 'Review claim state and expected-version feedback', 'AVAILABLE NOW', 'SMALL'],
  ['P3', 'Admin', 'Analytics', 'Metric freshness and definitions are implicit.', 'Operations staff can misread a metric without its window/context.', 'Metric timeframe and freshness label', 'BACKEND CHANGE REQUIRED', 'MEDIUM'],
];

for (const row of topGaps) {
  const [priority, role, screenName, problem, why_it_matters, recommended_information, backend_data, implementation_size] = row;
  const target = screens.find((item) => item.role === role && item.name === screenName);
  if (target) target.priority = priority;
}

const count = (predicate) => screens.filter(predicate).length;
const average = (field) => Math.round(screens.reduce((sum, item) => sum + item.scores[field], 0) / screens.length);
const roleSummary = Object.fromEntries(['Customer', 'Provider', 'Admin'].map((role) => {
  const entries = screens.filter((item) => item.role === role);
  return [role.toLowerCase(), {
    screens_audited: entries.length,
    balanced: entries.filter((item) => item.density === 'BALANCED').length,
    needs_more_info: entries.filter((item) => item.density === 'UNDER-INFORMATIVE' || item.density === 'PLACEHOLDER-LIKE').length,
    too_technical: entries.filter((item) => item.density === 'TOO TECHNICAL').length,
    top_gaps: topGaps.filter((gap) => gap[1] === role).slice(0, 5).map((gap) => gap[3]),
  }];
}));

function recommendationsFor(role) {
  const fromGaps = topGaps
    .filter((gap) => gap[1] === role)
    .map((gap) => ({ priority: gap[0], screen: gap[2], recommendation: gap[5], availability: gap[6] }));
  const fallback = screens
    .filter((item) => item.role === role)
    .flatMap((item) => item.missing_information.useful.map((recommendation) => ({
      priority: 'P3', screen: item.name, recommendation, availability: 'NOT VERIFIED',
    })));
  return [...fromGaps, ...fallback].slice(0, 10);
}

const report = {
  summary: {
    generated_at: new Date().toISOString(),
    audit_method: 'Static implementation audit: UI widgets, controllers, API/realtime contracts, navigation, authorization boundaries, and existing report screenshots. No runtime screenshots were fabricated.',
    total_ux_items: screens.length,
    customer_screens: count((item) => item.role === 'Customer'),
    provider_screens: count((item) => item.role === 'Provider'),
    admin_screens: count((item) => item.role === 'Admin'),
    classifications: {
      balanced: count((item) => item.density === 'BALANCED'),
      under_informative: count((item) => item.density === 'UNDER-INFORMATIVE'),
      overloaded: count((item) => item.density === 'OVERLOADED'),
      too_technical: count((item) => item.density === 'TOO TECHNICAL'),
      placeholder_like: count((item) => item.density === 'PLACEHOLDER-LIKE'),
      not_verified: count((item) => item.current_status === 'NOT VERIFIED'),
    },
    averages: {
      information_completeness: average('completeness'),
      user_clarity: average('clarity'),
      next_step_clarity: average('next_step'),
      technical_noise_cleanliness: average('technical_noise'),
      privacy_appropriateness: average('privacy'),
    },
  },
  roles: roleSummary,
  screens,
  information_elements: informationElements,
  actions: screens.flatMap((item) => item.actions.map((action) => ({ screen_id: item.id, role: item.role, action }))),
  missing_information: screens.map((item) => ({ screen_id: item.id, ...item.missing_information })),
  redundancy: [
    { item: 'Opaque booking/user identifiers', finding: 'KEEP SECONDARY', rationale: 'Short human references should lead; full IDs belong in audit/reference disclosure.' },
    { item: 'Booking status across list/detail/tracking', finding: 'KEEP, but tailor to the task', rationale: 'A brief status is necessary at each step; lifecycle explanations should not be repeated verbatim.' },
    { item: 'OTP guidance', finding: 'MERGE', rationale: 'Show full safety guidance at tracking/OTP time; use only a short reminder elsewhere.' },
  ],
  technical_noise: [
    { item: 'UUIDs and opaque IDs', classification: 'KEEP SECONDARY', replacement: 'Use short Booking/Case/User references as primary labels.' },
    { item: 'Backend lifecycle enums', classification: 'REPLACE WITH HUMAN LABEL', replacement: 'Use labels such as Provider is on the way and Service completed.' },
    { item: 'Fixture/local/synthetic language', classification: 'DEBUG ONLY', replacement: 'Do not surface in customer/provider/admin product UI.' },
  ],
  privacy_findings: [
    { role: 'Customer', finding: 'Live provider location, identity, and contact information must remain conditional on assignment and current booking authorization.' },
    { role: 'Provider', finding: 'Customer-safe locality/destination is appropriate only for an assigned job; private contact, other jobs, and OTP must not be exposed early.' },
    { role: 'Admin', finding: 'Operational views need minimum necessary data, role authorization, private document controls, and audit-first secondary IDs.' },
  ],
  top_gaps: topGaps.map(([priority, role, screen, problem, why_it_matters, recommended_information, backend_data, implementation_size]) => ({ priority, role, screen, problem, why_it_matters, recommended_information, backend_data, implementation_size })),
  customer_recommendations: recommendationsFor('Customer'),
  provider_recommendations: recommendationsFor('Provider'),
  admin_recommendations: recommendationsFor('Admin'),
  final_verdict: {
    customer_understands_service_journey: 'MOSTLY',
    provider_understands_current_job_and_next_legal_action: 'MOSTLY',
    admin_has_enough_operational_context: 'MOSTLY',
    technical_ids_dominate_any_screens: 'NO',
    screens_need_more_information_before_production: 'YES',
    screens_are_overloaded: 'NO',
  },
};

const safe = (value) => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const json = JSON.stringify(report, null, 2);
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FixNow Information Architecture Audit</title>
<style>
:root{--bg:#081020;--surface:#14213d;--surface2:#1b2b4b;--ink:#f7f7fa;--muted:#b9c4dc;--blue:#4e8cff;--green:#32bd80;--gold:#f59e0b;--red:#ff6b6b;--border:#435579}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 Inter,ui-sans-serif,system-ui,sans-serif}.shell{display:grid;grid-template-columns:250px 1fr;min-height:100vh}.side{position:sticky;top:0;height:100vh;padding:28px 18px;border-right:1px solid var(--border);background:#0b1630}.brand{font-size:22px;font-weight:800}.brand span{color:var(--blue)}.side p{color:var(--muted);font-size:13px}.filters{display:grid;gap:10px;margin-top:28px}.filter-label{font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:var(--muted)}input,select{width:100%;border:1px solid var(--border);border-radius:10px;background:var(--surface);color:var(--ink);padding:10px}.legend{margin-top:28px;display:grid;gap:8px;color:var(--muted);font-size:12px}.content{max-width:1440px;padding:40px 44px 80px}.eyebrow{color:var(--blue);font-weight:800;letter-spacing:.1em;text-transform:uppercase;font-size:12px}h1{font-size:clamp(32px,5vw,58px);line-height:1.05;margin:8px 0 12px}h2{font-size:24px;margin:0 0 14px}h3{font-size:18px;margin:0 0 8px}.lead{max-width:850px;color:var(--muted);font-size:17px}.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin:28px 0}.metric,.card{border:1px solid var(--border);background:linear-gradient(135deg,var(--surface),#101d37);border-radius:16px;padding:18px}.metric strong{display:block;font-size:30px}.metric span{color:var(--muted);font-size:13px}.section{margin-top:44px}.role-grid,.gap-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.chip{display:inline-flex;padding:3px 8px;border-radius:999px;background:#263d6a;color:#dce7ff;font-weight:700;font-size:11px}.chip[data-tone="P0"]{background:#642a36;color:#ffe5e7}.chip[data-tone="P1"]{background:#684d16;color:#fff1c7}.chip[data-tone="P2"]{background:#203c63}.scores{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin:15px 0}.score{padding:7px;border-radius:8px;background:#0e1930;color:var(--muted);font-size:11px}.score b{display:block;color:var(--ink);font-size:15px}.table-wrap{overflow:auto;border:1px solid var(--border);border-radius:16px}table{width:100%;border-collapse:collapse;min-width:1000px;background:var(--surface)}th,td{padding:12px;border-bottom:1px solid #30415f;vertical-align:top;text-align:left}th{position:sticky;top:0;background:#192a49;font-size:12px;color:#dbe5fc}td{color:#dfe6f5}.details{display:grid;gap:16px}.detail{border:1px solid var(--border);border-radius:16px;background:var(--surface);padding:20px}.detail summary{cursor:pointer;list-style:none}.detail summary::-webkit-details-marker{display:none}.detail .route{font:12px ui-monospace,SFMono-Regular,monospace;color:#aebddd}.info-list{display:grid;gap:7px;padding:0;list-style:none}.info-list li{padding:8px 10px;border-radius:8px;background:#0d1830}.info-list small{color:var(--muted)}.columns{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.shot{max-width:280px;border:1px solid var(--border);border-radius:10px;margin-top:10px}.muted{color:var(--muted)}.hidden{display:none}@media(max-width:980px){.shell{display:block}.side{position:static;height:auto;border-right:0;border-bottom:1px solid var(--border)}.filters{grid-template-columns:repeat(2,minmax(0,1fr))}.content{padding:28px 18px}.metrics,.role-grid,.gap-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:560px){.filters,.metrics,.role-grid,.gap-grid,.columns{grid-template-columns:1fr}.scores{grid-template-columns:repeat(2,1fr)}}
</style></head><body><div class="shell"><aside class="side"><div class="brand">Fix<span>Now</span></div><p>Information architecture audit<br>Static code and contract review</p><div class="filters"><label><span class="filter-label">Search</span><input id="search" placeholder="Screen, route, gap"></label><label><span class="filter-label">Role</span><select id="role"><option value="">All roles</option><option>Customer</option><option>Provider</option><option>Admin</option></select></label><label><span class="filter-label">Status</span><select id="status"><option value="">All statuses</option><option>COMPLETE</option><option>MOSTLY COMPLETE</option><option>PARTIAL</option><option>PLACEHOLDER</option></select></label><label><span class="filter-label">Information density</span><select id="density"><option value="">All density</option><option>BALANCED</option><option>UNDER-INFORMATIVE</option><option>OVERLOADED</option><option>TOO TECHNICAL</option><option>PLACEHOLDER-LIKE</option></select></label><label><span class="filter-label">Priority</span><select id="priority"><option value="">All priorities</option><option>P0</option><option>P1</option><option>P2</option><option>P3</option></select></label></div><div class="legend"><b>Evidence policy</b><span>Existing screenshots are linked where available.</span><span>Missing screenshots are marked explicitly.</span><span>No runtime state or backend data was fabricated.</span></div></aside><main class="content"><p class="eyebrow">Full screen information architecture audit</p><h1>Make every next step obvious.</h1><p class="lead">A role-aware audit of current FixNow information, data sources, privacy boundaries, technical noise, and the smallest high-confidence improvements. This is a report only; it does not change product behavior.</p><section class="metrics" id="metrics"></section><section class="section"><h2>Role summary</h2><div class="role-grid" id="roles"></div></section><section class="section"><h2>Top 20 information gaps</h2><div class="gap-grid" id="gaps"></div></section><section class="section"><h2>Master screen matrix</h2><div class="table-wrap"><table><thead><tr><th>Role</th><th>Screen</th><th>Type / route</th><th>Status</th><th>Density</th><th>Completeness</th><th>Clarity</th><th>Next step</th><th>Noise</th><th>Privacy</th><th>Priority</th><th>Top missing information</th></tr></thead><tbody id="matrix"></tbody></table></div></section><section class="section"><h2>Screen detail cards</h2><div class="details" id="details"></div></section></main></div><script>const report=${json};const byId=id=>document.getElementById(id);const metric=(n,l)=>'<article class="metric"><strong>'+n+'</strong><span>'+l+'</span></article>';byId('metrics').innerHTML=[metric(report.summary.total_ux_items,'UX items audited'),metric(report.summary.customer_screens,'Customer items'),metric(report.summary.provider_screens,'Provider items'),metric(report.summary.admin_screens,'Admin items'),metric(report.summary.classifications.balanced,'Balanced'),metric(report.summary.classifications.under_informative,'Under-informative'),metric(report.summary.classifications.placeholder_like,'Placeholder-like'),metric(report.summary.averages.privacy_appropriateness+'%','Privacy appropriateness')].join('');byId('roles').innerHTML=Object.entries(report.roles).map(([role,x])=>'<article class="card"><span class="chip">'+role.toUpperCase()+'</span><h3>'+x.screens_audited+' items audited</h3><p class="muted">'+x.balanced+' balanced · '+x.needs_more_info+' need more information · '+x.too_technical+' too technical</p><ul class="info-list">'+x.top_gaps.map(g=>'<li>'+g+'</li>').join('')+'</ul></article>').join('');byId('gaps').innerHTML=report.top_gaps.map(g=>'<article class="card gap" data-role="'+g.role+'" data-priority="'+g.priority+'"><span class="chip" data-tone="'+g.priority+'">'+g.priority+'</span><h3>'+g.role+' · '+g.screen+'</h3><p>'+g.problem+'</p><p class="muted">'+g.recommended_information+' · '+g.backend_data+' · '+g.implementation_size+'</p></article>').join('');function list(xs){return xs.length?'<ul class="info-list">'+xs.map(x=>'<li>'+x+'</li>').join('')+'</ul>':'<p class="muted">None identified.</p>'}function render(){const q=byId('search').value.toLowerCase(),role=byId('role').value,status=byId('status').value,density=byId('density').value,priority=byId('priority').value;const rows=report.screens.filter(s=>(!role||s.role===role)&&(!status||s.current_status===status)&&(!density||s.density===density)&&(!priority||s.priority===priority)&&(!q||JSON.stringify(s).toLowerCase().includes(q)));byId('matrix').innerHTML=rows.map(s=>'<tr><td>'+s.role+'</td><td><b>'+s.name+'</b></td><td><span class="chip">'+s.type+'</span><br><small>'+s.route+'</small></td><td>'+s.current_status+'</td><td>'+s.density+'</td><td>'+s.scores.completeness+'%</td><td>'+s.scores.clarity+'%</td><td>'+s.scores.next_step+'%</td><td>'+s.scores.technical_noise+'%</td><td>'+s.scores.privacy+'%</td><td>'+ (s.priority||'—')+'</td><td>'+((s.missing_information.required[0])||'—')+'</td></tr>').join('');byId('details').innerHTML=rows.map(s=>'<details class="detail"><summary><span class="chip">'+s.role+' · '+s.type+'</span><h3>'+s.name+'</h3><p class="route">'+s.route+' · '+s.source+'</p><p>'+s.density+' — '+s.density_reason+'</p></summary><div class="scores">'+Object.entries(s.scores).map(([k,v])=>'<div class="score"><b>'+v+'%</b>'+k.replaceAll('_',' ')+'</div>').join('')+'</div><div class="columns"><div><h3>Current information</h3><ul class="info-list">'+s.current_information.map(i=>'<li><b>'+i.name+'</b><br><small>'+i.source+' · '+i.purpose+'</small></li>').join('')+'</ul><h3>Actions</h3>'+list(s.actions)+'</div><div><h3>Current user goal</h3><p>'+s.user_goal+'</p><h3>What is good</h3><p>'+s.good+'</p><h3>Top next improvement</h3><p>'+s.top_next_improvement+'</p></div></div><div class="columns"><div><h3>Required additions</h3>'+list(s.missing_information.required)+'<h3>Useful additions</h3>'+list(s.missing_information.useful)+'<h3>Optional additions</h3>'+list(s.missing_information.optional)+'</div><div><h3>More prominent</h3>'+list(s.questions.prominent)+'<h3>Secondary / collapsed</h3>'+list(s.questions.secondary)+'<h3>Hidden</h3>'+list(s.questions.hidden)+'<h3>Do not add / privacy</h3>'+list(s.missing_information.do_not_add)+'<h3>Recommended structure</h3>'+list(s.recommended_structure)+'<h3>Information boundaries</h3>'+list(s.questions.never_show)+'</div></div><h3>Screen evidence</h3>'+ (s.screenshot?'<img class="shot" src="'+s.screenshot+'" alt="Existing screenshot evidence for '+s.name+'">':'<p class="muted">SCREENSHOT NOT AVAILABLE</p>')+'</details>').join('');document.querySelectorAll('.gap').forEach(el=>el.classList.toggle('hidden',(!role&& !priority)?false:((role&&el.dataset.role!==role)||(priority&&el.dataset.priority!==priority))));}['search','role','status','density','priority'].forEach(id=>byId(id).addEventListener('input',render));render();</script></body></html>`;

fs.writeFileSync(jsonPath, `${json}\n`);
fs.writeFileSync(htmlPath, html);
console.log(`Wrote ${path.relative(process.cwd(), jsonPath)} and ${path.relative(process.cwd(), htmlPath)}`);

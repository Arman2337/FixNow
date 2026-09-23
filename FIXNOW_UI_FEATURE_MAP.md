# FixNow UI Feature Map & Structural Screen Coverage Checklist

This document is the mandatory screen-by-screen coverage checklist for the FixNow Stitch UI Redesign. Every documented screen, variant, modal, sheet, and dialog must be structurally reconstructed to match the corresponding Stitch HTML blueprint.

---

## 1. Customer Screens & Surfaces (Mobile)

| Screen / Flow | Stitch Blueprint Reference | Source File | Status |
| :--- | :--- | :--- | :--- |
| **Welcome & Brand Entry** | `FixNow_-_Welcome___Role_Selection.html` | `mobile/lib/auth/welcome_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Role Selection (Customer vs Pro)** | `FixNow_-_Welcome___Role_Selection.html` | `mobile/lib/auth/role_selection_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Customer Sign In & Register** | `FixNow_-_Customer_Sign_In___Register.html` | `mobile/lib/auth/auth_screen.dart` | `Complete (Stitch Reconstructed)` |
| **OTP Verification Challenge** | `FixNow_-_OTP_Verification_Challenge.html` | `mobile/lib/auth/verification_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Customer Service Discovery (Home)** | `FixNow_-_Customer_Service_Discovery.html` | `mobile/lib/features/services/service_discovery_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Sub-Service Catalog & Cart Itemizer**| `FixNow_-_Sub-Service_Catalog___Itemizer.html` | `mobile/lib/features/services/sub_service_catalog_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Service Request & Booking Options** | `FixNow_-_Service_Request___Booking.html` | `mobile/lib/features/bookings/service_request_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Address Selector Modal / Sheet** | `FixNow_-_Service_Request___Booking.html` | `mobile/lib/design_system/fix_address_selector.dart` | `Complete (Stitch Reconstructed)` |
| **Schedule Picker Sheet / Windows** | `FixNow_-_Service_Request___Booking.html` | `mobile/lib/design_system/fix_schedule_hours_sheet.dart` | `Complete (Stitch Reconstructed)` |
| **Provider Match Radar & Celebration** | `FixNow_-_Provider_Match_Celebration.html` | `mobile/lib/design_system/fix_accept_celebration.dart` | `Complete (Stitch Reconstructed)` |
| **Live Tracking & Security OTP** | `FixNow_-_Live_Tracking___Security_OTP.html` | `mobile/lib/features/tracking/booking_tracking_screen.dart` | `Complete (Stitch Reconstructed)` |
| **In-Booking Live Chat** | `FixNow_-_Booking_Live_Chat.html` | `mobile/lib/features/chat/booking_chat_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Active VoIP Audio Call** | `FixNow_-_Active_VoIP_Audio_Call.html` | `mobile/lib/features/call/booking_call_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Bookings Hub & History (Tabs)** | `FixNow_-_Bookings_Hub___History.html` | `mobile/lib/features/bookings/customer_bookings_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Booking Details & Timeline** | `FixNow_-_Bookings_Hub___History.html` | `mobile/lib/features/bookings/booking_detail_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Reschedule & Cancel Modal** | `FixNow_-_Reschedule___Cancel_Booking.html` | `mobile/lib/design_system/fix_reschedule_sheet.dart` | `Complete (Stitch Reconstructed)` |
| **GST Tax Invoice & Receipt** | `FixNow_-_GST_Tax_Invoice___Receipt.html` | `mobile/lib/features/payments/invoice_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Booking 5-Star Photo Review** | `FixNow_-_Booking_5-Star_Photo_Review.html` | `mobile/lib/features/ratings/booking_review_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Customer Profile & Settings** | `FixNow_-_Customer_Profile___Settings.html` | `mobile/lib/features/profile/customer_profile_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Customer Help & Support Hub** | `FixNow_-_Customer_Help___Support_Hub.html` | `mobile/lib/features/support/customer_help_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Disputes & Support Cases Hub** | `FixNow_-_Disputes___Support_Cases_Hub.html` | `mobile/lib/features/support/complaint_list_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Notification Center & Alerts** | `FixNow_-_Notification_Center___Alerts.html` | `mobile/lib/features/notifications/notification_center_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Emergency Priority SOS Flow** | `FixNow_-_Emergency_Hazards_Priority_SOS.html` | `mobile/lib/features/emergency/emergency_confirm_screen.dart` | `Complete (Stitch Reconstructed)` |
| **FixAI Problem Diagnostic** | `FixNow_-_AI_Multimodal_Problem_Diagnosis.html` | `mobile/lib/features/ai/ai_diagnostic_screen.dart` | `Complete (Stitch Reconstructed)` |

---

## 2. Provider Screens & Surfaces (Mobile)

| Screen / Flow | Stitch Blueprint Reference | Source File | Status |
| :--- | :--- | :--- | :--- |
| **Provider KYC Verification & Setup** | `FixNow_-_Provider_KYC_Verification.html` | `mobile/lib/features/provider/provider_onboarding_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Provider Active Job Cockpit** | `FixNow_-_Provider_Active_Job_Cockpit.html` | `mobile/lib/features/provider/provider_active_job_cockpit_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Provider Home Workspace** | `FixNow_-_Provider_Active_Job_Cockpit.html` | `mobile/lib/features/provider/provider_home_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Provider Jobs & Schedule Ledger** | `FixNow_-_Provider_Jobs___Schedule_Ledger.html` | `mobile/lib/features/provider/provider_jobs_screen.dart` | `Complete (Stitch Reconstructed)` |
| **Provider Earnings Ledger** | `FixNow_-_Provider_Earnings_Ledger.html` | `mobile/lib/features/provider/provider_earnings_screen.dart` | `Complete (Stitch Reconstructed)` |

---

## 3. Admin Web Portal Screens & Surfaces (Next.js)

| Screen / Flow | Stitch Blueprint Reference | Source File | Status |
| :--- | :--- | :--- | :--- |
| **Portal Staff Login** | `FixNow_Admin_-_Portal_Staff_Login.html` | `admin/src/app/login/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Operations Command Center (Bento)**| `FixNow_Admin_-_Operations_Command_Center.html` | `admin/src/app/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Booking Dispatches & SOS Radar** | `FixNow_Admin_-_Booking_Dispatches___SOS_Radar.html` | `admin/src/app/bookings/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Booking Dispatch Inspection** | `FixNow_Admin_-_Booking_Dispatches___SOS_Radar.html` | `admin/src/app/bookings/[bookingId]/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Categories & Surge Pricing Matrix** | `FixNow_Admin_-_Categories___Surge_Pricing.html` | `admin/src/app/services/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Provider KYC Verification Queue** | `FixNow_Admin_-_Provider_KYC_Verification.html` | `admin/src/app/providers/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Provider Document Inspection & Action**| `FixNow_Admin_-_Provider_KYC_Verification.html` | `admin/src/app/providers/[applicationId]/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Support Complaints & Escrow** | `FixNow_Admin_-_Support_Complaints___Escrow.html` | `admin/src/app/support/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Complaint Case Resolution & Chat** | `FixNow_Admin_-_Support_Complaints___Escrow.html` | `admin/src/app/support/[complaintId]/page.tsx` | `Complete (Stitch Reconstructed)` |
| **Trust & Safety Moderation** | `FixNow_Admin_-_Trust___Safety_Moderation.html` | `admin/src/app/trust/page.tsx` | `Complete (Stitch Reconstructed)` |
| **User & Customer Management** | `FixNow_Admin_-_Operations_Command_Center.html` | `admin/src/app/users/page.tsx` | `Complete (Stitch Reconstructed)` |

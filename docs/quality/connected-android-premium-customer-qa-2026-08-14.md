# FN-082 Connected Android QA

Date: 2026-08-14

Branch: `feat/customer-core-journey`

Device: A059, Android 16 (API 36), 1080 x 2392

## Coverage

- Installed the current debug APK over USB and forwarded local API port 3300.
- Visually inspected welcome, role selection, customer sign-in, and email verification on the physical device.
- Verified keyboard resize and scroll behavior on credential and OTP forms.
- Verified the current backend returns the server-resolved `customer` role and the app reaches the verification boundary.
- Exercised customer discovery, request, bookings, booking detail, profile, offline, empty, error, and responsive states through the Flutter widget suite.

## Findings and fixes

- Enabled cleartext traffic only in the Android debug manifest so a USB-attached development build can reach the local HTTP API. Production networking rules are unchanged.
- Confirmed an older backend process omitted the role field; rebuilt and ran the current branch against the isolated local test services.
- The booking detail intentionally does not display a fake map, ETA, provider, price, chat, or payment state when those values are absent from the API.

## Evidence handling

Screenshots were captured under the operating-system temporary directory and were not added to Git.

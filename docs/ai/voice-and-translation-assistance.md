# Voice input and translation assistance

FN-058 adds the customer-facing, assistive voice boundary to Ask FixNow AI. It does not approve a speech-recognition or translation vendor and does not enable external media or text processing.

## Current behavior

- The customer can choose **Speak your issue** without losing typed input.
- Recognition availability is checked before microphone permission is requested. When unavailable, FixNow keeps text entry available and explains the fallback.
- When a reviewed recognition adapter supplies a transcript, it is editable, shown back to the customer, and must be explicitly confirmed before it can enter the existing FN-057 recommendation request.
- The UI distinguishes listening, processing, permission denied, permanently denied, unavailable, and error states without exposing internal error codes.
- The default recognition gateway is unavailable by design. It records nothing, persists no audio, and makes no network call.
- The default translation gateway supports only English-to-English preservation. Other languages are truthfully unavailable until an approved backend-governed translation adapter exists.

## Privacy and retention

Raw audio is never stored. A transcript and any processing text exist only in the current screen state until the customer explicitly uses it or leaves the screen. The client does not send email, phone, name, location, address, booking/provider information, OTP, credentials, or audio to the AI recommendation endpoint.

No transcription or translation creates a booking, service request, provider assignment, match, or emergency dispatch. Confirmation only enables the existing FN-057 advisory request; the existing category and booking confirmations remain separate.

## Required release gate

Before production voice recognition or non-English translation can be enabled, product, privacy/legal, security, and operations must approve a provider and data-processing terms under ADR-0014. The selected adapter must be backend-governed, disabled by default, configured with supported languages, bounded by timeout/rate limits, validated with deterministic failure tests, and proven not to retain audio or text beyond the approved purpose. Flutter must never receive provider credentials or call an external provider directly.

Until that approval, `UnsupportedVoiceRecognitionGateway` and `LocalOnlyTranslationGateway` are the intentional safe defaults.

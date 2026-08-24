# Booking ratings and reviews

FN-054 adds one optional, plain-text customer review to an authoritative completed booking. The backend derives customer and provider identities from the booking; clients cannot submit either identifier. Database uniqueness and the transactional service path prevent duplicate reviews for the same booking.

Only the customer and assigned provider on that booking may read its review. Provider-facing reads use the label "Customer review" and never return the customer's email, phone, address, GPS, OTP, or session data. Review text is untrusted plain text and UI surfaces render it as text, never HTML.

Ratings are integer 1–5. Published reviews alone contribute to provider aggregates. A provider with no published reviews receives `{ "averageRating": null, "reviewCount": 0 }`, which clients must present as "No reviews yet" rather than `0.0`.

Reviews begin `PUBLISHED`. The durable `HIDDEN` and `FLAGGED` moderation states preserve the review record and remove non-published reviews from aggregates. Privileged moderation actions and their audit workflow are intentionally deferred to FN-055; no automatic penalties, matching changes, payment decisions, or provider suspensions are made from ratings.

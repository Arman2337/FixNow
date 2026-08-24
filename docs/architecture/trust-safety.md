# Trust and safety operations

FN-055 reuses the authoritative complaint lifecycle and adds advisory trust operations. A provider cancellation-frequency signal is emitted only when three or more cancellations occur in the preceding 30 days. It is keyed by provider, rule code, and evaluation-window date to prevent duplicate active signals. Its severity is `LOW`, and it never changes account status, verification, matching, bookings, or reviews automatically.

Only trust-and-safety reviewers and operations administrators may moderate a review or inspect/review internal signals. Review moderation requires a bounded reason and appends an immutable audit event. Hidden and flagged reviews do not contribute to published rating aggregates. Providers who dispute a review use the existing complaint path, retaining the original review and protected complaint reporter identity for human review.

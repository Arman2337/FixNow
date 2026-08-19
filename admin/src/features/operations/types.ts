export type ServiceCategory = { id: string; name: string; slug: string; description: string | null; displayOrder: number; isActive: boolean; isEmergency: boolean };
export type BookingStatus = "REQUESTED" | "ASSIGNED" | "EN_ROUTE" | "IN_PROGRESS" | "COMPLETED" | "CANCELLED";
export type BookingSummary = { id: string; customerId: string; providerId: string | null; serviceCategoryId: string; status: BookingStatus; description: string; scheduledAt: string | null; cancellationReason: string | null; version: number; createdAt: string; updatedAt: string };
export type BookingEvent = { id: string; actorUserId: string; fromStatus: BookingStatus | null; toStatus: BookingStatus; reason: string | null; bookingVersion: number; createdAt: string };
export type BookingDetail = BookingSummary & { events: readonly BookingEvent[] };
export type BookingPage = { items: readonly BookingSummary[]; nextCursor: string | null };
export type ComplaintStatus = 'OPEN' | 'IN_REVIEW' | 'ESCALATED' | 'RESOLVED' | 'CLOSED';
export type ComplaintEvidence = { id: string; uploadedBy: string; fileUrl: string; fileType: string; description?: string; createdAt: string; };
export type Complaint = { id: string; submitterId: string; targetRole: 'PROVIDER' | 'CUSTOMER' | 'PLATFORM'; targetId?: string; bookingId?: string; category: string; description: string; status: ComplaintStatus; resolutionNotes?: string; resolvedAt?: string; resolvedBy?: string; createdAt: string; updatedAt: string; evidence: ComplaintEvidence[]; };

export type UserDetail = { id: string; email: string; name: string; status: string; roles: string[]; createdAt: string; updatedAt: string; };
export type AnalyticsResponse = { bookings: { total: number; completed: number; cancelled: number; pending: number; }; providers: { total: number; active: number; verified: number; pendingVerification: number; }; services: { topCategories: { id: string; name: string; count: number }[]; }; emergencies: { activeRequests: number; totalRequests: number; }; };

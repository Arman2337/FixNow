import { managementRequest } from "../management-api";
import type { BookingDetail, BookingPage, ServiceCategory, Complaint, ComplaintStatus } from "./types";
export const listCategories = () => managementRequest<readonly ServiceCategory[]>("/admin/service-categories");
export const createCategory = (body: object) => managementRequest<ServiceCategory>("/admin/service-categories", { method: "POST", body: JSON.stringify(body) });
export const updateCategory = (id: string, body: object) => managementRequest<ServiceCategory>(`/admin/service-categories/${encodeURIComponent(id)}`, { method: "PUT", body: JSON.stringify(body) });
export const deleteCategory = (id: string) => managementRequest<void>(`/admin/service-categories/${encodeURIComponent(id)}`, { method: "DELETE" });
export function listBookings(search?: string, status?: string, cursor?: string) { const query = new URLSearchParams({ limit: "20" }); if (search) query.set("search", search); if (status) query.set("status", status); if (cursor) query.set("cursor", cursor); return managementRequest<BookingPage>(`/admin/bookings?${query}`); }
export const getBooking = (id: string) => managementRequest<BookingDetail>(`/admin/bookings/${encodeURIComponent(id)}`);
export const cancelBooking = (id: string, expectedVersion: number, reason: string) => managementRequest<BookingDetail>(`/admin/bookings/${encodeURIComponent(id)}/cancel`, { method: "POST", body: JSON.stringify({ expectedVersion, reason }) });
export const listComplaints = () => managementRequest<readonly Complaint[]>('/admin/complaints');
export const getComplaint = (id: string) => managementRequest<Complaint>(`/admin/complaints/${encodeURIComponent(id)}`);
export const updateComplaintStatus = (id: string, status: ComplaintStatus, resolutionNotes?: string) => managementRequest<Complaint>(`/admin/complaints/${encodeURIComponent(id)}/status`, { method: 'PATCH', body: JSON.stringify({ status, resolutionNotes }) });

export const getUser = (id: string) => managementRequest<import('./types').UserDetail>(`/admin/users/${encodeURIComponent(id)}`);
export const getAnalytics = () => managementRequest<import('./types').AnalyticsResponse>('/admin/analytics');

import { pageNumber as parsePageNumber } from "@/lib/format";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { deleteCategoryAction, saveCategoryAction } from "@/features/operations/actions";
import { listCategories } from "@/features/operations/api";
import { canMutateServices, hasPermission } from "@/auth/roles";

const field = "w-full py-2.5 px-3 rounded-xl border border-outline-variant/50 bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary transition-all disabled:opacity-60 disabled:cursor-not-allowed";

export default async function ServicesPage({
  searchParams,
}: {
  searchParams: Promise<{ result?: string; page?: string }>;
}) {
  const session = await getSession(); 
  if (session.state !== "authenticated") redirect("/login?reason=expired");

  if (!hasPermission(session.session.roles, "adminServicesRead")) {
    redirect("/unauthorized");
  }

  const canEdit = canMutateServices(session.session.roles);
  const params = await searchParams;
  const result = params.result;

  const pageNumber = parsePageNumber(params.page);
  const pageSize = 8;
  const categories = await requireManagementResult(await listCategories(pageSize + 1, (pageNumber - 1) * pageSize));
  const hasNextPage = categories.length > pageSize;
  const pagedCategories = categories.slice(0, pageSize);

  return (
    <AdminShell
      environment={env.appEnvironment}
      roles={session.session.roles}
      email={session.session.email}
      displayName={session.session.displayName}
      current="Categories & Pricing"
    >
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg max-w-5xl">
          
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-space-md">
            <div>
              <p className="font-label-sm uppercase tracking-wider text-primary font-bold">Catalog Operations</p>
              <h1 className="font-headline-lg text-headline-lg font-bold text-on-surface mt-1">Service Taxonomy</h1>
              <p className="font-body-md text-body-md text-on-surface-variant mt-2">Maintain the categories customers use to request help.</p>
            </div>
            <div className="flex items-center gap-3">
              {!canEdit && (
                <div className="px-3 py-1.5 rounded-lg bg-surface-container-high text-on-surface-variant font-label-sm font-semibold border border-outline-variant/30 flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-[16px]">visibility</span>
                  <span>Read-only Auditor View</span>
                </div>
              )}
              {result && (
                <div className="px-4 py-2 rounded-lg bg-surface-container-highest text-on-surface font-label-sm font-bold border border-outline-variant/30 shadow-sm">
                  Result: {result.replaceAll("-", " ")}
                </div>
              )}
            </div>
          </div>

          {canEdit ? (
            <section aria-labelledby="new-category" className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-lg shadow-sm">
              <h2 id="new-category" className="font-headline-sm text-headline-sm font-bold text-on-surface mb-space-md flex items-center gap-2">
                <span className="material-symbols-outlined text-primary">add_circle</span> Add Category
              </h2>
              <form action={saveCategoryAction} className="grid gap-space-md sm:grid-cols-2">
                <label className="flex flex-col gap-1.5">
                  <span className="font-label-sm font-semibold uppercase text-secondary">Name</span>
                  <input required name="name" maxLength={255} className={field}/>
                </label>
                <label className="flex flex-col gap-1.5">
                  <span className="font-label-sm font-semibold uppercase text-secondary">Slug</span>
                  <input required name="slug" maxLength={255} pattern="[a-z0-9-]+" className={field} placeholder="e.g. plumbing-repair"/>
                </label>
                <label className="sm:col-span-2 flex flex-col gap-1.5">
                  <span className="font-label-sm font-semibold uppercase text-secondary">Description</span>
                  <textarea name="description" className={`${field} min-h-[100px]`}/>
                </label>
                <label className="flex flex-col gap-1.5">
                  <span className="font-label-sm font-semibold uppercase text-secondary">Display Order</span>
                  <input required type="number" min="0" max="9999" defaultValue="0" name="displayOrder" className={field}/>
                </label>
                <label className="flex flex-col gap-1.5">
                  <span className="font-label-sm font-semibold uppercase text-secondary">Base Price (₹)</span>
                  <input type="number" min="0" max="10000" step="0.01" name="priceRupees" placeholder="Empty for price on request" className={field}/>
                </label>
                
                <div className="sm:col-span-2 flex flex-wrap items-center gap-6 p-4 rounded-xl bg-surface-container-low border border-outline-variant/30 mt-2">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" name="isActive" defaultChecked className="w-4 h-4 text-primary rounded border-outline focus:ring-primary"/>
                    <span className="font-label-md font-semibold text-on-surface">Active Status</span>
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" name="isEmergency" className="w-4 h-4 text-error rounded border-outline focus:ring-error"/>
                    <span className="font-label-md font-semibold text-error">Priority/Emergency Flag</span>
                  </label>
                </div>

                <div className="sm:col-span-2 flex justify-end mt-2">
                  <button className="px-6 py-2.5 rounded-xl bg-primary text-on-primary font-label-md font-bold shadow-sm hover:bg-primary-container transition-colors">
                    Create Category
                  </button>
                </div>
              </form>
            </section>
          ) : null}

          <section aria-label="Service categories" className="grid gap-space-lg">
            {pagedCategories.map((category) => (
              <article key={category.id} className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-lg shadow-sm hover:shadow-md transition-shadow relative overflow-hidden">
                {category.isEmergency && (
                  <div className="absolute top-0 right-0 px-3 py-1 bg-error text-on-error font-label-sm font-bold uppercase rounded-bl-xl shadow-sm">
                    Priority Category
                  </div>
                )}
                
                <form action={canEdit ? saveCategoryAction : undefined} className="grid gap-space-md sm:grid-cols-2">
                  <input type="hidden" name="id" value={category.id}/>
                  
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Name</span>
                    <input required disabled={!canEdit} name="name" defaultValue={category.name} className={field}/>
                  </label>
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Slug</span>
                    <input required disabled={!canEdit} name="slug" defaultValue={category.slug} pattern="[a-z0-9-]+" className={field}/>
                  </label>
                  <label className="sm:col-span-2 flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Description</span>
                    <textarea disabled={!canEdit} name="description" defaultValue={category.description ?? ""} className={`${field} min-h-[80px]`}/>
                  </label>
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Display Order</span>
                    <input disabled={!canEdit} type="number" min="0" max="9999" name="displayOrder" defaultValue={category.displayOrder} className={field}/>
                  </label>
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Base Price (₹)</span>
                    <div className="flex gap-2">
                      <input disabled={!canEdit} type="number" min="0" max="10000" step="0.01" name="priceRupees" defaultValue={category.pricing ? String(category.pricing.amountMinor / 100) : ""} placeholder="Price on request" aria-describedby={`current-price-${category.id}`} className={field}/>
                      {category.pricing && (
                        <span id={`current-price-${category.id}`} className="whitespace-nowrap flex items-center font-data-mono text-sm font-bold text-primary px-3 bg-primary/10 rounded-xl">
                          ₹{(category.pricing.amountMinor / 100).toFixed(2)}
                        </span>
                      )}
                    </div>
                    {canEdit && category.pricing && (
                      <label className="flex items-center gap-2 mt-1 cursor-pointer">
                        <input type="checkbox" name="clearPricing" className="w-3.5 h-3.5 text-secondary rounded border-outline"/>
                        <span className="font-label-sm text-secondary">Clear published price</span>
                      </label>
                    )}
                  </label>

                  <div className="sm:col-span-2 flex flex-wrap items-center justify-between gap-6 p-4 rounded-xl bg-surface-container-low border border-outline-variant/30 mt-2">
                    <div className="flex gap-6">
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input disabled={!canEdit} type="checkbox" name="isActive" defaultChecked={category.isActive} className="w-4 h-4 text-primary rounded border-outline focus:ring-primary"/>
                        <span className="font-label-md font-semibold text-on-surface">Active Status</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input disabled={!canEdit} type="checkbox" name="isEmergency" defaultChecked={category.isEmergency} className="w-4 h-4 text-error rounded border-outline focus:ring-error"/>
                        <span className="font-label-md font-semibold text-error">Priority/Emergency</span>
                      </label>
                    </div>
                    {canEdit ? (
                      <button className="px-6 py-2 rounded-xl bg-surface-container-high hover:bg-surface-container-highest text-on-surface font-label-md font-bold transition-colors">
                        Save Changes
                      </button>
                    ) : null}
                  </div>
                </form>

                {canEdit ? (
                  <form action={deleteCategoryAction} className="mt-4 flex flex-wrap items-center justify-end gap-4 pt-4 border-t border-outline-variant/30">
                    <input type="hidden" name="id" value={category.id}/>
                    <label className="flex items-center gap-2 text-sm text-secondary cursor-pointer">
                      <input required type="checkbox" name="confirmed" className="w-4 h-4 rounded text-error border-outline"/>
                      Confirm permanent removal
                    </label>
                    <button className="px-4 py-2 rounded-lg bg-error-container text-on-error-container font-label-sm font-bold hover:bg-error hover:text-on-error transition-colors">
                      Delete
                    </button>
                  </form>
                ) : null}
              </article>
            ))}
          </section>

          {(hasNextPage || pageNumber > 1) && (
            <div className="flex items-center justify-between border-t border-outline-variant/20 pt-4 mt-2">
              <div>
                {pageNumber > 1 ? (
                  <Link
                    href={`/services?page=${pageNumber - 1}`}
                    className="px-4 py-2 rounded-xl border border-outline-variant/40 bg-surface-container-low text-on-surface font-label-md text-sm font-semibold hover:bg-surface-container transition-colors inline-flex items-center gap-1"
                  >
                    <span className="material-symbols-outlined text-[16px]">arrow_back</span>
                    <span>Previous page</span>
                  </Link>
                ) : <div />}
              </div>
              <span className="font-body-sm text-sm text-on-surface-variant">Page {pageNumber}</span>
              <div>
                {hasNextPage ? (
                  <Link
                    href={`/services?page=${pageNumber + 1}`}
                    className="px-4 py-2 rounded-xl bg-primary text-on-primary font-label-md text-sm font-semibold hover:bg-primary/90 transition-colors inline-flex items-center gap-1"
                  >
                    <span>Next page</span>
                    <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
                  </Link>
                ) : <div />}
              </div>
            </div>
          )}

        </div>
      </div>
    </AdminShell>
  );
}

import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { deleteCategoryAction, saveCategoryAction } from "@/features/operations/actions";
import { listCategories } from "@/features/operations/api";

const field = "w-full py-2.5 px-3 rounded-xl border border-outline-variant/50 bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary transition-all";

export default async function ServicesPage({ searchParams }: { searchParams: Promise<{ result?: string }> }) {
  const session = await getSession(); 
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const categories = await requireManagementResult(await listCategories()); 
  const { result } = await searchParams;

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Categories & Pricing">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg max-w-5xl">
          
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-space-md">
            <div>
              <p className="font-label-sm uppercase tracking-wider text-primary font-bold">Catalog Operations</p>
              <h1 className="font-headline-lg text-headline-lg font-bold text-on-surface mt-1">Service Taxonomy</h1>
              <p className="font-body-md text-body-md text-on-surface-variant mt-2">Maintain the categories customers use to request help.</p>
            </div>
            {result && (
              <div className="px-4 py-2 rounded-lg bg-surface-container-highest text-on-surface font-label-sm font-bold border border-outline-variant/30 shadow-sm">
                Result: {result.replaceAll("-", " ")}
              </div>
            )}
          </div>

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

          <section aria-label="Service categories" className="grid gap-space-lg">
            {categories.map((category) => (
              <article key={category.id} className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-lg shadow-sm hover:shadow-md transition-shadow relative overflow-hidden">
                {category.isEmergency && (
                  <div className="absolute top-0 right-0 px-3 py-1 bg-error text-on-error font-label-sm font-bold uppercase rounded-bl-xl shadow-sm">
                    Priority Category
                  </div>
                )}
                
                <form action={saveCategoryAction} className="grid gap-space-md sm:grid-cols-2">
                  <input type="hidden" name="id" value={category.id}/>
                  
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Name</span>
                    <input required name="name" defaultValue={category.name} className={field}/>
                  </label>
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Slug</span>
                    <input required name="slug" defaultValue={category.slug} pattern="[a-z0-9-]+" className={field}/>
                  </label>
                  <label className="sm:col-span-2 flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Description</span>
                    <textarea name="description" defaultValue={category.description ?? ""} className={`${field} min-h-[80px]`}/>
                  </label>
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Display Order</span>
                    <input type="number" min="0" max="9999" name="displayOrder" defaultValue={category.displayOrder} className={field}/>
                  </label>
                  <label className="flex flex-col gap-1.5">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Base Price (₹)</span>
                    <div className="flex gap-2">
                      <input type="number" min="0" max="10000" step="0.01" name="priceRupees" defaultValue={category.pricing ? String(category.pricing.amountMinor / 100) : ""} placeholder="Price on request" aria-describedby={`current-price-${category.id}`} className={field}/>
                      {category.pricing && (
                        <span id={`current-price-${category.id}`} className="whitespace-nowrap flex items-center font-data-mono text-sm font-bold text-primary px-3 bg-primary/10 rounded-xl">
                          ₹{(category.pricing.amountMinor / 100).toFixed(2)}
                        </span>
                      )}
                    </div>
                    {category.pricing && (
                      <label className="flex items-center gap-2 mt-1 cursor-pointer">
                        <input type="checkbox" name="clearPricing" className="w-3.5 h-3.5 text-secondary rounded border-outline"/>
                        <span className="font-label-sm text-secondary">Clear published price</span>
                      </label>
                    )}
                  </label>

                  <div className="sm:col-span-2 flex flex-wrap items-center justify-between gap-6 p-4 rounded-xl bg-surface-container-low border border-outline-variant/30 mt-2">
                    <div className="flex gap-6">
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input type="checkbox" name="isActive" defaultChecked={category.isActive} className="w-4 h-4 text-primary rounded border-outline focus:ring-primary"/>
                        <span className="font-label-md font-semibold text-on-surface">Active Status</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input type="checkbox" name="isEmergency" defaultChecked={category.isEmergency} className="w-4 h-4 text-error rounded border-outline focus:ring-error"/>
                        <span className="font-label-md font-semibold text-error">Priority/Emergency</span>
                      </label>
                    </div>
                    <button className="px-6 py-2 rounded-xl bg-surface-container-high hover:bg-surface-container-highest text-on-surface font-label-md font-bold transition-colors">
                      Save Changes
                    </button>
                  </div>
                </form>

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
              </article>
            ))}
          </section>

        </div>
      </div>
    </AdminShell>
  );
}

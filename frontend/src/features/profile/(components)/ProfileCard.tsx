"use client";

import { useState, useEffect } from "react";
import { User, Mail, Phone, Building2, Shield, Pencil, X, Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { useProfile, useUpdateProfile } from "../(queries)/queries";

function Field({
  icon,
  label,
  value,
  mono,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex items-start gap-3 py-3">
      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-surface-container-low text-on-surface-variant">
        {icon}
      </div>
      <div className="min-w-0">
        <div className="font-mono text-[9px] font-bold uppercase tracking-widest text-on-surface-variant">
          {label}
        </div>
        <div className={cn("mt-0.5 text-sm text-on-surface", mono && "font-mono tabular-nums")}>
          {value || "—"}
        </div>
      </div>
    </div>
  );
}

function EditForm({
  profile,
  onCancel,
  onSuccess,
}: {
  profile: IProfileAttributes;
  onCancel: () => void;
  onSuccess: () => void;
}) {
  const update = useUpdateProfile();
  const [form, setForm] = useState({
    first_name: profile.first_name,
    last_name: profile.last_name,
    phone_number: profile.phone_number,
    email: profile.email,
  });

  const error = update.error
    ? ((update.error as { data?: IApiError }).data?.errors?.base?.[0] ??
      "Update failed. Please try again.")
    : null;

  function handleSubmit(e: { preventDefault(): void }) {
    e.preventDefault();
    update.mutate(
      { user: form },
      { onSuccess }
    );
  }

  const inputClass =
    "w-full rounded-lg border border-[#c7c4d8]/30 bg-surface-container-low px-3 py-2 text-sm text-on-surface outline-none transition-colors focus:border-brand-600 focus:ring-1 focus:ring-brand-600";
  const labelClass =
    "mb-1.5 block font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant";

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="rounded-lg bg-red-500/10 px-4 py-2.5 text-sm text-red-600">
          {error}
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className={labelClass}>First name</label>
          <input
            type="text"
            value={form.first_name}
            onChange={(e) => setForm((f) => ({ ...f, first_name: e.target.value }))}
            className={inputClass}
            required
          />
        </div>
        <div>
          <label className={labelClass}>Last name</label>
          <input
            type="text"
            value={form.last_name}
            onChange={(e) => setForm((f) => ({ ...f, last_name: e.target.value }))}
            className={inputClass}
            required
          />
        </div>
      </div>

      <div>
        <label className={labelClass}>Email</label>
        <input
          type="email"
          value={form.email}
          onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
          className={inputClass}
          required
        />
      </div>

      <div>
        <label className={labelClass}>Phone number</label>
        <input
          type="tel"
          value={form.phone_number}
          onChange={(e) => setForm((f) => ({ ...f, phone_number: e.target.value }))}
          className={inputClass}
          required
        />
      </div>

      <div className="flex items-center justify-end gap-2 pt-2">
        <button
          type="button"
          onClick={onCancel}
          className="inline-flex items-center gap-1.5 rounded-lg px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-on-surface-variant transition-colors hover:bg-surface-container-low"
        >
          <X className="h-3.5 w-3.5" />
          Cancel
        </button>
        <button
          type="submit"
          disabled={update.isPending}
          className="inline-flex items-center gap-1.5 rounded-lg bg-brand-600 px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 active:translate-y-px disabled:opacity-50"
        >
          <Check className="h-3.5 w-3.5" />
          {update.isPending ? "Saving..." : "Save changes"}
        </button>
      </div>
    </form>
  );
}

function SkeletonProfile() {
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        <div className="h-16 w-16 animate-pulse rounded-2xl bg-surface-container-low" />
        <div className="space-y-2">
          <div className="h-5 w-40 animate-pulse rounded bg-surface-container-low" />
          <div className="h-3 w-24 animate-pulse rounded bg-surface-container-low" />
        </div>
      </div>
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="flex items-center gap-3 py-3">
          <div className="h-8 w-8 animate-pulse rounded-lg bg-surface-container-low" />
          <div className="space-y-1.5">
            <div className="h-2 w-16 animate-pulse rounded bg-surface-container-low" />
            <div className="h-3 w-32 animate-pulse rounded bg-surface-container-low" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function ProfileCard() {
  const { data, isLoading } = useProfile();
  const [editing, setEditing] = useState(false);

  const profile = data?.data?.attributes;

  if (isLoading || !profile) {
    return (
      <div className="rounded-2xl bg-surface-container-lowest p-6">
        <SkeletonProfile />
      </div>
    );
  }

  const initials = `${profile.first_name[0] ?? ""}${profile.last_name[0] ?? ""}`.toUpperCase();

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
          Account
        </p>
        <h1 className="text-2xl font-black tracking-tight text-on-surface">Profile</h1>
      </div>

      <div className="rounded-2xl bg-surface-container-lowest p-6">
        {/* Avatar + name */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-brand-600 text-lg font-bold text-white">
              {initials}
            </div>
            <div>
              <h2 className="text-lg font-bold text-on-surface">
                {profile.first_name} {profile.last_name}
              </h2>
              <div className="flex items-center gap-2 text-xs text-on-surface-variant">
                <span className="rounded bg-brand-600/10 px-1.5 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-brand-600">
                  {profile.role_name}
                </span>
                {profile.company_name && (
                  <span className="text-on-surface-variant">at {profile.company_name}</span>
                )}
              </div>
            </div>
          </div>

          {!editing && (
            <button
              onClick={() => setEditing(true)}
              className="inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant transition-colors hover:bg-surface-container-low"
            >
              <Pencil className="h-3 w-3" />
              Edit
            </button>
          )}
        </div>

        {editing ? (
          <EditForm
            profile={profile}
            onCancel={() => setEditing(false)}
            onSuccess={() => setEditing(false)}
          />
        ) : (
          <div className="divide-y divide-[#c7c4d8]/15">
            <Field icon={<Mail className="h-4 w-4" />} label="Email" value={profile.email} />
            <Field icon={<Phone className="h-4 w-4" />} label="Phone" value={profile.phone_number} mono />
            <Field icon={<Building2 className="h-4 w-4" />} label="Company" value={profile.company_name} />
            <Field icon={<Shield className="h-4 w-4" />} label="Role" value={profile.role_name} />
            <Field icon={<User className="h-4 w-4" />} label="Member since" value={new Date(profile.created_at).toLocaleDateString("en-US", { month: "long", year: "numeric" })} />
          </div>
        )}
      </div>
    </div>
  );
}

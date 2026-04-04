"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SearchableSelect } from "@/components/ui/searchable-select";
import { useRegisterFacade } from "../(hooks)/useAuthFacade";

export function RegisterForm() {
  const { register, isPending, error, companies, companiesLoading, onCompanySearch } =
    useRegisterFacade();
  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    phone_number: "",
    email: "",
    password: "",
    company_id: 0,
  });

  const updateField = (field: string, value: string | number) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = (e: { preventDefault(): void }) => {
    e.preventDefault();
    register({ user: form });
  };

  const inputClass =
    "h-10 border-[#c7c4d8]/30 bg-surface-container-low focus-visible:ring-brand-600";
  const labelClass =
    "font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant";

  return (
    <div className="w-full max-w-sm">
      <div className="mb-8">
        <h1 className="text-2xl font-black tracking-tight text-on-surface">
          Create an account
        </h1>
        <p className="mt-2 text-sm text-on-surface-variant">
          Join your company&apos;s shuttle network
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        {error && (
          <div className="rounded-lg border border-destructive/20 bg-destructive/5 p-3 font-mono text-xs text-destructive">
            {error}
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <Label htmlFor="first_name" className={labelClass}>
              First name
            </Label>
            <Input
              id="first_name"
              placeholder="Sarah"
              value={form.first_name}
              onChange={(e) => updateField("first_name", e.target.value)}
              required
              className={inputClass}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="last_name" className={labelClass}>
              Last name
            </Label>
            <Input
              id="last_name"
              placeholder="Mendez"
              value={form.last_name}
              onChange={(e) => updateField("last_name", e.target.value)}
              required
              className={inputClass}
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="reg_email" className={labelClass}>
            Email
          </Label>
          <Input
            id="reg_email"
            type="email"
            placeholder="you@company.com"
            value={form.email}
            onChange={(e) => updateField("email", e.target.value)}
            required
            autoComplete="email"
            className={inputClass}
          />
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="phone" className={labelClass}>
            Phone number
          </Label>
          <Input
            id="phone"
            type="tel"
            placeholder="+91 9876543210"
            value={form.phone_number}
            onChange={(e) => updateField("phone_number", e.target.value)}
            required
            className={inputClass}
          />
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="company" className={labelClass}>
            Company
          </Label>
          <SearchableSelect
            options={companies.map((c) => ({ value: c.id, label: c.name }))}
            value={form.company_id}
            onValueChange={(val) => updateField("company_id", Number(val))}
            onSearchChange={onCompanySearch}
            placeholder="Select company"
            loading={companiesLoading}
          />
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="reg_password" className={labelClass}>
            Password
          </Label>
          <Input
            id="reg_password"
            type="password"
            placeholder="Create a password"
            value={form.password}
            onChange={(e) => updateField("password", e.target.value)}
            required
            autoComplete="new-password"
            className={inputClass}
          />
        </div>

        <Button
          type="submit"
          className="h-10 w-full bg-gradient-to-r from-brand-600 to-brand-500 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
          disabled={isPending}
        >
          {isPending ? "Creating account..." : "Create account"}
        </Button>

        <p className="text-center font-mono text-[11px] text-on-surface-variant">
          Already have an account?{" "}
          <Link
            href="/login"
            className="font-bold text-brand-600 transition-colors hover:text-brand-700 hover:underline"
          >
            Sign in
          </Link>
        </p>
      </form>
    </div>
  );
}

"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Home,
  CalendarDays,
  Ticket,
  Bus,
  Building2,
  Users,
  Shield,
  User,
  Plus,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { ROLES } from "@/lib/auth";

interface ISidebarItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const MENU_ITEMS: Record<string, ISidebarItem[]> = {
  [ROLES.USER]: [
    { label: "Dashboard", href: "/employee", icon: Home },
    { label: "Schedules", href: "/employee/schedules", icon: CalendarDays },
    { label: "Reservations", href: "/employee/reservations", icon: Ticket },
    { label: "Profile", href: "/employee/profile", icon: User },
  ],
  [ROLES.ADMIN]: [
    { label: "Dashboard", href: "/admin", icon: Home },
    { label: "Buses", href: "/admin/buses", icon: Bus },
    { label: "Schedules", href: "/admin/schedules", icon: CalendarDays },
    { label: "Reservations", href: "/admin/reservations", icon: Ticket },
  ],
  [ROLES.GUEST]: [
    { label: "Dashboard", href: "/super-admin", icon: Home },
    { label: "Companies", href: "/super-admin/companies", icon: Building2 },
    { label: "Users", href: "/super-admin/users", icon: Users },
    { label: "Buses", href: "/super-admin/buses", icon: Bus },
    { label: "Schedules", href: "/super-admin/schedules", icon: CalendarDays },
    { label: "Roles", href: "/super-admin/roles", icon: Shield },
  ],
};

const ROLE_LABELS: Record<string, string> = {
  [ROLES.USER]: "Employee",
  [ROLES.ADMIN]: "Admin",
  [ROLES.GUEST]: "Super Admin",
};

const ROLE_CTA: Record<string, string> = {
  [ROLES.USER]: "New Reservation",
  [ROLES.ADMIN]: "New Schedule",
  [ROLES.GUEST]: "New Company",
};

interface ISidebarProps {
  roleType: string;
  collapsed: boolean;
}

export function Sidebar({ roleType, collapsed }: ISidebarProps) {
  const pathname = usePathname();
  const items = MENU_ITEMS[roleType] ?? MENU_ITEMS[ROLES.USER];
  const roleLabel = ROLE_LABELS[roleType] ?? "User";
  const ctaLabel = ROLE_CTA[roleType] ?? "New Reservation";

  return (
    <aside
      className={cn(
        "hidden md:flex flex-col h-screen overflow-y-auto border-r border-[#c7c4d8]/15 bg-[#f4f2fd] transition-all duration-300 ease-in-out",
        collapsed ? "w-16" : "w-56"
      )}
    >
      {/* Logo + role */}
      <div className={cn("p-6", collapsed && "px-4 py-6 flex justify-center")}>
        {collapsed ? (
          <span className="text-lg font-black text-brand-600 tracking-tighter">
            S
          </span>
        ) : (
          <>
            <div className="text-lg font-black uppercase tracking-tighter text-brand-600">
              Shuttle Office
            </div>
            <div className="mt-1 font-mono text-[10px] uppercase font-medium tracking-widest text-on-surface-variant">
              {roleLabel}
            </div>
          </>
        )}
      </div>

      {/* Nav */}
      <nav className="mt-2 flex-1 px-2">
        {items.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== `/${pathname.split("/")[1]}` &&
              pathname.startsWith(item.href + "/"));
          const Icon = item.icon;

          return (
            <Link
              key={item.href}
              href={item.href}
              title={collapsed ? item.label : undefined}
              className={cn(
                "mx-0 my-0.5 flex items-center gap-3 rounded-lg px-4 py-3 transition-all duration-200 ease-in-out",
                collapsed && "justify-center px-0",
                isActive
                  ? "bg-brand-600 text-white shadow-sm"
                  : "text-on-surface hover:bg-surface-dim"
              )}
            >
              <Icon className="h-[18px] w-[18px] shrink-0" />
              {!collapsed && (
                <span className="font-mono text-xs font-medium uppercase tracking-wide">
                  {item.label}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* CTA */}
      {!collapsed && (
        <div className="p-4">
          <button className="flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 py-3 font-mono text-[11px] font-bold uppercase tracking-wider text-white transition-opacity hover:opacity-90 active:translate-y-px">
            <Plus className="h-3.5 w-3.5" />
            {ctaLabel}
          </button>
        </div>
      )}
    </aside>
  );
}

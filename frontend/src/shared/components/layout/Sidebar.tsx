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
} from "lucide-react";
import { cn } from "@/lib/utils";
import { ROLES } from "@/lib/auth";

interface ISidebarItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const MENU_ITEMS: Record<number, ISidebarItem[]> = {
  [ROLES.EMPLOYEE]: [
    { label: "Dashboard", href: "/employee", icon: Home },
    { label: "My Reservations", href: "/employee/reservations", icon: Ticket },
    { label: "Profile", href: "/employee/profile", icon: User },
  ],
  [ROLES.ADMIN]: [
    { label: "Dashboard", href: "/admin", icon: Home },
    { label: "Buses", href: "/admin/buses", icon: Bus },
    { label: "Schedules", href: "/admin/schedules", icon: CalendarDays },
    { label: "Reservations", href: "/admin/reservations", icon: Ticket },
  ],
  [ROLES.SUPER_ADMIN]: [
    { label: "Dashboard", href: "/super-admin", icon: Home },
    { label: "Companies", href: "/super-admin/companies", icon: Building2 },
    { label: "Users", href: "/super-admin/users", icon: Users },
    { label: "Buses", href: "/super-admin/buses", icon: Bus },
    { label: "Schedules", href: "/super-admin/schedules", icon: CalendarDays },
    { label: "Roles", href: "/super-admin/roles", icon: Shield },
  ],
};

interface ISidebarProps {
  roleType: number;
  collapsed: boolean;
}

export function Sidebar({ roleType, collapsed }: ISidebarProps) {
  const pathname = usePathname();
  const items = MENU_ITEMS[roleType] ?? MENU_ITEMS[ROLES.EMPLOYEE];

  return (
    <aside
      className={cn(
        "hidden md:flex flex-col border-r bg-white transition-all duration-200",
        collapsed ? "w-16" : "w-56"
      )}
    >
      <div className="flex h-14 items-center border-b px-4">
        {!collapsed && (
          <span className="text-lg font-bold text-brand-600">Shuttle</span>
        )}
        {collapsed && (
          <span className="text-lg font-bold text-brand-600 mx-auto">S</span>
        )}
      </div>
      <nav className="flex-1 p-2 space-y-1">
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
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                isActive
                  ? "bg-brand-50 text-brand-700 font-medium"
                  : "text-muted-foreground hover:bg-secondary hover:text-foreground"
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}

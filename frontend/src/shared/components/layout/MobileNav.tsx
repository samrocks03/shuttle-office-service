"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Ticket, User, Bus, Building2, CalendarDays } from "lucide-react";
import { cn } from "@/lib/utils";
import { ROLES } from "@/lib/auth";

interface IMobileNavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const MOBILE_ITEMS: Record<string, IMobileNavItem[]> = {
  [ROLES.USER]: [
    { label: "Home", href: "/employee", icon: Home },
    { label: "Schedules", href: "/employee/schedules", icon: CalendarDays },
    { label: "Rides", href: "/employee/reservations", icon: Ticket },
    { label: "Profile", href: "/employee/profile", icon: User },
  ],
  [ROLES.ADMIN]: [
    { label: "Home", href: "/admin", icon: Home },
    { label: "Buses", href: "/admin/buses", icon: Bus },
    { label: "Schedules", href: "/admin/schedules", icon: CalendarDays },
  ],
  [ROLES.GUEST]: [
    { label: "Home", href: "/super-admin", icon: Home },
    { label: "Companies", href: "/super-admin/companies", icon: Building2 },
    { label: "Users", href: "/super-admin/users", icon: User },
  ],
};

interface IMobileNavProps {
  roleType: string;
}

export function MobileNav({ roleType }: IMobileNavProps) {
  const pathname = usePathname();
  const items = MOBILE_ITEMS[roleType] ?? MOBILE_ITEMS[ROLES.USER];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex md:hidden border-t bg-white">
      {items.map((item) => {
        const isActive = pathname === item.href || pathname.startsWith(item.href + "/");
        const Icon = item.icon;

        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex flex-1 flex-col items-center gap-1 py-2 text-xs transition-colors",
              isActive
                ? "text-brand-600 font-medium"
                : "text-muted-foreground"
            )}
          >
            <Icon className="h-5 w-5" />
            <span>{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}

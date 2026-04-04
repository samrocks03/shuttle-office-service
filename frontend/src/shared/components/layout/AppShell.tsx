"use client";

import { useState } from "react";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { MobileNav } from "./MobileNav";

interface IAppShellProps {
  children: React.ReactNode;
  userName: string;
  roleType: string;
}

export function AppShell({ children, userName, roleType }: IAppShellProps) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  return (
    <div className="flex h-screen bg-surface">
      <Sidebar roleType={roleType} collapsed={sidebarCollapsed} />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header
          userName={userName}
          onToggleSidebar={() => setSidebarCollapsed((prev) => !prev)}
        />
        <main className="flex-1 overflow-y-auto p-4 pb-20 md:pb-4">
          {children}
        </main>
      </div>
      <MobileNav roleType={roleType} />
    </div>
  );
}

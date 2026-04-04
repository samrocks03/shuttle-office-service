"use client";

import { Menu, LogOut, Bell, Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useLogoutFacade } from "@/features/auth/(hooks)/useAuthFacade";

interface IHeaderProps {
  userName: string;
  onToggleSidebar: () => void;
}

export function Header({ userName, onToggleSidebar }: IHeaderProps) {
  const { logout } = useLogoutFacade();

  return (
    <header className="sticky top-0 z-50 flex h-16 w-full items-center justify-between border-b border-[#c7c4d8]/15 bg-[#fbf8ff] px-6 transition-all">
      <div className="flex items-center gap-3">
        <Button
          variant="ghost"
          size="icon"
          onClick={onToggleSidebar}
          className="text-on-surface-variant hover:bg-surface-dim hover:text-on-surface"
        >
          <Menu className="h-4 w-4" />
        </Button>
      </div>

      <div className="flex items-center gap-2">
        <button className="rounded-lg p-2 text-on-surface-variant transition-colors hover:bg-surface-container-low hover:text-on-surface">
          <Bell className="h-4 w-4" />
        </button>
        <button className="rounded-lg p-2 text-on-surface-variant transition-colors hover:bg-surface-container-low hover:text-on-surface">
          <Settings className="h-4 w-4" />
        </button>

        <DropdownMenu>
          <DropdownMenuTrigger className="ml-1 inline-flex items-center gap-2.5 rounded-lg px-2 py-1.5 outline-none transition-colors hover:bg-surface-container-low">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-500 text-[10px] font-bold uppercase text-white">
              {userName.slice(0, 2).toUpperCase()}
            </div>
            <span className="hidden font-mono text-xs font-medium uppercase tracking-wide text-on-surface sm:inline">
              {userName}
            </span>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="min-w-40">
            <DropdownMenuItem
              onClick={logout}
              className="gap-2 font-mono text-xs uppercase tracking-wide text-destructive focus:text-destructive"
            >
              <LogOut className="h-3.5 w-3.5" />
              Sign out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}

"use client";

import { Menu, LogOut } from "lucide-react";
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
    <header className="flex h-14 items-center justify-between border-b bg-white px-4">
      <Button
        variant="ghost"
        size="icon"
        onClick={onToggleSidebar}
      >
        <Menu className="h-5 w-5" />
      </Button>

      <DropdownMenu>
        <DropdownMenuTrigger className="inline-flex items-center gap-2 rounded-lg px-2 py-1 text-sm hover:bg-muted transition-colors outline-none">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-100 text-sm font-medium text-brand-700">
            {userName.charAt(0).toUpperCase()}
          </div>
          <span className="hidden sm:inline">{userName}</span>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={logout} className="text-destructive">
            <LogOut className="mr-2 h-4 w-4" />
            Sign out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </header>
  );
}

"use client";

import * as React from "react";
import { Combobox } from "@base-ui/react/combobox";
import { CheckIcon, ChevronsUpDownIcon } from "lucide-react";
import { cn } from "@/lib/utils";

export interface SearchableSelectOption {
  value: number | string;
  label: string;
}

interface SearchableSelectProps {
  options: SearchableSelectOption[];
  value: number | string;
  onValueChange: (value: number | string) => void;
  /** Called on every keystroke — caller is responsible for debouncing */
  onSearchChange?: (search: string) => void;
  loading?: boolean;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}

export function SearchableSelect({
  options,
  value,
  onValueChange,
  onSearchChange,
  loading = false,
  disabled = false,
  placeholder = "Select...",
  className,
}: SearchableSelectProps) {
  const [inputValue, setInputValue] = React.useState("");
  // Persist the selected label independently of the current search results
  const [selectedLabel, setSelectedLabel] = React.useState<string>("");

  // Sync label when value is set externally and options contain it
  React.useEffect(() => {
    if (!value && value !== 0) return;
    const match = options.find((o) => String(o.value) === String(value));
    if (match) setSelectedLabel(match.label);
  }, [value, options]);

  function handleInputChange(search: string) {
    setInputValue(search);
    onSearchChange?.(search);
  }

  function handleValueChange(val: string | null) {
    if (val === null) return;
    const opt = options.find((o) => String(o.value) === val);
    if (!opt) return;
    setSelectedLabel(opt.label);
    setInputValue("");
    onSearchChange?.("");
    onValueChange(opt.value);
  }

  return (
    <Combobox.Root
      // Disable Base UI's internal filtering — server already filters
      filter={() => true}
      value={value === 0 || value === "" ? null : String(value)}
      onValueChange={handleValueChange}
      inputValue={inputValue}
      onInputValueChange={handleInputChange}
    >
      <Combobox.Trigger
        disabled={disabled || loading}
        className={cn(
          "flex h-10 w-full items-center justify-between rounded-lg border border-[#c7c4d8]/30 bg-surface-container-low px-3 py-2 text-sm text-on-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-600 disabled:cursor-not-allowed disabled:opacity-50",
          className
        )}
      >
        <span className={cn("truncate", !selectedLabel && "text-muted-foreground")}>
          {loading ? "Loading..." : selectedLabel || placeholder}
        </span>
        <ChevronsUpDownIcon className="size-4 shrink-0 text-muted-foreground" />
      </Combobox.Trigger>

      <Combobox.Portal>
        <Combobox.Positioner sideOffset={4} className="z-50">
          <Combobox.Popup className="w-(--anchor-width) overflow-hidden rounded-lg border bg-popover shadow-md animate-in fade-in-0 zoom-in-95">
            <div className="border-b px-3 py-2">
              <Combobox.Input
                placeholder="Search..."
                className="w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
              />
            </div>

            <Combobox.List className="max-h-52 overflow-y-auto p-1">
              {loading ? (
                <div className="py-6 text-center text-sm text-muted-foreground">
                  Searching...
                </div>
              ) : (
                <>
                  <Combobox.Empty className="py-6 text-center text-sm text-muted-foreground">
                    No companies found.
                  </Combobox.Empty>
                  {options.map((opt) => (
                    <Combobox.Item
                      key={opt.value}
                      value={String(opt.value)}
                      className="relative flex cursor-default select-none items-center rounded-md py-1.5 pl-8 pr-2 text-sm outline-none hover:bg-accent hover:text-accent-foreground data-[highlighted]:bg-accent data-[highlighted]:text-accent-foreground"
                    >
                      <span className="absolute left-2 flex size-3.5 items-center justify-center">
                        <Combobox.ItemIndicator>
                          <CheckIcon className="size-4" />
                        </Combobox.ItemIndicator>
                      </span>
                      {opt.label}
                    </Combobox.Item>
                  ))}
                </>
              )}
            </Combobox.List>
          </Combobox.Popup>
        </Combobox.Positioner>
      </Combobox.Portal>
    </Combobox.Root>
  );
}

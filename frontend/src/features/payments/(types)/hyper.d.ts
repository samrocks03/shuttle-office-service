// @juspay-tech/react-hyper-js ships no type declarations; these cover what the checkout uses.
declare module "@juspay-tech/react-hyper-js" {
  import type { ComponentType, ReactNode } from "react";

  export const HyperElements: ComponentType<{
    hyper: Promise<unknown>;
    options: Record<string, unknown>;
    children?: ReactNode;
  }>;
  export const PaymentElement: ComponentType<{ id?: string; options?: Record<string, unknown> }>;
  export function useHyper(): {
    confirmPayment(args: {
      elements: unknown;
      confirmParams: { return_url: string };
      redirect?: "if_required" | "always";
    }): Promise<{ error?: { type?: string; message?: string }; status?: string }>;
  } | null;
  export function useWidgets(): unknown;
}

interface Window {
  Hyper?: (publishableKey: string, options?: Record<string, unknown>) => unknown;
}

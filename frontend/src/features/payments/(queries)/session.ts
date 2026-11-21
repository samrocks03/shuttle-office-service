// The client secret is only handed out when a payment starts (booking or retry), so it is kept
// for this browser tab to let "Pay now" reopen the checkout. Card data never touches it.
const sessionKey = (uid: string) => `payment-session:${uid}`;

export function savePaymentSession(uid: string, session: IPaymentSession) {
  try {
    sessionStorage.setItem(sessionKey(uid), JSON.stringify(session));
  } catch {
    // Storage blocked: the pay page falls back to asking for a new payment.
  }
}

export function readPaymentSession(uid: string): IPaymentSession | null {
  try {
    const raw = sessionStorage.getItem(sessionKey(uid));
    return raw ? (JSON.parse(raw) as IPaymentSession) : null;
  } catch {
    return null;
  }
}

export function clearPaymentSession(uid: string) {
  try {
    sessionStorage.removeItem(sessionKey(uid));
  } catch {
    // nothing to clear
  }
}

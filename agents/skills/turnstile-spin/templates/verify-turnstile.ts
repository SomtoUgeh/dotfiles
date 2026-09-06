/** Server-only helper; never import this module from a client component. */
export async function verifyTurnstile(input: {
  token: unknown;
  secret: unknown;
  hostnames: string | undefined;
  action: string;
}): Promise<boolean> {
  const { token, secret, action } = input;
  const hostnames = new Set(
    (input.hostnames ?? "").split(",").map(value => value.trim()).filter(Boolean),
  );
  if (typeof token !== "string" || token.length === 0 || token.length > 2048
      || typeof secret !== "string" || secret.trim().length === 0
      || hostnames.size === 0 || !/^[A-Za-z0-9_-]{1,32}$/.test(action)) {
    return false;
  }
  try {
    const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      signal: AbortSignal.timeout(10_000),
      body: new URLSearchParams({ secret, response: token }),
    });
    if (!response.ok) return false;
    const result: unknown = await response.json();
    return typeof result === "object" && result !== null
      && "success" in result && result.success === true
      && "action" in result && result.action === action
      && "hostname" in result && typeof result.hostname === "string"
      && hostnames.has(result.hostname);
  } catch {
    // Transport, timeout, or malformed JSON: the protected handler cannot run.
    return false;
  }
}

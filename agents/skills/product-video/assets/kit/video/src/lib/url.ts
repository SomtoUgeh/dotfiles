import { brand } from "../brand/tokens";

const LOCALE = /^[a-z]{2}(-[A-Z]{2})?$/;
const ID = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-z]{20,})$/i;
const INDEX = /^index\.html?$/i;

/**
 * Presentable address-bar text for a recorded URL: the brand host, no locale prefix,
 * no query string, no opaque ids, and no scaffolding segments (see brand.urlScaffold).
 */
export const prettyUrl = (raw: string): string => {
  let pathname: string;
  let isFile = false;
  try {
    const url = new URL(raw);
    pathname = url.pathname;
    isFile = url.protocol === "file:";
  } catch {
    pathname = raw.split("?")[0] ?? "";
  }
  let parts = pathname.split("/").filter(Boolean);
  // A page opened from disk has a folder path that means nothing to the viewer.
  if (isFile) parts = parts.slice(-1);
  if (parts[0] && LOCALE.test(parts[0])) parts.shift();
  const kept: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    const next = parts[i + 1];
    if (brand.urlScaffold.includes(part) && next && ID.test(next)) {
      i++;
      continue;
    }
    if (ID.test(part) || INDEX.test(part)) continue;
    kept.push(part.replace(/\.html?$/i, ""));
  }
  return kept.length ? `${brand.host}/${kept.join("/")}` : brand.host;
};

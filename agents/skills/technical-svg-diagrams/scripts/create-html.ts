#!/usr/bin/env bun
/** Wrap a self-contained SVG as an image for browser screenshot capture.
 * Run with Bun or a Node version supporting TypeScript type stripping.
 * SVG image mode disables scripts; external assets must be embedded first.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, basename } from "node:path";
import { parseArgs } from "node:util";

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) => {
    switch (char) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      default: return "&#39;";
    }
  });
}

function dimension(value: string, name: string, minimum: number): number {
  const number = Number(value);
  if (!value.trim() || !Number.isFinite(number) || number < minimum) {
    throw new Error(`${name} must be a finite number >= ${minimum}`);
  }
  return number;
}

function color(value: string): string {
  const hex = /^#(?:[\da-f]{3}|[\da-f]{4}|[\da-f]{6}|[\da-f]{8})$/i;
  const named = /^[a-z]+$/i;
  const functional = /^(?:rgb|hsl)a?\([\d.% ,/+\-]+\)$/i;
  if (!hex.test(value) && !named.test(value) && !functional.test(value)) {
    throw new Error("background must be a hex, named, rgb(), or hsl() color");
  }
  return value;
}

function attributes(tag: string): Map<string, string> {
  const values = new Map<string, string>();
  for (const match of tag.matchAll(/([\w:-]+)\s*=\s*(["'])(.*?)\2/g)) {
    const [, name, , value] = match;
    if (name !== undefined && value !== undefined) values.set(name, value);
  }
  return values;
}

function backgroundFromSvg(svg: string): string | undefined {
  const root = attributes(svg.match(/<svg\b[^>]*>/i)?.[0] ?? "");
  const styled = root.get("style")?.match(/(?:^|;)\s*background(?:-color)?\s*:\s*([^;]+)/i)?.[1];
  if (styled) return color(styled.trim());
  const viewBox = root.get("viewBox")?.trim().split(/[\s,]+/);
  const width = viewBox?.[2] ?? root.get("width");
  const height = viewBox?.[3] ?? root.get("height");
  for (const match of svg.matchAll(/<rect\b[^>]*>/gi)) {
    const rect = attributes(match[0]);
    const fillsWidth = rect.get("width") === "100%" || (width !== undefined && rect.get("width") === width);
    const fillsHeight = rect.get("height") === "100%" || (height !== undefined && rect.get("height") === height);
    const atOrigin = (rect.get("x") ?? "0") === (viewBox?.[0] ?? "0") && (rect.get("y") ?? "0") === (viewBox?.[1] ?? "0");
    const fill = rect.get("fill");
    if (fillsWidth && fillsHeight && atOrigin && fill && fill !== "none" && !fill.startsWith("url(")) return color(fill);
  }
  return undefined;
}

function main(): void {
  const { values } = parseArgs({
    options: {
      svg: { type: "string", short: "s" },
      output: { type: "string", short: "o" },
      padding: { type: "string", short: "p", default: "40" },
      width: { type: "string", short: "w", default: "1600" },
      background: { type: "string", short: "b" },
      help: { type: "boolean", short: "h" },
    },
    strict: true,
    allowPositionals: false,
  });
  if (values.help) {
    console.log("create-html.ts --svg <file.svg> --output <file.html> [--padding 40] [--width 1600] [--background '#fafafa']");
    return;
  }
  if (!values.svg || !values.output) throw new Error("--svg and --output are required");
  if (resolve(values.svg) === resolve(values.output)) throw new Error("output must differ from input");
  const padding = dimension(values.padding, "padding", 0);
  const width = dimension(values.width, "width", 1);
  const svg = readFileSync(resolve(values.svg), "utf8");
  if (!/<svg\b[\s\S]*<\/svg\s*>/i.test(svg)) throw new Error("input must contain a complete SVG document");
  const background = color(values.background ?? backgroundFromSvg(svg) ?? "#fafafa");
  const title = escapeHtml(basename(values.svg, ".svg"));
  const data = Buffer.from(svg).toString("base64");
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>${title}</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: ${background}; }
.container { display: inline-block; padding: ${padding}px; background: ${background}; }
.container img { display: block; width: ${width}px; height: auto; }
</style></head><body><div class="container"><img alt="${title}" src="data:image/svg+xml;base64,${data}"></div></body></html>`;
  writeFileSync(resolve(values.output), html, "utf8");
  console.log(`HTML wrapper written to: ${resolve(values.output)}`);
  console.log(`Background colour: ${background}`);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

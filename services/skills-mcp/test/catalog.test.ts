import { describe, expect, test } from "bun:test";
import { skillEntry } from "@modelcontextprotocol/server/ext/skills";
import { hasFile, parseSkillUri, searchSkills, shardOf, type CatalogSkill } from "../src/catalog.js";

const skill = async (name: string, description: string, extra: Record<string, string> = {}): Promise<CatalogSkill> => ({
  name,
  description,
  version: "v1",
  entry: await skillEntry(name, { "SKILL.md": `---\nname: ${name}\ndescription: ${description}\n---\n`, ...extra }, { baseUri: "skill://" }),
});

describe("parseSkillUri", () => {
  test("splits a name and a nested path", () => {
    expect(parseSkillUri("skill://shadcn/references/a.md")).toEqual({ name: "shadcn", path: "references/a.md" });
  });
  test("refuses other schemes and missing parts", () => {
    expect(parseSkillUri("file://shadcn/SKILL.md")).toBeUndefined();
    expect(parseSkillUri("skill://shadcn")).toBeUndefined();
    expect(parseSkillUri("skill://shadcn/")).toBeUndefined();
    expect(parseSkillUri("skill:///SKILL.md")).toBeUndefined();
  });
});

test("hasFile accepts only files the skill publishes", async () => {
  const s = await skill("demo", "Demo.", { "references/x.md": "x" });
  expect(hasFile(s, "references/x.md")).toBe(true);
  expect(hasFile(s, "../other/SKILL.md")).toBe(false);
});

test("shardOf is stable and in range", () => {
  expect(shardOf("cloudflare")).toBe(shardOf("cloudflare"));
  for (const name of ["a", "shadcn", "principle-prove-it-works"]) {
    const shard = shardOf(name, 3);
    expect(shard).toBeGreaterThanOrEqual(0);
    expect(shard).toBeLessThan(3);
  }
});

describe("searchSkills", async () => {
  const skills = [
    await skill("react-performance", "Make React apps faster."),
    await skill("cloudflare", "Build on Cloudflare Workers and React Router."),
    await skill("postgres", "Tune Postgres queries."),
  ];
  test("ranks a name match above a description match", () => {
    expect(searchSkills(skills, "react", 10).map((s) => s.name)).toEqual(["react-performance", "cloudflare"]);
  });
  test("prefers skills that match every word", () => {
    expect(searchSkills(skills, "cloudflare workers", 10)[0]?.name).toBe("cloudflare");
  });
  test("lists every skill by name for an empty query", () => {
    expect(searchSkills(skills, "", 10).map((s) => s.name)).toEqual(["cloudflare", "postgres", "react-performance"]);
  });
  test("returns nothing for unknown words and respects the limit", () => {
    expect(searchSkills(skills, "kubernetes", 10)).toEqual([]);
    expect(searchSkills(skills, "", 1)).toHaveLength(1);
  });
});

import { afterAll, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildCatalog, collectSkills, executorShards } from "../scripts/build.js";

const root = mkdtempSync(join(tmpdir(), "skills-build-"));
afterAll(() => rmSync(root, { recursive: true, force: true }));

const write = (path: string, content: string | Uint8Array) => {
  mkdirSync(join(root, path, ".."), { recursive: true });
  writeFileSync(join(root, path), content);
};
const git = (...args: string[]) => {
  const result = Bun.spawnSync(["git", "-C", root, ...args], { stderr: "pipe" });
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
};

git("init", "-q");
write("good/SKILL.md", "---\nname: good\ndescription: A good skill.\n---\n# Good\n");
write("good/references/guide.md", "Guide\n");
write("good/assets/logo.png", new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0, 1, 2]));
write("good/untracked.md", "not committed\n");
write("wrong-name/SKILL.md", "---\nname: other\ndescription: Name does not match.\n---\n");
write("RUNTIME_TOOLS.md", "A loose file beside the skills.\n");
symlinkSync("references/guide.md", join(root, "good/link.md"));
git("add", "good/SKILL.md", "good/references/guide.md", "good/assets/logo.png", "good/link.md", "wrong-name/SKILL.md", "RUNTIME_TOOLS.md");

test("collects tracked text files and reports what it skips", () => {
  const { sources, skipped } = collectSkills(root);
  expect(sources.map((s) => s.name)).toEqual(["good", "wrong-name"]);
  expect([...(sources[0]?.files.keys() ?? [])]).toEqual(["SKILL.md", "references/guide.md"]);
  expect(skipped).toEqual(["good/assets/logo.png (binary)", "good/link.md (not a regular file)"]);
});

test("fails the build on a skill Executor or MCP would refuse", async () => {
  const { sources } = collectSkills(root);
  expect(buildCatalog(sources, "abc")).rejects.toThrow(/wrong-name/);
});

test("builds a catalog and shards from valid skills", async () => {
  const { sources } = collectSkills(root);
  const catalog = await buildCatalog(sources.filter((s) => s.name === "good"), "abc");
  expect(catalog.skills.map((s) => s.name)).toEqual(["good"]);
  expect(catalog.skills[0]?.description).toBe("A good skill.");
  const shards = executorShards(catalog);
  expect(shards.flatMap((s) => s.index.skills.map((x) => x.name))).toEqual(["good"]);
  expect(shards.flatMap((s) => s.index.skills.flatMap((x) => x.files))).toEqual(["SKILL.md", "references/guide.md"]);
});

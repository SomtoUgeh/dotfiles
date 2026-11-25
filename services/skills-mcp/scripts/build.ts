// Builds the skills site from the git-tracked files of agents/skills.
// Output: dist/assets (served by the Worker) and src/generated/catalog.json
// (bundled into the Worker). Fails on any skill that Executor or the MCP
// Skills extension would refuse, because one bad skill fails a whole catalog.
import { createHash } from "node:crypto";
import { lstatSync, mkdirSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { skillEntry } from "@modelcontextprotocol/server/ext/skills";
import { fileSkill } from "apps/skills";
import { assetPath, shardOf, type Catalog, type CatalogSkill } from "../src/catalog.js";
import {
  DISCOVERY_SCHEMA,
  EXECUTOR_SHARDS,
  EXECUTOR_SHARD_FILE_LIMIT,
  ORIGIN,
  SKILLS_PATH,
  SKILL_URI_BASE,
  executorShardFile,
} from "../src/config.js";

interface SourceSkill {
  name: string;
  files: Map<string, string>;
}

interface BuildResult {
  catalog: Catalog;
  sources: SourceSkill[];
  skipped: string[];
}

const git = (cwd: string, args: string[]): string => {
  const result = Bun.spawnSync(["git", "-C", cwd, ...args], { stdout: "pipe", stderr: "pipe" });
  if (result.exitCode !== 0) throw new Error(`git ${args.join(" ")} failed in ${cwd}: ${result.stderr.toString()}`);
  return result.stdout.toString();
};

const trackedFiles = (cwd: string): string[] => git(cwd, ["ls-files", "-z"]).split("\0").filter(Boolean);

const decodeText = (bytes: Uint8Array): string | undefined => {
  if (bytes.includes(0)) return undefined;
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return undefined;
  }
};

const sha256 = (data: string | Uint8Array): string => createHash("sha256").update(data).digest("hex");

export const collectSkills = (skillsRoot: string): { sources: SourceSkill[]; skipped: string[] } => {
  const names = [...new Set(trackedFiles(skillsRoot).map((path) => path.split("/")[0] ?? ""))]
    .filter((name) => name !== "" && !name.startsWith("."))
    .sort();
  const sources: SourceSkill[] = [];
  const skipped: string[] = [];
  for (const name of names) {
    const dir = join(skillsRoot, name);
    if (!statSync(dir).isDirectory()) continue;
    const real = realpathSync(dir);
    const files = new Map<string, string>();
    for (const path of trackedFiles(real).sort()) {
      const absolute = join(real, path);
      const stat = lstatSync(absolute);
      if (stat.isSymbolicLink() || !stat.isFile()) {
        skipped.push(`${name}/${path} (not a regular file)`);
        continue;
      }
      const text = decodeText(readFileSync(absolute));
      if (text === undefined) {
        skipped.push(`${name}/${path} (binary)`);
        continue;
      }
      files.set(path, text);
    }
    if (!files.has("SKILL.md")) {
      skipped.push(`${name}/ (no SKILL.md)`);
      continue;
    }
    sources.push({ name, files });
  }
  return { sources, skipped };
};

export const buildCatalog = async (sources: SourceSkill[], commit: string): Promise<Catalog> => {
  const problems: string[] = [];
  const skills: CatalogSkill[] = [];
  for (const source of sources) {
    const record = Object.fromEntries(source.files);
    try {
      await fileSkill([...source.files].map(([path, content]) => ({ path, content })));
      const entry = await skillEntry(source.name, record, { baseUri: SKILL_URI_BASE });
      const { description } = entry.frontmatter;
      const resources = entry.resources === "dynamic" ? [] : entry.resources;
      const version = sha256(resources.map((r) => `${r.uri}\0${r.digest}`).join("\n")).slice(0, 16);
      skills.push({ name: source.name, description, version, entry });
    } catch (error) {
      problems.push(`${source.name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  if (problems.length > 0) throw new Error(`Invalid skills:\n${problems.join("\n")}`);
  const version = sha256(skills.map((s) => `${s.name}@${s.version}`).join("\n")).slice(0, 16);
  return { version, commit, skills };
};

const indexEntry = (skill: CatalogSkill) => {
  const resources = skill.entry.resources === "dynamic" ? [] : skill.entry.resources;
  const skillMd = resources.find((r) => r.uri.endsWith("/SKILL.md"));
  const prefix = `${SKILL_URI_BASE}${skill.name}/`;
  return {
    name: skill.name,
    type: "skill-md",
    description: skill.description,
    url: `${ORIGIN}${assetPath(skill.name, "SKILL.md")}`,
    digest: skillMd?.digest ?? "",
    version: skill.version,
    files: resources.map((r) => r.uri.slice(prefix.length)),
  };
};

export const executorShards = (catalog: Catalog) => {
  const shards = Array.from({ length: EXECUTOR_SHARDS }, () => [] as ReturnType<typeof indexEntry>[]);
  for (const skill of catalog.skills) shards[shardOf(skill.name)]?.push(indexEntry(skill));
  return shards.map((skills, shard) => {
    const files = skills.reduce((count, skill) => count + skill.files.length, 0);
    if (files > EXECUTOR_SHARD_FILE_LIMIT)
      throw new Error(
        `${executorShardFile(shard)} lists ${files} files; Executor reads at most ${EXECUTOR_SHARD_FILE_LIMIT}. Raise EXECUTOR_SHARDS in src/config.ts and executor-app/index.ts.`,
      );
    return { file: executorShardFile(shard), files, index: { skills: skills.map(({ name, version, files: f }) => ({ name, version, files: f })) } };
  });
};

const HEADERS = `${SKILLS_PATH}/*
  Access-Control-Allow-Origin: *
  Cache-Control: public, max-age=60, must-revalidate
  X-Content-Type-Options: nosniff
`;

export const writeOutputs = (result: BuildResult, serviceDir: string): void => {
  const assets = join(serviceDir, "dist", "assets");
  rmSync(join(serviceDir, "dist"), { recursive: true, force: true });
  const skillsDir = join(assets, SKILLS_PATH);
  for (const source of result.sources) {
    for (const [path, content] of source.files) {
      const target = join(skillsDir, source.name, path);
      mkdirSync(dirname(target), { recursive: true });
      writeFileSync(target, content);
    }
  }
  const index = { $schema: DISCOVERY_SCHEMA, skills: result.catalog.skills.map(indexEntry) };
  writeFileSync(join(skillsDir, "index.json"), `${JSON.stringify(index, null, 2)}\n`);
  for (const shard of executorShards(result.catalog))
    writeFileSync(join(skillsDir, shard.file), `${JSON.stringify(shard.index)}\n`);
  writeFileSync(join(assets, "_headers"), HEADERS);
  const generated = join(serviceDir, "src", "generated");
  mkdirSync(generated, { recursive: true });
  writeFileSync(join(generated, "catalog.json"), `${JSON.stringify(result.catalog)}\n`);
};

if (import.meta.main) {
  const serviceDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
  const repoRoot = git(serviceDir, ["rev-parse", "--show-toplevel"]).trim();
  const skillsRoot = process.env.SKILLS_DIR ?? join(repoRoot, "agents", "skills");
  const commit = process.env.GITHUB_SHA ?? git(repoRoot, ["rev-parse", "HEAD"]).trim();
  const { sources, skipped } = collectSkills(skillsRoot);
  const catalog = await buildCatalog(sources, commit);
  writeOutputs({ catalog, sources, skipped }, serviceDir);
  const files = sources.reduce((n, s) => n + s.files.size, 0);
  const bytes = sources.reduce((n, s) => n + [...s.files.values()].reduce((m, c) => m + Buffer.byteLength(c), 0), 0);
  console.log(`Built ${catalog.skills.length} skills, ${files} files, ${(bytes / 1e6).toFixed(2)} MB, version ${catalog.version}`);
  for (const shard of executorShards(catalog)) console.log(`  ${shard.file}: ${shard.index.skills.length} skills, ${shard.files} files`);
  if (skipped.length > 0) console.log(`Skipped ${skipped.length}:\n  ${skipped.join("\n  ")}`);
}

import type { Skill } from "@modelcontextprotocol/server/ext/skills";
import { EXECUTOR_SHARDS, SKILLS_PATH, SKILL_URI_BASE } from "./config.js";

export interface CatalogSkill {
  name: string;
  description: string;
  version: string;
  entry: Skill;
}

export interface Catalog {
  version: string;
  commit: string;
  skills: CatalogSkill[];
}

export interface SkillFile {
  path: string;
  size: number;
}

export interface SearchResult {
  name: string;
  description: string;
  files: number;
}

export const skillUri = (name: string, path: string): string => `${SKILL_URI_BASE}${name}/${path}`;

export const parseSkillUri = (uri: string): { name: string; path: string } | undefined => {
  if (!uri.startsWith(SKILL_URI_BASE)) return undefined;
  const rest = uri.slice(SKILL_URI_BASE.length);
  const slash = rest.indexOf("/");
  if (slash <= 0 || slash === rest.length - 1) return undefined;
  return { name: rest.slice(0, slash), path: rest.slice(slash + 1) };
};

export const skillFiles = (skill: CatalogSkill): SkillFile[] => {
  const prefix = skillUri(skill.name, "");
  const { resources } = skill.entry;
  if (resources === "dynamic") return [];
  return resources.map((resource) => ({ path: resource.uri.slice(prefix.length), size: resource.size }));
};

export const hasFile = (skill: CatalogSkill, path: string): boolean =>
  skillFiles(skill).some((file) => file.path === path);

export const assetPath = (name: string, path: string): string =>
  `${SKILLS_PATH}/${encodeURIComponent(name)}/${path.split("/").map(encodeURIComponent).join("/")}`;

export const mimeType = (path: string): string => {
  if (path.endsWith(".md")) return "text/markdown";
  if (path.endsWith(".json")) return "application/json";
  return "text/plain";
};

// FNV-1a keeps a skill in one shard for as long as its name and the shard count stay the same.
export const shardOf = (name: string, shards: number = EXECUTOR_SHARDS): number => {
  let hash = 0x811c9dc5;
  for (let i = 0; i < name.length; i++) {
    hash ^= name.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash % shards;
};

const tokens = (text: string): string[] =>
  text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((token) => token.length > 1);

const score = (skill: CatalogSkill, query: string[]): number => {
  const name = skill.name.toLowerCase();
  const nameWords = new Set(tokens(skill.name));
  const descriptionWords = new Set(tokens(skill.description));
  let total = 0;
  let matched = 0;
  for (const token of query) {
    let hit = 0;
    if (name === token) hit += 20;
    if (nameWords.has(token)) hit += 8;
    else if (name.includes(token)) hit += 4;
    if (descriptionWords.has(token)) hit += 3;
    else if (skill.description.toLowerCase().includes(token)) hit += 1;
    if (hit > 0) matched++;
    total += hit;
  }
  if (matched === 0) return 0;
  return total + (matched === query.length ? 10 : 0);
};

export const searchSkills = (skills: readonly CatalogSkill[], query: string, limit: number): SearchResult[] => {
  const words = tokens(query);
  const ranked =
    words.length === 0
      ? [...skills].sort((a, b) => a.name.localeCompare(b.name))
      : skills
          .map((skill) => ({ skill, score: score(skill, words) }))
          .filter((item) => item.score > 0)
          .sort((a, b) => b.score - a.score || a.skill.name.localeCompare(b.skill.name))
          .map((item) => item.skill);
  return ranked.slice(0, limit).map((skill) => ({
    name: skill.name,
    description: skill.description,
    files: skillFiles(skill).length,
  }));
};

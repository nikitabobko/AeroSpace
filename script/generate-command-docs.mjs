#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const sourcePath = path.join(root, "docs", "commands.mdx");
const swiftHelpPath = path.join(root, "Sources", "Common", "cmdHelpGenerated.swift");
const swiftDescriptionsPath = path.join(root, "Sources", "Cli", "subcommandDescriptionsGenerated.swift");
const manDir = path.join(root, ".man");

const source = fs.readFileSync(sourcePath, "utf8");
const decodeEntities = (value) => value.replaceAll("&lt;", "<").replaceAll("&gt;", ">");
const commandPattern = /^## ([a-z0-9-]+)\n\n([^#\n][^\n]*)\n\n### Synopsis\n\n```shell\n([\s\S]*?)\n```([\s\S]*?)(?=^## [a-z0-9-]+\n|(?![\s\S]))/gm;
const commands = [];
const names = new Set();
let match;

while ((match = commandPattern.exec(source)) !== null) {
  const [, name, description, synopsis, body] = match;
  if (names.has(name)) throw new Error(`Duplicate command: ${name}`);
  if (!synopsis.split("\n").every((line) => line.trim() === "" || /^flightdeck(?:\s|$)/.test(line) || /^\s+/.test(line))) {
    throw new Error(`${name}: synopsis entries must begin with "flightdeck" and continuations must be indented`);
  }
  if (/include::|^\[source|^={1,4} |::\s*$/m.test(body)) {
    throw new Error(`${name}: unsupported AsciiDoc syntax remains`);
  }
  names.add(name);
  commands.push({ name, description: decodeEntities(description).replaceAll("`", ""), synopsis, body: body.trim() });
}

if (commands.length < 42) {
  throw new Error(`Expected at least 42 command sections, found ${commands.length}`);
}

const unmatched = [...source.matchAll(/^## ([a-z0-9-]+)$/gm)]
  .map((item) => item[1])
  .filter((name) => !names.has(name));
if (unmatched.length) throw new Error(`Malformed command sections: ${unmatched.join(", ")}`);

const swiftEscape = (value) => value.replaceAll("\\", "\\\\").replaceAll('"', '\\"');
const helpName = (name) => name.replaceAll("-", "_");
const helpSynopsis = (synopsis) => {
  const lines = decodeEntities(synopsis).split("\n");
  let entry = 0;
  return lines.map((line) => {
    if (line.startsWith("flightdeck")) {
      const stripped = line.replace(/^flightdeck\s*/, "");
      return entry++ === 0 ? `    USAGE: ${stripped}` : `       OR: ${stripped}`;
    }
    return `    ${line.replace(/^ {0,3}/, "")}`;
  }).join("\n");
};

const helpOutput = [
  "// FILE IS GENERATED FROM docs/commands.mdx",
  "// TO REGENERATE THE FILE RUN generate.sh",
  "",
  ...commands.filter(({ name }) => name !== "flightdeck").map(({ name, synopsis }) =>
    `let ${helpName(name)}_help_generated = """\n${helpSynopsis(synopsis)}\n    """`
  ),
  "",
].join("\n");

const descriptionsOutput = [
  "// FILE IS GENERATED FROM docs/commands.mdx",
  "// TO REGENERATE THE FILE RUN generate.sh",
  "",
  "let subcommandDescriptions = [",
  ...commands
    .filter(({ name }) => name !== "flightdeck" && name !== "exec-and-forget")
    .map(({ name, description }) => `    ["  ${name}", "${swiftEscape(description)}"],`),
  "]",
  "",
].join("\n");

const roffEscape = (value) => value
  .replaceAll("\\", "\\e")
  .replaceAll("`", "")
  .replace(/^-/, "\\-")
  .replace(/^([.'])/, "\\&$1")
  .replaceAll("*", "")
  .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
  .replaceAll("&lt;", "<")
  .replaceAll("&gt;", ">");

const bodyToRoff = (body) => {
  const output = [];
  let inCode = false;
  for (const rawLine of body.split("\n")) {
    if (rawLine.startsWith("```")) {
      output.push(inCode ? ".fi" : ".nf");
      inCode = !inCode;
    } else if (/^### /.test(rawLine)) {
      output.push(`.SH "${roffEscape(rawLine.slice(4).toUpperCase())}"`);
    } else if (/^#### /.test(rawLine)) {
      output.push(`.SS "${roffEscape(rawLine.slice(5))}"`);
    } else if (/^- /.test(rawLine)) {
      output.push(".IP \\(bu 2", roffEscape(rawLine.slice(2)));
    } else if (/^\d+\. /.test(rawLine)) {
      output.push(".IP", roffEscape(rawLine.replace(/^\d+\. /, "")));
    } else if (rawLine.trim()) {
      output.push(roffEscape(rawLine));
    } else {
      output.push(".PP");
    }
  }
  return output.join("\n");
};

fs.mkdirSync(manDir, { recursive: true });
for (const file of fs.readdirSync(manDir)) fs.rmSync(path.join(manDir, file), { recursive: true });

for (const command of commands) {
  const manName = command.name === "flightdeck" ? "flightdeck" : `flightdeck-${command.name}`;
  const synopsis = command.synopsis.split("\n").map(roffEscape).join("\n.br\n");
  const output = [
    `.TH "${manName.toUpperCase()}" "1" "June 2026" "FlightDeck" "FlightDeck Manual"`,
    ".SH NAME",
    `${manName} \\- ${roffEscape(command.description)}`,
    ".SH SYNOPSIS",
    ".nf",
    synopsis,
    ".fi",
    ".SH DESCRIPTION",
    roffEscape(command.description),
    bodyToRoff(command.body),
    ".SH RESOURCES",
    "Project homepage: https://flightdeck.saad.sh/",
    ".br",
    "Guide: https://flightdeck.saad.sh/guide",
    ".SH BUGS",
    "Report bugs at https://github.com/saadjs/FlightDeck/issues",
    ".SH LICENSE",
    "MIT License",
    "",
  ].join("\n");
  fs.writeFileSync(path.join(manDir, `${manName}.1`), output);
}

fs.writeFileSync(swiftHelpPath, helpOutput);
fs.writeFileSync(swiftDescriptionsPath, descriptionsOutput);
console.log(`Generated Swift help and ${commands.length} manpages from docs/commands.mdx`);

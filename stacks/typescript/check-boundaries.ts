// Mechanical architecture rules. Each failure message says how to fix it.
import { Glob } from "bun";

const failures: string[] = [];
const glob = new Glob("src/**/*.ts");

for await (const path of glob.scan(".")) {
  const text = await Bun.file(path).text();
  const isTest = path.endsWith(".test.ts");
  const lines = text.split("\n");

  lines.forEach((line, i) => {
    const where = `${path}:${i + 1}`;
    const code = line.replace(/\/\/.*$/, "");

    if (path.startsWith("src/features/") && !isTest && /\bthrow\b/.test(code)) {
      failures.push(
        `${where} uses throw. Feature code returns Result<T, E>: use err({ type: "..." }) from src/contracts/result.ts.`,
      );
    }

    const imp = code.match(/from\s+["']([^"']+)["']/);
    if (!imp?.[1]) return;
    const spec = imp[1];

    if (path.startsWith("src/contracts/") && spec.includes("features")) {
      failures.push(
        `${where} imports a feature from contracts. Move the shared type into src/contracts/.`,
      );
    }

    // From src/features/<slice>/x.ts, "../<other>/<file>" is another slice's internals.
    const slice = path.match(/^src\/features\/([^/]+)\/[^/]+$/)?.[1];
    const other = spec.match(/^\.\.\/([^./][^/]*)\/.+$/)?.[1];
    if (slice && other && other !== slice) {
      failures.push(
        `${where} reaches into slice "${other}" internals (${spec}). Import from "../${other}" (its index.ts) instead.`,
      );
    }
  });
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  console.error(`\nboundaries: ${failures.length} failure(s)`);
  process.exit(1);
}
console.log("boundaries: ok");

import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const __filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(__filename), "..");
const builder = path.join(root, "tools", "build-item-approval-workbook.mjs");

const output = execFileSync(process.execPath, [builder], {
  cwd: root,
  encoding: "utf8",
});
const buildResult = JSON.parse(output.trim().split(/\r?\n/).at(-1));
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(buildResult.outputPath));
const review = workbook.worksheets.getItem("道具审批");
const rows = review.getRange("C2:Q46").values;

const expectedItems = [
  "Protein Strip",
  "Energy Kibble",
  "Lean Can",
  "DHA Fish Oil",
  "Dental Chew",
  "Lucky Liver Bites",
  "Goat Milk Pudding",
];

for (const itemName of expectedItems) {
  const row = rows.find((candidate) => candidate[0] === itemName);
  assert.ok(row, `审批表缺少道具：${itemName}`);
  assert.ok(typeof row[13] === "string" && row[13].trim(), `${itemName} 缺少中文 EID 描述`);
  assert.ok(typeof row[14] === "string" && row[14].trim(), `${itemName} 缺少英文 EID 描述`);
}

console.log(`Verified EID export for ${expectedItems.length} pet-food items.`);

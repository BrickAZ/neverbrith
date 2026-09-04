import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const __filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(__filename), "..");
const workbookPath = path.join(root, "outputs", "item-approval", "neverbrith_item_approval_sortable.xlsx");
const previewPath = path.join(root, "outputs", "item-approval", "neverbrith_item_statistics_preview.png");

function attrs(text) {
  const result = {};
  for (const match of text.matchAll(/([\w-]+)="([^"]*)"/g)) {
    result[match[1]] = match[2];
  }
  return result;
}

function parseItems(xml) {
  const items = [];
  for (const match of xml.matchAll(/<(active|passive)\b([\s\S]*?)\/>/g)) {
    const item = attrs(match[2]);
    items.push({
      type: match[1],
      name: item.name ?? "",
      quality: item.quality ?? "未填写",
      tags: (item.tags ?? "").split(/\s+/).filter(Boolean),
    });
  }
  return items;
}

function normalizeName(name) {
  return name.toLowerCase().replace(/\s+/g, "");
}

function countBy(items, getKey) {
  const counts = new Map();
  for (const item of items) {
    const key = getKey(item);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

function rowsFromMap(counts, compare) {
  return [...counts.entries()]
    .sort(compare)
    .map(([label, count]) => [label, count]);
}

async function readApprovalStatus(workbook) {
  const approval = workbook.worksheets.getItem("道具审批");
  const used = approval.getUsedRange();
  const values = used.values;
  const header = values[0] ?? [];
  const nameIndex = header.indexOf("英文名");
  if (nameIndex === -1) {
    throw new Error("道具审批表缺少“英文名”列。");
  }

  const approvalItems = values
    .slice(1)
    .map((row) => row[nameIndex])
    .filter((name) => typeof name === "string" && name.trim());

  const styles = await workbook.inspect({
    kind: "computedStyle",
    sheetId: "道具审批",
    range: `C2:C${approvalItems.length + 1}`,
    maxChars: 100000,
  });

  let green = 0;
  let yellow = 0;
  for (const line of styles.ndjson.split(/\r?\n/)) {
    if (!line.trim()) {
      continue;
    }
    const record = JSON.parse(line);
    const fill = record.style?.fill?.color?.value ?? "";
    if (fill === "theme:9") {
      green += 1;
    } else if (fill === "FFFFFF00" || fill === "FFFF00") {
      yellow += 1;
    }
  }

  return {
    approval,
    approvalItems,
    green,
    yellow,
    uncolored: approvalItems.length - green - yellow,
  };
}

const [itemsXml, poolsXml, mainLua, input] = await Promise.all([
  fs.readFile(path.join(root, "content", "items.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "itempools.xml"), "utf8"),
  fs.readFile(path.join(root, "main.lua"), "utf8"),
  FileBlob.load(workbookPath),
]);

const workbook = await SpreadsheetFile.importXlsx(input);
const items = parseItems(itemsXml);
const approvalStatus = await readApprovalStatus(workbook);
const approvalNames = new Set(approvalStatus.approvalItems.map(normalizeName));
const sourceMissingFromApproval = items.filter((item) => !approvalNames.has(normalizeName(item.name)));
const qualityCounts = countBy(items, (item) => item.quality);
const typeCounts = countBy(items, (item) => item.type === "active" ? "主动" : "被动");
const tagCounts = new Map();
for (const item of items) {
  for (const tag of item.tags) {
    tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
  }
}

const poolEntries = [...poolsXml.matchAll(/<Item\b([^>]*)\/>/g)]
  .map((match) => attrs(match[1]).Name ?? attrs(match[1]).name ?? "")
  .filter(Boolean);
const poolNames = new Set(poolEntries.map(normalizeName));
const itemsInPool = items.filter((item) => poolNames.has(normalizeName(item.name)));
const noPoolItems = items.filter((item) => !poolNames.has(normalizeName(item.name)));
const eidStart = mainLua.indexOf("local EID_DESCRIPTIONS = {");
const eidEnd = mainLua.indexOf("local EID_LANGUAGE_ORDER", eidStart);
const eidEntryCount = eidStart === -1 || eidEnd === -1
  ? 0
  : [...mainLua.slice(eidStart, eidEnd).matchAll(/\[Items\.[A-Za-z0-9_]+\]\s*=\s*\{/g)].length;
const unfilledQuality = items.filter((item) => item.quality === "未填写");

const stats = workbook.worksheets.getOrAdd("道具统计");
for (const table of stats.tables.items) {
  table.delete();
}
stats.deleteAllDrawings();
stats.getRange("A1:H80").clear({ applyTo: "all" });
stats.showGridLines = false;
stats.freezePanes.freezeRows(2);

const titleFormat = {
  fill: "#1D4ED8",
  font: { bold: true, color: "#FFFFFF" },
  horizontalAlignment: "left",
  verticalAlignment: "center",
};
const sectionFormat = {
  fill: "#374151",
  font: { bold: true, color: "#FFFFFF" },
  horizontalAlignment: "left",
  verticalAlignment: "center",
};
const headerFormat = {
  fill: "#DBEAFE",
  font: { bold: true, color: "#1F2937" },
  horizontalAlignment: "left",
  verticalAlignment: "center",
};
const borderFormat = {
  borders: { preset: "all", style: "thin", color: "#D1D5DB" },
  verticalAlignment: "center",
  wrapText: true,
};

stats.mergeCells("A1:H1");
stats.getRange("A1").values = [["neverbrith 道具统计"]];
stats.getRange("A1:H1").format = titleFormat;
stats.getRange("A1:H1").format.rowHeight = 28;

stats.mergeCells("A2:H2");
stats.getRange("A2").values = [[
  `快照日期：${new Date().toISOString().slice(0, 10)}；源：content/items.xml、content/itempools.xml、main.lua、道具审批表。绿色状态仅读取现有审批表，不作修改。`, 
]];
stats.getRange("A2:H2").format = {
  fill: "#F3F4F6",
  font: { color: "#4B5563", italic: true },
  wrapText: true,
  verticalAlignment: "center",
};
stats.getRange("A2:H2").format.rowHeight = 30;

stats.getRange("A4:B4").merge();
stats.getRange("D4:E4").merge();
stats.getRange("G4:H4").merge();
stats.getRange("A4").values = [["基本统计"]];
stats.getRange("D4").values = [["品质分布"]];
stats.getRange("G4").values = [["道具池覆盖"]];
stats.getRange("A4:B4").format = sectionFormat;
stats.getRange("D4:E4").format = sectionFormat;
stats.getRange("G4:H4").format = sectionFormat;

const basicRows = [
  ["总道具", items.length],
  ["被动", typeCounts.get("被动") ?? 0],
  ["主动", typeCounts.get("主动") ?? 0],
  ["EID 描述条目", eidEntryCount],
  ["含标签", items.filter((item) => item.tags.length > 0).length],
  ["无标签", items.filter((item) => item.tags.length === 0).length],
];
const qualityRows = rowsFromMap(qualityCounts, ([left], [right]) => {
  const order = (value) => value === "未填写" ? 99 : Number(value);
  return order(left) - order(right);
});
const poolRows = [
  ["道具池条目", poolEntries.length],
  ["进入至少一个池", itemsInPool.length],
  ["未分配道具池", noPoolItems.length],
];

stats.getRange(`A5:B${4 + basicRows.length}`).values = basicRows;
stats.getRange(`D5:E${4 + qualityRows.length}`).values = qualityRows;
stats.getRange(`G5:H${4 + poolRows.length}`).values = poolRows;
stats.getRange(`A5:B${4 + basicRows.length}`).format = borderFormat;
stats.getRange(`D5:E${4 + qualityRows.length}`).format = borderFormat;
stats.getRange(`G5:H${4 + poolRows.length}`).format = borderFormat;

stats.getRange("A13:B13").merge();
stats.getRange("D13:E13").merge();
stats.getRange("G13:H13").merge();
stats.getRange("A13").values = [["标签分布"]];
stats.getRange("D13").values = [["审批表状态"]];
stats.getRange("G13").values = [["待同步到审批表"]];
stats.getRange("A13:B13").format = sectionFormat;
stats.getRange("D13:E13").format = sectionFormat;
stats.getRange("G13:H13").format = sectionFormat;

const tagRows = rowsFromMap(tagCounts, ([leftLabel, leftCount], [rightLabel, rightCount]) => rightCount - leftCount || leftLabel.localeCompare(rightLabel));
const statusRows = [
  ["审批表道具行", approvalStatus.approvalItems.length],
  ["绿色（用户确认可游玩）", approvalStatus.green],
  ["黄色（仅颜色统计）", approvalStatus.yellow],
  ["未着色", approvalStatus.uncolored],
  ["待同步", sourceMissingFromApproval.length],
];
const pendingRows = sourceMissingFromApproval.length > 0
  ? sourceMissingFromApproval.map((item) => [item.name, "当前源文件存在，审批表尚未有对应行"])
  : [["无", "已与当前源文件同步"]];

stats.getRange(`A14:B${13 + tagRows.length}`).values = tagRows;
stats.getRange(`D14:E${13 + statusRows.length}`).values = statusRows;
stats.getRange(`G14:H${13 + pendingRows.length}`).values = pendingRows;
stats.getRange(`A14:B${13 + tagRows.length}`).format = borderFormat;
stats.getRange(`D14:E${13 + statusRows.length}`).format = borderFormat;
stats.getRange(`G14:H${13 + pendingRows.length}`).format = borderFormat;

const qualityStart = 22;
stats.getRange(`G${qualityStart}:H${qualityStart}`).merge();
stats.getRange(`G${qualityStart}`).values = [["未填写品质"]];
stats.getRange(`G${qualityStart}:H${qualityStart}`).format = sectionFormat;
const unfilledRows = unfilledQuality.map((item) => [item.name, "quality 属性未填写"]);
stats.getRange(`G${qualityStart + 1}:H${qualityStart + unfilledRows.length}`).values = unfilledRows;
stats.getRange(`G${qualityStart + 1}:H${qualityStart + unfilledRows.length}`).format = borderFormat;

stats.getRange("A5:A40").format.horizontalAlignment = "left";
stats.getRange("B5:B40").format.horizontalAlignment = "right";
stats.getRange("D5:D40").format.horizontalAlignment = "left";
stats.getRange("E5:E40").format.horizontalAlignment = "right";
stats.getRange("G5:H40").format.horizontalAlignment = "left";
stats.getRange("A1:A40").format.columnWidth = 29;
stats.getRange("B1:B40").format.columnWidth = 13;
stats.getRange("C1:C40").format.columnWidth = 3;
stats.getRange("D1:D40").format.columnWidth = 27;
stats.getRange("E1:E40").format.columnWidth = 13;
stats.getRange("F1:F40").format.columnWidth = 3;
stats.getRange("G1:G40").format.columnWidth = 29;
stats.getRange("H1:H40").format.columnWidth = 34;
stats.getRange("A4:H40").format.rowHeight = 21;

const preview = await workbook.render({
  sheetName: "道具统计",
  range: "A1:H24",
  scale: 1,
  format: "png",
});
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(workbookPath);

console.log(JSON.stringify({
  workbookPath,
  itemCount: items.length,
  approvalRows: approvalStatus.approvalItems.length,
  greenCount: approvalStatus.green,
  pendingSync: sourceMissingFromApproval.map((item) => item.name),
  previewPath,
}));

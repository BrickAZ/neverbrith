import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");
const outputDir = path.join(root, "outputs", "item-approval");
const outputPath = path.join(outputDir, "neverbrith_item_approval.xlsx");
const fallbackOutputPath = path.join(outputDir, "neverbrith_item_approval_sortable.xlsx");

const poolNames = {
  treasure: "宝箱房",
  greedTreasure: "贪婪宝箱房",
  boss: "首领房",
  greedBoss: "贪婪白宝箱房",
  devil: "恶魔房",
  greedDevil: "贪婪恶魔房",
  angel: "天使房",
  greedAngel: "贪婪天使房",
  shop: "商店房",
  greedShop: "贪婪商店房",
  babyShop: "领养证明商店",
  secret: "隐藏房",
  greedSecret: "贪婪隐藏房",
  ultraSecret: "红隐藏房",
  curse: "刺房",
  greedCurse: "贪婪刺房",
  library: "书房",
  planetarium: "星象房",
  goldenChest: "金箱子",
  redChest: "红箱子",
  oldChest: "旧箱子",
  woodenChest: "木箱子",
  beggar: "白乞丐",
  demonBeggar: "黑乞丐",
  craneGame: "赌博乞丐",
  bombBum: "炸弹乞丐",
  keyMaster: "钥匙乞丐",
  rottenBeggar: "腐烂乞丐",
  batteryBum: "电池乞丐",
};

const tagNames = {
  angel: "天使",
  baby: "宝宝",
  battery: "电池",
  bob: "鲍勃",
  book: "书",
  dead: "死亡",
  devil: "恶魔",
  devilsacrifice: "恶魔献祭",
  fly: "苍蝇",
  food: "食物",
  guppy: "嗝屁猫",
  lazarushared: "拉撒路共享",
  lazarusharedglobal: "拉撒路全局共享",
  mom: "妈妈",
  monstermanual: "怪物手册",
  mushroom: "蘑菇",
  nocantrip: "非大罐功牌",
  nochallenge: "非挑战",
  nodaily: "非每日",
  noeden: "非伊甸",
  nogreed: "非贪婪模式",
  nokeeper: "非店主",
  nolostbr: "非游魂长子名",
  offensive: "攻击性",
  poop: "大便",
  quest: "任务",
  spider: "蜘蛛",
  stars: "星星",
  summonable: "可召唤",
  syringe: "注射器",
  tearsup: "射速上升",
  tech: "科技",
  uniquefamiliar: "独特跟班",
};

function attrs(source) {
  const result = {};
  for (const match of source.matchAll(/([A-Za-z_][\w:-]*)="([^"]*)"/g)) {
    result[match[1]] = match[2];
  }
  return result;
}

function parseItems(xml, lang) {
  const rows = [];
  const tagRegex = /<(passive|active)\b([\s\S]*?)\/>/g;
  for (const match of xml.matchAll(tagRegex)) {
    const item = attrs(match[2]);
    rows.push({
      lang,
      type: match[1],
      typeZh: match[1] === "active" ? "主动" : "被动",
      name: item.name ?? "",
      description: item.description ?? "",
      gfx: item.gfx ?? "",
      quality: item.quality ?? "",
      tags: item.tags ?? "",
      cache: item.cache ?? "",
      maxcharges: item.maxcharges ?? "",
      initcharge: item.initcharge ?? "",
      chargetype: item.chargetype ?? "",
    });
  }
  return rows;
}

function parsePools(xml, lang) {
  const rows = [];
  const poolRegex = /<Pool\b([^>]*)>([\s\S]*?)<\/Pool>/g;
  const itemRegex = /<Item\b([^>]*)\/>/g;
  for (const poolMatch of xml.matchAll(poolRegex)) {
    const pool = attrs(poolMatch[1]);
    const poolName = pool.Name ?? "";
    for (const itemMatch of poolMatch[2].matchAll(itemRegex)) {
      const item = attrs(itemMatch[1]);
      rows.push({
        lang,
        pool: poolName,
        poolZh: poolNames[poolName] ?? "",
        name: item.Name ?? "",
        weight: Number(item.Weight ?? 0),
        decreaseBy: Number(item.DecreaseBy ?? 0),
        removeOn: Number(item.RemoveOn ?? 0),
      });
    }
  }
  return rows;
}

function poolSummary(poolRows, name) {
  return poolRows
    .filter((row) => row.name === name)
    .map((row) => `${row.pool}(${row.poolZh || "?"}): ${row.weight}`)
    .join("\n");
}

function uniqueValues(rows, key) {
  return [...new Set(rows.map((row) => row[key]).filter(Boolean))];
}

const [itemsEnXml, itemsZhXml, poolsEnXml, poolsZhXml] = await Promise.all([
  fs.readFile(path.join(root, "content", "items.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "items.zh_cn.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "itempools.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "itempools.zh_cn.xml"), "utf8"),
]);

const itemsEn = parseItems(itemsEnXml, "en");
const itemsZh = parseItems(itemsZhXml, "zh_cn");
const poolsEn = parsePools(poolsEnXml, "en");
const poolsZh = parsePools(poolsZhXml, "zh_cn");

const itemRows = itemsEn.map((item, index) => {
  const zh = itemsZh[index] ?? {};
  return [
    index + 1,
    item.typeZh,
    item.name,
    zh.name ?? "",
    item.quality,
    item.tags,
    item.tags
      .split(/\s+/)
      .filter(Boolean)
      .map((tag) => `${tag}(${tagNames[tag] ?? "待核对"})`)
      .join("\n"),
    item.cache,
    item.maxcharges,
    item.initcharge,
    item.chargetype,
    poolSummary(poolsEn, item.name),
    poolSummary(poolsZh, zh.name ?? ""),
    item.description,
    zh.description ?? "",
    item.gfx,
    "",
  ];
});

const poolRows = poolsEn.map((pool, index) => {
  const zhPool = poolsZh[index] ?? {};
  return [
    index + 1,
    pool.pool,
    pool.poolZh,
    pool.name,
    zhPool.name ?? "",
    pool.weight,
    pool.decreaseBy,
    pool.removeOn,
  ];
});

const tagRows = Object.entries(tagNames).map(([en, zh]) => [en, zh]);
const poolRefRows = Object.entries(poolNames).map(([en, zh]) => [en, zh]);

const workbook = Workbook.create();
const review = workbook.worksheets.add("道具审批");
const details = workbook.worksheets.add("道具池明细");
const refs = workbook.worksheets.add("标签参考");

review.showGridLines = false;
details.showGridLines = false;
refs.showGridLines = false;

review.getRange("A1:Q1").values = [[
  "序号",
  "类型",
  "英文名",
  "中文名",
  "品质",
  "标签",
  "标签中文",
  "Cache",
  "充能",
  "初始充能",
  "充能类型",
  "英文道具池/权重",
  "中文道具池/权重",
  "英文描述",
  "中文描述",
  "贴图",
  "审批备注",
]];
review.getRange(`A2:Q${itemRows.length + 1}`).values = itemRows;

details.getRange("A1:H1").values = [[
  "序号",
  "池英文",
  "池中文",
  "道具英文名",
  "道具中文名",
  "权重",
  "DecreaseBy",
  "RemoveOn",
]];
details.getRange(`A2:H${poolRows.length + 1}`).values = poolRows;

refs.getRange("A1:B1").values = [["标签英文", "标签中文"]];
refs.getRange(`A2:B${tagRows.length + 1}`).values = tagRows;
refs.getRange("D1:E1").values = [["道具池英文", "道具池中文"]];
refs.getRange(`D2:E${poolRefRows.length + 1}`).values = poolRefRows;
refs.getRange("G1").values = [["来源/备注"]];
refs.getRange("G2:G4").values = [
  ["标签参考：https://isaac.huijiwiki.com/wiki/%E6%A0%87%E7%AD%BE"],
  ["道具池中英对照来自用户截图资料。"],
  ["主表来自 content/items.xml、content/items.zh_cn.xml、content/itempools.xml、content/itempools.zh_cn.xml。"],
];

for (const sheet of [review, details, refs]) {
  const used = sheet.getUsedRange();
  used.format.font = { name: "Microsoft YaHei", size: 10, color: "#1F2937" };
  used.format.borders = { preset: "inside", style: "thin", color: "#E5E7EB" };
}

review.getRange("A1:Q1").format = {
  fill: "#1D4ED8",
  font: { bold: true, color: "#FFFFFF", name: "Microsoft YaHei", size: 10 },
};
details.getRange("A1:H1").format = {
  fill: "#1D4ED8",
  font: { bold: true, color: "#FFFFFF", name: "Microsoft YaHei", size: 10 },
};
refs.getRange("A1:B1").format = {
  fill: "#1D4ED8",
  font: { bold: true, color: "#FFFFFF", name: "Microsoft YaHei", size: 10 },
};
refs.getRange("D1:E1").format = {
  fill: "#1D4ED8",
  font: { bold: true, color: "#FFFFFF", name: "Microsoft YaHei", size: 10 },
};
refs.getRange("G1").format = {
  fill: "#374151",
  font: { bold: true, color: "#FFFFFF", name: "Microsoft YaHei", size: 10 },
};

review.getRange(`E2:E${itemRows.length + 1}`).format.numberFormat = "0";
details.getRange(`F2:H${poolRows.length + 1}`).format.numberFormat = "0.0";
review.getRange(`A1:Q${itemRows.length + 1}`).format.wrapText = true;
details.getRange(`A1:H${poolRows.length + 1}`).format.wrapText = true;
refs.getRange(`A1:G${Math.max(tagRows.length, poolRefRows.length) + 1}`).format.wrapText = true;

review.getRange("A:A").format.columnWidth = 6;
review.getRange("B:B").format.columnWidth = 8;
review.getRange("C:D").format.columnWidth = 24;
review.getRange("E:E").format.columnWidth = 8;
review.getRange("F:G").format.columnWidth = 24;
review.getRange("H:K").format.columnWidth = 12;
review.getRange("L:M").format.columnWidth = 28;
review.getRange("N:O").format.columnWidth = 28;
review.getRange("P:P").format.columnWidth = 24;
review.getRange("Q:Q").format.columnWidth = 24;
details.getRange("A:A").format.columnWidth = 6;
details.getRange("B:C").format.columnWidth = 18;
details.getRange("D:E").format.columnWidth = 28;
details.getRange("F:H").format.columnWidth = 12;
refs.getRange("A:B").format.columnWidth = 24;
refs.getRange("D:E").format.columnWidth = 24;
refs.getRange("G:G").format.columnWidth = 72;

review.freezePanes.freezeRows(1);
details.freezePanes.freezeRows(1);
refs.freezePanes.freezeRows(1);

const approvalTable = review.tables.add(`A1:Q${itemRows.length + 1}`, true, "ItemApprovalTable");
const poolDetailTable = details.tables.add(`A1:H${poolRows.length + 1}`, true, "ItemPoolDetailTable");
const tagReferenceTable = refs.tables.add(`A1:B${tagRows.length + 1}`, true, "TagReferenceTable");
const poolReferenceTable = refs.tables.add(`D1:E${poolRefRows.length + 1}`, true, "PoolReferenceTable");
for (const table of [approvalTable, poolDetailTable, tagReferenceTable, poolReferenceTable]) {
  table.showFilterButton = true;
}

review.getRange(`E2:E${itemRows.length + 1}`).dataValidation = {
  rule: { type: "list", values: ["0", "1", "2", "3", "4"] },
};
review.getRange(`Q2:Q${itemRows.length + 1}`).dataValidation = {
  rule: { type: "list", values: ["通过", "待改名", "待改池", "待改权重", "待改标签", "待改品质"] },
};

const inspectReview = await workbook.inspect({
  kind: "table",
  range: `道具审批!A1:Q${itemRows.length + 1}`,
  include: "values",
  tableMaxRows: 5,
  tableMaxCols: 17,
  maxChars: 3000,
});
console.log(inspectReview.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 50 },
  summary: "formula error scan",
});
console.log(errors.ndjson);

const preview = await workbook.render({
  sheetName: "道具审批",
  range: `A1:Q${itemRows.length + 1}`,
  scale: 1,
  format: "png",
});
const detailPreview = await workbook.render({
  sheetName: "道具池明细",
  range: `A1:H${poolRows.length + 1}`,
  scale: 1,
  format: "png",
});
const refPreview = await workbook.render({
  sheetName: "标签参考",
  range: `A1:G${Math.max(tagRows.length, poolRefRows.length) + 1}`,
  scale: 1,
  format: "png",
});

await fs.mkdir(outputDir, { recursive: true });
await fs.writeFile(path.join(outputDir, "neverbrith_item_approval_preview.png"), new Uint8Array(await preview.arrayBuffer()));
await fs.writeFile(path.join(outputDir, "neverbrith_item_pools_preview.png"), new Uint8Array(await detailPreview.arrayBuffer()));
await fs.writeFile(path.join(outputDir, "neverbrith_item_refs_preview.png"), new Uint8Array(await refPreview.arrayBuffer()));

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
let savedPath = outputPath;
try {
  await xlsx.save(outputPath);
} catch (error) {
  if (error?.code !== "EBUSY") {
    throw error;
  }
  savedPath = fallbackOutputPath;
  await xlsx.save(fallbackOutputPath);
}

console.log(JSON.stringify({
  outputPath: savedPath,
  itemCount: itemRows.length,
  poolEntryCount: poolRows.length,
  tagsInUse: uniqueValues(itemsEn.flatMap((item) => item.tags.split(/\s+/).filter(Boolean)).map((tag) => ({ tag })), "tag").length,
}));

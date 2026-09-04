import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const __filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(__filename), "..");
const workbookPath = path.join(root, "outputs", "item-approval", "neverbrith_item_approval_sortable.xlsx");

const poolNames = {
  treasure: "宝箱房", greedTreasure: "贪婪宝箱房", boss: "首领房", greedBoss: "贪婪白宝箱房",
  devil: "恶魔房", greedDevil: "贪婪恶魔房", angel: "天使房", greedAngel: "贪婪天使房",
  shop: "商店房", greedShop: "贪婪商店房", babyShop: "领养证明商店", secret: "隐藏房",
  greedSecret: "贪婪隐藏房", ultraSecret: "红隐藏房", curse: "刺房", greedCurse: "贪婪刺房",
  library: "书房", planetarium: "星象房", goldenChest: "金箱子", redChest: "红箱子",
  oldChest: "旧箱子", woodenChest: "木箱子", beggar: "白乞丐", demonBeggar: "黑乞丐",
  craneGame: "赌博乞丐", bombBum: "炸弹乞丐", keyMaster: "钥匙乞丐", rottenBeggar: "腐烂乞丐",
  batteryBum: "电池乞丐",
};

const tagNames = {
  angel: "天使", baby: "宝宝", battery: "电池", bob: "鲍勃", book: "书", dead: "死亡",
  devil: "恶魔", devilsacrifice: "恶魔献祭", fly: "苍蝇", food: "食物", guppy: "嗝屁猫",
  lazarushared: "拉撒路共享", lazarusharedglobal: "拉撒路全局共享", mom: "妈妈",
  monstermanual: "怪物手册", mushroom: "蘑菇", nocantrip: "非大罐功牌", nochallenge: "非挑战",
  nodaily: "非每日", noeden: "非伊甸", nogreed: "非贪婪模式", nokeeper: "非店主",
  nolostbr: "非游魂长子名", offensive: "攻击性", poop: "大便", quest: "任务", spider: "蜘蛛",
  stars: "星星", summonable: "可召唤", syringe: "注射器", tearsup: "射速上升", tech: "科技",
  uniquefamiliar: "独特跟班",
};

function attrs(source) {
  const result = {};
  for (const match of source.matchAll(/([A-Za-z_][\w:-]*)="([^"]*)"/g)) {
    result[match[1]] = match[2];
  }
  return result;
}

function parseItems(xml) {
  return [...xml.matchAll(/<(passive|active)\b([\s\S]*?)\/>/g)].map((match) => {
    const item = attrs(match[2]);
    return {
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
    };
  });
}

function parsePools(xml) {
  const rows = [];
  for (const poolMatch of xml.matchAll(/<Pool\b([^>]*)>([\s\S]*?)<\/Pool>/g)) {
    const pool = attrs(poolMatch[1]);
    for (const itemMatch of poolMatch[2].matchAll(/<Item\b([^>]*)\/>/g)) {
      const item = attrs(itemMatch[1]);
      rows.push({ pool: pool.Name ?? "", name: item.Name ?? "", weight: Number(item.Weight ?? 0) });
    }
  }
  return rows;
}

function poolSummary(poolRows, name) {
  return poolRows.filter((row) => row.name === name)
    .map((row) => `${row.pool}(${poolNames[row.pool] ?? "?"}): ${row.weight}`).join("\n");
}

function unescapeLuaString(value) {
  return value.replace(/\\"/g, "\"").replace(/\\n/g, "\n").replace(/\\t/g, "\t").replace(/\\\\/g, "\\");
}

function findMatchingLuaBrace(text, openIndex) {
  let depth = 0;
  let quote = null;
  let escaped = false;
  for (let index = openIndex; index < text.length; index += 1) {
    const char = text[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === quote) quote = null;
    } else if (char === "\"" || char === "'") quote = char;
    else if (char === "{") depth += 1;
    else if (char === "}" && --depth === 0) return index;
  }
  return -1;
}

function parseEidDescriptions(lua) {
  const result = new Map();
  const tableStart = lua.indexOf("local EID_DESCRIPTIONS = {");
  const tableOpen = lua.indexOf("{", tableStart);
  const tableEnd = findMatchingLuaBrace(lua, tableOpen);
  if (tableStart === -1 || tableOpen === -1 || tableEnd === -1) return result;

  const candidates = new Map();
  const candidateBlock = lua.match(/local ITEM_NAME_CANDIDATES = \{([\s\S]*?)\n\}/);
  for (const match of candidateBlock?.[1].matchAll(/^\s*([A-Za-z0-9_]+)\s*=\s*\{([^}]*)\}/gm) ?? []) {
    for (const name of match[2].matchAll(/"((?:\\.|[^"])*)"/g)) candidates.set(unescapeLuaString(name[1]), match[1]);
  }

  const byKey = new Map();
  const tableText = lua.slice(tableOpen + 1, tableEnd);
  for (const entryMatch of tableText.matchAll(/\[Items\.([A-Za-z0-9_]+)\]\s*=\s*\{/g)) {
    const entryOpen = tableOpen + 1 + entryMatch.index + entryMatch[0].lastIndexOf("{");
    const entryEnd = findMatchingLuaBrace(lua, entryOpen);
    if (entryEnd === -1) continue;
    const localized = {};
    const entryText = lua.slice(entryOpen + 1, entryEnd);
    for (const languageMatch of entryText.matchAll(/\b(en_us|zh_cn)\s*=\s*\{/g)) {
      const languageOpen = entryOpen + 1 + languageMatch.index + languageMatch[0].lastIndexOf("{");
      const languageEnd = findMatchingLuaBrace(lua, languageOpen);
      if (languageEnd === -1) continue;
      const fields = {};
      for (const field of lua.slice(languageOpen + 1, languageEnd).matchAll(/\b(name|eidDescription)\s*=\s*"((?:\\.|[^"])*)"/g)) {
        fields[field[1]] = unescapeLuaString(field[2]);
      }
      localized[languageMatch[1]] = fields;
    }
    const en = localized.en_us;
    const zh = localized.zh_cn;
    if (en?.name && en?.eidDescription && zh?.name && zh?.eidDescription) {
      const eid = { enDescription: en.eidDescription, zhDescription: zh.eidDescription };
      byKey.set(entryMatch[1], eid);
      result.set(en.name, eid);
      result.set(zh.name, eid);
    }
  }
  for (const [name, key] of candidates) {
    if (byKey.has(key)) result.set(name, byKey.get(key));
  }
  return result;
}

function normalizeName(name) {
  return String(name).toLowerCase().replace(/\s+/g, "");
}
function descriptionRowHeight(row) {
  const displayWidth = (value) => [...String(value ?? "")].reduce(
    (total, char) => total + (char.codePointAt(0) > 0xff ? 1 : 0.55),
    0,
  );
  const widestDescription = Math.max(...[row[13], row[14], row[15], row[16]].map(displayWidth));
  return Math.max(54, Math.min(216, Math.ceil(widestDescription / 22) * 18));
}

const [itemsEnXml, itemsZhXml, poolsEnXml, poolsZhXml, mainLua, input] = await Promise.all([
  fs.readFile(path.join(root, "content", "items.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "items.zh_cn.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "itempools.xml"), "utf8"),
  fs.readFile(path.join(root, "content", "itempools.zh_cn.xml"), "utf8"),
  fs.readFile(path.join(root, "main.lua"), "utf8"),
  FileBlob.load(workbookPath),
]);

const workbook = await SpreadsheetFile.importXlsx(input);
const approval = workbook.worksheets.getItem("道具审批");
const values = approval.getUsedRange().values;
const headers = values[0] ?? [];
const expectedHeaders = ["序号", "类型", "英文名", "中文名", "品质", "标签", "标签中文", "Cache", "充能", "初始充能", "充能类型", "英文道具池/权重", "中文道具池/权重", "英文描述", "中文描述", "中文EID描述", "英文EID描述", "贴图", "审批备注"];
if (headers.join("\u0000") !== expectedHeaders.join("\u0000")) throw new Error("道具审批表列结构已变化，已停止同步以保护人工数据。");

const existingNames = new Set(values.slice(1).map((row) => normalizeName(row[2])));
const itemsEn = parseItems(itemsEnXml);
const itemsZh = parseItems(itemsZhXml);
const poolsEn = parsePools(poolsEnXml);
const poolsZh = parsePools(poolsZhXml);
const eidDescriptions = parseEidDescriptions(mainLua);
const maxSerial = Math.max(0, ...values.slice(1).map((row) => Number(row[0]) || 0));

const missing = itemsEn.map((item, index) => ({ item, zh: itemsZh[index] ?? {} }))
  .filter(({ item }) => item.name && !existingNames.has(normalizeName(item.name)));
if (missing.length === 0) {
  console.log(JSON.stringify({ workbookPath, appended: [] }));
  process.exit(0);
}

const newRows = missing.map(({ item, zh }, index) => {
  const eid = eidDescriptions.get(item.name) ?? eidDescriptions.get(zh.name) ?? {};
  return [
    maxSerial + index + 1, item.typeZh, item.name, zh.name ?? "", item.quality,
    item.tags, item.tags.split(/\s+/).filter(Boolean).map((tag) => `${tag}(${tagNames[tag] ?? "待核对"})`).join("\n"),
    item.cache, item.maxcharges, item.initcharge, item.chargetype,
    poolSummary(poolsEn, item.name), poolSummary(poolsZh, zh.name ?? ""),
    item.description, zh.description ?? "", eid.zhDescription ?? "", eid.enDescription ?? "", item.gfx, "",
  ];
});

const approvalTable = approval.tables.getItem("ItemApprovalTable");
approvalTable.rows.add(null, newRows);
const firstNewRow = values.length + 1;
const lastNewRow = firstNewRow + newRows.length - 1;

// Copy a deliberately uncolored row's layout, then restore only the new source values.
const templateRow = 27;
for (let row = firstNewRow; row <= lastNewRow; row += 1) {
  approval.getRange("A27:S27").copyTo(approval.getRange(`A${row}:S${row}`), "all");
}
approval.getRange(`A${firstNewRow}:S${lastNewRow}`).values = newRows;
approval.getRange(`A${firstNewRow}:S${lastNewRow}`).format.verticalAlignment = "top";
approval.getRange(`N${firstNewRow}:Q${lastNewRow}`).format.wrapText = true;
for (let index = 0; index < newRows.length; index += 1) {
  approval.getRange(`A${firstNewRow + index}:S${firstNewRow + index}`).format.rowHeight = descriptionRowHeight(newRows[index]);
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(workbookPath);
console.log(JSON.stringify({ workbookPath, appended: missing.map(({ item }) => item.name), firstNewRow, lastNewRow }));

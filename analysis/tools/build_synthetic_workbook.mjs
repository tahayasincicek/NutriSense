import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const root = process.cwd();
const analysis = path.join(root, "analysis");
const outputPath = path.join(root, "docs", "NutriSense_Sentetik_Saha_Calismasi.xlsx");
const readJson = async (p) => JSON.parse(await fs.readFile(p, "utf8"));
const latest = await readJson(path.join(analysis, "outputs", "synthetic", "LATEST_STATUS.json"));
const manifest = await readJson(latest.results_manifest);
const usability = (await readJson(path.join(analysis, "data", "synthetic", "usability_tidy.synthetic.json"))).rows;
const survey = (await readJson(path.join(analysis, "data", "synthetic", "survey_tidy.synthetic.json"))).rows;
const profiles = (await readJson(path.join(analysis, "data", "synthetic", "participant_profiles.synthetic.json"))).rows;

const wb = Workbook.create();
const summary = wb.worksheets.add("Özet");
const tasks = wb.worksheets.add("Görev Sonuçları");
const likert = wb.worksheets.add("Anket Özeti");
const profileSheet = wb.worksheets.add("Sentetik Profiller");
const rawTasks = wb.worksheets.add("Ham Görev Verisi");
const rawSurvey = wb.worksheets.add("Ham Anket Verisi");
const method = wb.worksheets.add("Yöntem ve Uyarı");
for (const sheet of [summary, tasks, likert, profileSheet, rawTasks, rawSurvey, method]) sheet.showGridLines = false;
summary.tabColor = "#006B57"; tasks.tabColor = "#4FAF91"; likert.tabColor = "#4FAF91"; method.tabColor = "#B7791F";

const dark = "#123043", green = "#007A62", mint = "#E7F4EF", pale = "#F4F8F7", amber = "#FFF3D6", red = "#9B2C2C";
const title = (sheet, range, text) => {
  sheet.getRange(range).merge();
  sheet.getRange(range).values = [[text]];
  sheet.getRange(range).format.font = { bold: true, size: 16, color: dark, name: "Arial" };
};
const header = (range) => {
  range.format.fill = dark;
  range.format.font = { bold: true, color: "#FFFFFF", name: "Arial", size: 10 };
  range.format.horizontalAlignment = "center";
  range.format.verticalAlignment = "center";
  range.format.borders = { preset: "inside", style: "thin", color: "#FFFFFF" };
};
const body = (range) => {
  range.format.font = { color: "#243746", name: "Arial", size: 10 };
  range.format.verticalAlignment = "center";
};

title(summary, "A2:H2", "NutriSense — Sentetik Saha Çalışması");
summary.getRange("A4:H5").merge();
summary.getRange("A4").values = [["YAPAY/SENTETİK VERİDİR. Gerçek katılımcı veya gerçek saha bulgusu içermez; ürün ve analiz hattı provasıdır."]];
summary.getRange("A4:H5").format = { fill: amber, font: { bold: true, color: red, name: "Arial", size: 11 }, wrapText: true, verticalAlignment: "center" };
summary.getRange("A7:H7").values = [["Katılımcı", "Görev kaydı", "Anket yanıtı", "NutriSense başarı", "Kontrol başarı", "Başarı farkı", "Süre farkı (sn)", "Kalite uyarısı"]];
header(summary.getRange("A7:H7"));
const ns = manifest.results["condition.nutrisense"].values;
const ctrl = manifest.results["condition.standardized_assistance"].values;
const ps = manifest.results["primary.success"].values;
const pd = manifest.results["primary.duration"].values;
summary.getRange("A8:H8").values = [[profiles.length, usability.length, survey.length, ns.independent_success_rate, ctrl.independent_success_rate, ps.effect, pd.effect, manifest.quality_warnings.length]];
body(summary.getRange("A8:H8"));
summary.getRange("D8:F8").format.numberFormat = "0.0%";
summary.getRange("A11:C13").values = [["Koşul", "Bağımsız başarı", "Medyan süre (sn)"], ["NutriSense", ns.independent_success_rate, ns.successful_duration_median_seconds], ["Standartlaştırılmış yardım", ctrl.independent_success_rate, ctrl.successful_duration_median_seconds]];
header(summary.getRange("A11:C11")); body(summary.getRange("A12:C13")); summary.getRange("B12:B13").format.numberFormat = "0.0%";
const chart = summary.charts.add("bar", summary.getRange("A11:B13"));
chart.title = "Bağımsız görev başarı oranı"; chart.titleTextStyle.typeface = "Arial"; chart.hasLegend = false;
chart.yAxis = { numberFormatCode: "0%", numberFormatSourceLinked: false, textStyle: { typeface: "Arial" } };
chart.setPosition("E11", "L26");
summary.getRange("A16:C21").values = [["İzlenebilirlik", "Değer", "Açıklama"], ["Analiz koşusu", manifest.analysis_run_id, "Sabit girdiye bağlı koşu kimliği"], ["Plan", manifest.analysis_plan_version, "Ön analiz planı"], ["Pipeline", manifest.pipeline_version, "Analiz kodu sürümü"], ["SHA-256", manifest.inputs.combined_checksum_sha256, "Birleşik girdi özeti"], ["Sentetik", true, "Her artefakta true"]];
header(summary.getRange("A16:C16")); body(summary.getRange("A17:C21"));

title(tasks, "A2:J2", "Görev Bazlı Sentetik Sonuçlar");
tasks.getRange("A4:J4").values = [["Görev", "Koşul", "Deneme", "Bağımsız başarı", "GA alt", "GA üst", "Medyan süre", "IQR", "p ham", "p Holm"]];
header(tasks.getRange("A4:J4"));
const taskRows = [];
for (const id of ["t1", "t2", "t3", "t4", "t5", "t6"]) for (const condition of ["nutrisense", "standardized_assistance"]) {
  const v = manifest.results[`task.${id}.${condition}`].values;
  taskRows.push([id, condition, v.attempts, v.independent_success_rate, v.success_ci95_low, v.success_ci95_high, v.duration_median_seconds, v.duration_iqr_seconds, v.paired_duration_p_raw, v.paired_duration_p_holm_6_tasks]);
}
tasks.getRangeByIndexes(4, 0, taskRows.length, 10).values = taskRows; body(tasks.getRange("A5:J16")); tasks.getRange("D5:F16").format.numberFormat = "0.0%"; tasks.freezePanes.freezeRows(4);

title(likert, "A2:J2", "Sentetik Anket Dağılımları");
likert.getRange("A4:K4").values = [["Madde", "n", "Medyan", "Q1", "Q3", "IQR", "1", "2", "3", "4", "5"]];
header(likert.getRange("A4:K4"));
const likertRows = ["q2", "q3", "q4", "q8"].map(id => { const v = manifest.results[`survey.${id}`].values; return [id, v.n, v.median, v.q1, v.q3, v.iqr, v.count_1, v.count_2, v.count_3, v.count_4, v.count_5]; });
likert.getRangeByIndexes(4, 0, likertRows.length, 11).values = likertRows; body(likert.getRange("A5:K8"));
likert.getRange("A11:C11").values = [["q5 yanıtı", "Sayı", "Oran"]]; header(likert.getRange("A11:C11"));
const q5 = new Map(); for (const row of survey.filter(r => r.question_id === "q5")) q5.set(row.answer, (q5.get(row.answer) || 0) + 1);
const q5Rows = [...q5.entries()].map(([answer, count]) => [answer, count, count / profiles.length]);
likert.getRangeByIndexes(11, 0, q5Rows.length, 3).values = q5Rows; body(likert.getRangeByIndexes(11, 0, q5Rows.length, 3)); likert.getRangeByIndexes(11, 2, q5Rows.length, 1).format.numberFormat = "0.0%";

const profileHeaders = Object.keys(profiles[0]);
profileSheet.getRangeByIndexes(0, 0, 1, profileHeaders.length).values = [profileHeaders]; header(profileSheet.getRangeByIndexes(0, 0, 1, profileHeaders.length));
profileSheet.getRangeByIndexes(1, 0, profiles.length, profileHeaders.length).values = profiles.map(r => profileHeaders.map(h => r[h] ?? null)); body(profileSheet.getRangeByIndexes(1, 0, profiles.length, profileHeaders.length)); profileSheet.freezePanes.freezeRows(1);

const taskHeaders = Object.keys(usability[0]);
rawTasks.getRangeByIndexes(0, 0, 1, taskHeaders.length).values = [taskHeaders]; header(rawTasks.getRangeByIndexes(0, 0, 1, taskHeaders.length));
rawTasks.getRangeByIndexes(1, 0, usability.length, taskHeaders.length).values = usability.map(r => taskHeaders.map(h => r[h] ?? null)); body(rawTasks.getRangeByIndexes(1, 0, usability.length, taskHeaders.length)); rawTasks.freezePanes.freezeRows(1);

const surveyHeaders = Object.keys(survey[0]);
rawSurvey.getRangeByIndexes(0, 0, 1, surveyHeaders.length).values = [surveyHeaders]; header(rawSurvey.getRangeByIndexes(0, 0, 1, surveyHeaders.length));
rawSurvey.getRangeByIndexes(1, 0, survey.length, surveyHeaders.length).values = survey.map(r => surveyHeaders.map(h => r[h] ?? null)); body(rawSurvey.getRangeByIndexes(1, 0, survey.length, surveyHeaders.length)); rawSurvey.freezePanes.freezeRows(1);

title(method, "A2:F2", "Yöntem, Kullanım Sınırı ve Yeniden Üretim");
const methodRows = [
  ["Veri niteliği", "Tamamı yapaydır; gerçek insan gözlemi yoktur."],
  ["Örneklem", `${profiles.length} sentetik profil; 6 görev × 2 koşul.`],
  ["Tohum", 2209],
  ["Tasarım", "Aynı profil içinde eşleştirilmiş AB/BA çapraz tasarım."],
  ["Birincil ölçüt", "Başarı=true ve assistance_level=none; bağımsız başarı."],
  ["İstatistik", "Katılımcı düzeyi sign-flip permutation, bootstrap %95 GA, Holm düzeltmesi."],
  ["Kullanım", "Analiz hattı, demo, tablo ve sunum provası."],
  ["Yasak iddia", "Gerçek saha sonucu, kullanıcı kanıtı, klinik yarar veya genellenebilir etki olarak sunulamaz."],
  ["Gerçek çalışma", "Onamlı katılımcı verisi data_origin=participant ve geçerli onay referansı ile ayrıca toplanmalıdır."],
  ["Üretim komutu", "python analysis/tools/generate_synthetic_fixture.py --output analysis/data/synthetic --participants 120 --seed 2209"],
  ["Analiz komutu", manifest.command],
];
method.getRange("A4:B4").values = [["Başlık", "Açıklama"]]; header(method.getRange("A4:B4"));
method.getRangeByIndexes(4, 0, methodRows.length, 2).values = methodRows; body(method.getRangeByIndexes(4, 0, methodRows.length, 2)); method.getRangeByIndexes(4, 1, methodRows.length, 1).format.wrapText = true;
method.getRange("A17:F19").merge(); method.getRange("A17").values = [["Bu dosyadaki sayılar sentetik veri üretim varsayımlarının sonucudur. Dosya paylaşılırken bu sayfa ve Özet sayfasındaki uyarı kaldırılmamalıdır."]]; method.getRange("A17:F19").format = { fill: amber, font: { bold: true, color: red, name: "Arial" }, wrapText: true, verticalAlignment: "center" };

for (const sheet of [summary, tasks, likert, profileSheet, rawTasks, rawSurvey, method]) {
  const used = sheet.getUsedRange(); if (used) { used.format.autofitColumns(); used.format.autofitRows(); }
}
summary.getRange("A:A").format.columnWidth = 24; summary.getRange("B:C").format.columnWidth = 22; method.getRange("A:A").format.columnWidth = 22; method.getRange("B:B").format.columnWidth = 80;
rawTasks.getUsedRange().format.rowHeight = 18; rawSurvey.getUsedRange().format.rowHeight = 18; profileSheet.getUsedRange().format.rowHeight = 18;
wb.recalculate();
const checks = await wb.inspect({ kind: "table", range: "Özet!A1:H21", include: "values,formulas", tableMaxRows: 24, tableMaxCols: 12, maxChars: 8000 });
console.log(checks.ndjson || checks);
const errors = await wb.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 100 }, summary: "final formula error scan" });
console.log(errors.ndjson || errors);
await fs.mkdir(path.dirname(outputPath), { recursive: true });
const preview = await wb.render({ sheetName: "Özet", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile(path.join(analysis, "outputs", "synthetic", "workbook_preview.png"), new Uint8Array(await preview.arrayBuffer()));
const output = await SpreadsheetFile.exportXlsx(wb); await output.save(outputPath);
console.log(outputPath);

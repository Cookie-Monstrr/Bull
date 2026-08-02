import React, { useState, useEffect, useRef } from "https://esm.sh/react@18.3.1";
/* ---------- icons (self-contained, no external icon package) ---------- */
const IconBase = ({ children, size = 20, ...p }) => (React.createElement("svg", { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", ...p }, children));
const Flame = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" }));
const Wind = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M9.59 4.59A2 2 0 1 1 11 8H2" }),
    React.createElement("path", { d: "M12.59 19.41A2 2 0 1 0 14 16H2" }),
    React.createElement("path", { d: "M17.73 7.73A2.5 2.5 0 1 1 19.5 12H2" }));
const Shield = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" }));
const BookOpen = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M2 4h6a4 4 0 0 1 4 4v12a3 3 0 0 0-3-3H2z" }),
    React.createElement("path", { d: "M22 4h-6a4 4 0 0 0-4 4v12a3 3 0 0 1 3-3h7z" }));
const SettingsIcon = (p) => React.createElement(IconBase, { ...p },
    React.createElement("circle", { cx: "12", cy: "12", r: "3" }),
    React.createElement("path", { d: "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" }));
const Check = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M20 6 9 17l-5-5" }));
const Plus = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M12 5v14M5 12h14" }));
const Trash2 = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M3 6h18" }),
    React.createElement("path", { d: "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" }),
    React.createElement("path", { d: "M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" }),
    React.createElement("path", { d: "M10 11v6M14 11v6" }));
const ChevronDown = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "m6 9 6 6 6-6" }));
const BarChart3 = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M3 3v18h18" }),
    React.createElement("rect", { x: "7", y: "12", width: "3", height: "6" }),
    React.createElement("rect", { x: "12", y: "8", width: "3", height: "10" }),
    React.createElement("rect", { x: "17", y: "5", width: "3", height: "13" }));
const Pencil = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M12 20h9" }),
    React.createElement("path", { d: "M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z" }));
const Zap = (p) => React.createElement(IconBase, { ...p },
    React.createElement("path", { d: "M13 2 3 14h9l-1 8 10-12h-9z" }));
/* ---------- storage (browser localStorage — persists on-device between visits) ---------- */
const KEY = "bull-tracker-data";
async function storageGet() {
    try {
        const raw = window.localStorage.getItem(KEY);
        return raw ? JSON.parse(raw) : null;
    }
    catch (e) {
        return null;
    }
}
async function storageSet(obj) {
    try {
        window.localStorage.setItem(KEY, JSON.stringify(obj));
    }
    catch (e) {
        console.error("save failed", e);
    }
}
async function storageClear() {
    try {
        window.localStorage.removeItem(KEY);
    }
    catch (e) { }
}
/* ---------- dates ---------- */
const pad = (n) => String(n).padStart(2, "0");
const dateKey = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const todayKey = () => dateKey(new Date());
const DAY_MS = 86400000;
const WD = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
function hijriDay(date) {
    try {
        const s = new Intl.DateTimeFormat("en-u-ca-islamic", { day: "numeric" }).format(date);
        const n = parseInt(s, 10);
        return isNaN(n) ? null : n;
    }
    catch (e) {
        return null;
    }
}
function fastingSuggested(date, lunarOnly) {
    const h = hijriDay(date);
    const lunar = h !== null && h >= 13 && h <= 15;
    if (lunarOnly)
        return lunar;
    const dow = date.getDay();
    return dow === 1 || dow === 4 || lunar;
}
/* ---------- reminders (.ics export — no backend available for real push) ---------- */
function icsDate(d) {
    return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "T" + pad(d.getHours()) + pad(d.getMinutes()) + "00";
}
function buildReminderEvent(uid, title, timeStr) {
    const [hh, mm] = (timeStr || "08:00").split(":").map((n) => parseInt(n, 10));
    const start = new Date();
    start.setHours(hh, mm, 0, 0);
    if (start.getTime() < Date.now())
        start.setDate(start.getDate() + 1);
    const end = new Date(start.getTime() + 15 * 60000);
    return [
        "BEGIN:VEVENT",
        "UID:" + uid + "@bull.app",
        "DTSTART:" + icsDate(start),
        "DTEND:" + icsDate(end),
        "RRULE:FREQ=DAILY",
        "SUMMARY:" + title,
        "BEGIN:VALARM",
        "TRIGGER:PT0M",
        "ACTION:DISPLAY",
        "DESCRIPTION:" + title,
        "END:VALARM",
        "END:VEVENT",
    ].join("\r\n");
}
function downloadReminderIcs(settings) {
    const ics = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Bull//Reminders//EN",
        buildReminderEvent("bull-morning", "Bull \u2014 Morning Check-In", settings.morningReminderTime),
        buildReminderEvent("bull-evening", "Bull \u2014 Evening Review", settings.eveningReminderTime),
        "END:VCALENDAR",
    ].join("\r\n");
    const blob = new Blob([ics], { type: "text/calendar" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "bull-reminders.ics";
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 5000);
}
/* ---------- colours ---------- */
const TEAL = "#e0b040"; /* gold — primary accent */
const AMBER = "#e0b040"; /* gold — vigour */
const ROSE = "#dc2626"; /* crimson — danger */
/* ---------- ambient color utilities ---------- */
function hexToRgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function lerpN(a, b, t) { return a + (b - a) * t; }
function mixHex(h1, h2, t) {
    const a = hexToRgb(h1), b = hexToRgb(h2);
    const to2 = (n) => Math.round(n).toString(16).padStart(2, "0");
    return "#" + to2(lerpN(a[0], b[0], t)) + to2(lerpN(a[1], b[1], t)) + to2(lerpN(a[2], b[2], t));
}
const CAUTION = "#b45309";
/* ---------- weights ---------- */
const W_RISK = { high: 20, med: 10, low: 5 };
const W_PROT = { high: 8, med: 5, low: 2 };
const W_ADH = { high: 3, med: 2, low: 1 };
const WEIGHT_SCALE = { high: 1, med: 0.6, low: 0.3 };
/* ---------- default items ---------- */
const DEFAULT_ITEMS = [
    { id: "lonely", label: "Home Alone, Unstructured Time", list: "prev", kind: "risk", weight: "high", freq: "daily" },
    { id: "junk", label: "Junk Food", list: "prev", kind: "risk", weight: "med", freq: "daily" },
    { id: "caffeine", label: "Caffeine", list: "prev", kind: "risk", weight: "med", freq: "daily" },
    { id: "coldplunge", label: "Cold Plunge", list: "prev", kind: "habit", weight: "med", freq: "daily" },
    { id: "nasalclear", label: "Nasal Rinse", list: "prev", kind: "habit", weight: "med", freq: "daily" },
    { id: "contentAccess", label: "Content Access", sub: "Low / Medium / High, logged daily", list: "prev", kind: "tier", weight: "high" },
    { id: "checkout", label: "Checking Out Women", sub: "None / A Few / A Lot, logged daily", list: "prev", kind: "tier", weight: "high" },
    { id: "recoveryLow", label: "Recovery Below 40%", sub: "Auto — from your Recovery Score", list: "prev", kind: "derived", weight: "med" },
    { id: "purposeLow", label: "Low-Purpose Day (1–2)", sub: "Auto — from your Evening Review", list: "prev", kind: "derived", weight: "med" },
    { id: "purposeHigh", label: "High-Purpose Day (4–5)", sub: "Auto — protective, from your Evening Review", list: "prev", kind: "derived", weight: "med" },
    { id: "accountabilityGap", label: "Accountability Not On Track", sub: "Auto — nothing booked, overdue, or too far out", list: "prev", kind: "derived", weight: "high" },
    { id: "urgeSurvivalBonus", label: "Urges Survived Today", sub: "Auto — protective, from the Urge button", list: "prev", kind: "derived", weight: "med" },
    { id: "kegels", label: "Kegels", list: "prime", kind: "habit", weight: "high", freq: [1, 3, 5, 0] },
    { id: "stretches", label: "Pelvic Floor Stretches", list: "prime", kind: "habit", weight: "med", freq: [1, 3, 5, 0] },
    { id: "cardio", label: "Cardio / Boxing", list: "prime", kind: "habit", weight: "high", freq: [1, 3, 5, 0] },
    { id: "strength", label: "Strength Training", list: "prime", kind: "habit", weight: "med", freq: [2, 6] },
    { id: "breathwork", label: "Breathwork Before Isha", list: "prime", kind: "habit", weight: "med", freq: "daily" },
    { id: "mouthtape", label: "Mouth Tape", list: "prime", kind: "habit", weight: "low", freq: "daily" },
    { id: "fasting", label: "Fasting", list: "prime", kind: "habit", weight: "med", freq: "daily", fastingAuto: true },
];
const DEFAULT_PURPOSE = "I am preparing for her before I have met her. Every clean day is me becoming the man and husband I intend to be on day one — clear-eyed, disciplined, present.\n\nThis urge is a wave. It rises, it peaks, it passes. I do not act on it. I am building something better.";
const DEFAULT_SETTINGS = {
    purposeText: DEFAULT_PURPOSE,
    supplements: ["Zinc", "Magnesium", "Vitamin D"],
    therapistEveryWeeks: 2,
    nextCheckin: null,
    manualLastRelapseDate: null,
    fastLunarOnly: false,
    morningReminderTime: "08:00",
    eveningReminderTime: "21:30",
};
const emptyDay = () => ({
    checks: {}, access: null, checkout: null,
    intentionText: "", intentionSet: false, purposeRating: null,
    recovery: null, sleep: null,
    supplementsTaken: {},
    sick: false, travelling: false,
});
/* ---------- migration ---------- */
function migrate(old) {
    if (!old)
        return null;
    if (old.version === 6)
        return old;
    const base = (old.version && old.version >= 2) ? old : (() => {
        const items = DEFAULT_ITEMS.map((it) => {
            const c = { ...it, freq: Array.isArray(it.freq) ? [...it.freq] : it.freq };
            if (["kegels", "stretches", "cardio"].includes(it.id) && Array.isArray(old.settings?.stackDays))
                c.freq = [...old.settings.stackDays];
            if (it.id === "strength" && Array.isArray(old.settings?.strengthDays))
                c.freq = [...old.settings.strengthDays];
            return c;
        });
        const days = {};
        Object.entries(old.days || {}).forEach(([k, d]) => {
            const checks = {};
            ["lonely", "junk", "caffeine"].forEach((f) => { if (d[f] !== null && d[f] !== undefined)
                checks[f] = d[f]; });
            if (d.lateScreen !== null && d.lateScreen !== undefined)
                checks.latescreen = d.lateScreen;
            ["kegels", "stretches", "cardio", "strength"].forEach((f) => { if (d[f])
                checks[f] = true; });
            if (d.breathing)
                checks.breathwork = true;
            if (d.mouthTape) {
                checks.mouthtape = true;
                checks.nasalclear = true;
            }
            if (d.fasted)
                checks.fasting = true;
            days[k] = {
                checks, access: d.access ?? null, checkout: d.checkout ?? null,
                intentionText: d.intentionText || "", intentionSet: !!d.intentionSet,
                purposeRating: d.purposeRating ?? null,
                recovery: d.recovery ?? null, sleep: d.sleep ?? null, steps: d.steps ?? null,
                supplementsTaken: d.supplementsTaken || {},
            };
        });
        return {
            settings: {
                purposeText: old.settings?.purposeText || DEFAULT_PURPOSE,
                supplements: old.settings?.supplements || [...DEFAULT_SETTINGS.supplements],
                therapistEveryWeeks: old.settings?.therapistEveryWeeks || 2,
                nextCheckin: null,
            },
            items, days, urges: old.urges || [], relapses: old.relapses || [], firstUse: old.firstUse || Date.now(),
        };
    })();
    if (base.settings && "lastTherapistCheckin" in base.settings) {
        const { lastTherapistCheckin, ...rest } = base.settings;
        base.settings = { ...rest, nextCheckin: base.settings.nextCheckin ?? null };
    }
    base.settings = { manualLastRelapseDate: null, fastLunarOnly: false, morningReminderTime: "08:00", eveningReminderTime: "21:30", ...base.settings };
    base.wetDreams = base.wetDreams || [];
    base.items = (base.items || []).filter((i) => i.id !== "latescreen");
    const NEW_BUILTIN_IDS = ["contentAccess", "checkout", "recoveryLow", "purposeLow", "purposeHigh", "accountabilityGap", "urgeSurvivalBonus"];
    NEW_BUILTIN_IDS.forEach((id) => {
        if (!base.items.some((i) => i.id === id)) {
            const def = DEFAULT_ITEMS.find((i) => i.id === id);
            if (def)
                base.items.push({ ...def });
        }
    });
    return { ...base, version: 6 };
}
/* ---------- scheduling ---------- */
function scheduledOn(item, date) {
    if (item.freq === "daily")
        return true;
    if (Array.isArray(item.freq))
        return item.freq.length === 0 ? true : item.freq.includes(date.getDay());
    return true;
}
function adherenceExpected(item, date, settings) {
    if (item.fastingAuto)
        return fastingSuggested(date, settings && settings.fastLunarOnly);
    return scheduledOn(item, date);
}
/* ---------- scoring ---------- */
function riskScore(day, items, urgesSurvived, hadRelapse, accountabilityPenalty = 0) {
    const d = day || emptyDay();
    const wOf = (id, fallback) => (items.find((i) => i.id === id) || {}).weight || fallback;
    const scaleOf = (id, fallback) => WEIGHT_SCALE[wOf(id, fallback)];
    let r = 15;
    items.filter((i) => i.list === "prev" && (i.kind === "risk" || i.kind === "habit")).forEach((it) => {
        const v = d.checks ? d.checks[it.id] : undefined;
        if (it.kind === "risk") {
            if (v === true)
                r += W_RISK[it.weight];
        }
        else {
            if (v === true)
                r -= W_PROT[it.weight];
        }
    });
    const accessScale = scaleOf("contentAccess", "high");
    if (d.access === "high")
        r += Math.round(25 * accessScale);
    else if (d.access === "med")
        r += Math.round(12 * accessScale);
    const checkoutScale = scaleOf("checkout", "high");
    if (d.checkout === "lot")
        r += Math.round(12 * checkoutScale);
    else if (d.checkout === "few")
        r += Math.round(4 * checkoutScale);
    if (d.recovery !== null && d.recovery !== undefined && d.recovery !== "" && Number(d.recovery) < 40) {
        r += Math.round(10 * scaleOf("recoveryLow", "med"));
    }
    if (d.purposeRating !== null && d.purposeRating !== undefined) {
        if (d.purposeRating <= 2)
            r += Math.round(10 * scaleOf("purposeLow", "med"));
        else if (d.purposeRating >= 4)
            r -= Math.round(5 * scaleOf("purposeHigh", "med"));
    }
    const urgeScale = scaleOf("urgeSurvivalBonus", "med");
    r -= Math.min((urgesSurvived || 0) * Math.round(4 * urgeScale), Math.round(12 * urgeScale));
    r += Math.round(accountabilityPenalty * scaleOf("accountabilityGap", "high"));
    if (hadRelapse)
        r = Math.max(r, 85);
    return Math.max(0, Math.min(100, r));
}
function riskLogged(day, items) {
    if (!day)
        return false;
    const anyRisk = items.some((i) => i.list === "prev" && day.checks && day.checks[i.id] !== undefined && day.checks[i.id] !== null);
    return anyRisk || day.access != null || day.checkout != null || day.purposeRating != null;
}
function vigourForDay(day, date, items, settings) {
    const d = day || emptyDay();
    let total = 0, done = 0;
    items.filter((i) => i.list === "prime" && i.kind === "habit").forEach((it) => {
        if (!adherenceExpected(it, date, settings))
            return;
        const w = W_ADH[it.weight] || 2;
        total += w;
        if (d.checks && d.checks[it.id] === true)
            done += w;
    });
    const sups = settings.supplements || [];
    if (sups.length) {
        total += 2;
        const taken = sups.filter((s) => d.supplementsTaken && d.supplementsTaken[s]).length;
        done += 2 * (taken / sups.length);
    }
    return { done, total };
}
function riskColor(r) { return r <= 25 ? TEAL : r <= 55 ? CAUTION : ROSE; }
/* ---------- UI atoms ---------- */
function Card({ children, className = "" }) {
    return React.createElement("div", { className: "rounded-2xl p-4 " + className, style: { background: "rgba(255,255,255,0.022)" } }, children);
}
function Rows({ children, className = "" }) {
    return React.createElement("div", { className: className }, children);
}
function GroupHeader({ icon: Icon, color, children }) {
    return (React.createElement("div", { className: "flex items-center gap-2 mt-10 mb-1" },
        React.createElement(Icon, { size: 13, style: { color, opacity: 0.75 } }),
        React.createElement("div", { className: "text-[11px] uppercase tracking-[0.22em] font-semibold", style: { color, opacity: 0.85 } }, children)));
}
function SectionLabel({ children }) {
    return React.createElement("div", { className: "text-[10px] uppercase tracking-[0.22em] mb-1 mt-7", style: { color: "#6a6358" } }, children);
}
function Seg({ value, options, onChange, allowClear = true }) {
    return (React.createElement("div", { className: "flex gap-1.5" }, options.map((o) => {
        const active = value === o.v;
        const tone = o.tone || "neutral";
        let style = { border: "1px solid rgba(255,255,255,0.09)", background: "transparent", color: "#6a6358" };
        if (active) {
            if (tone === "teal" || tone === "amber")
                style = { border: "1px solid var(--accent, #e0b040)", background: "var(--accent, #e0b040)", color: "#0a0705", fontWeight: 700, boxShadow: "0 0 calc(var(--vig, 0.5)*18px) rgba(224,176,64,calc(var(--vig, 0.5)*0.35))" };
            else if (tone === "warn")
                style = { border: "1px solid " + CAUTION, background: CAUTION, color: "#0a0705", fontWeight: 700 };
            else if (tone === "risk")
                style = { border: "1px solid " + ROSE, background: ROSE, color: "#fff", fontWeight: 700 };
            else
                style = { border: "1px solid #2a2622", background: "#2a2622", color: "#b5aa96", fontWeight: 700 };
        }
        return (React.createElement("button", { key: String(o.v), style: style, onClick: () => onChange(active && allowClear ? null : o.v), className: "flex-1 py-2 px-3 rounded-full text-[11px] uppercase tracking-[0.12em] transition-all" }, o.label));
    })));
}
function YesNo({ label, sub, value, onChange, mode = "risk" }) {
    const yesTone = mode === "risk" ? "risk" : mode === "vigour" ? "amber" : "teal";
    const noTone = mode === "risk" ? "teal" : "neutral";
    return (React.createElement("div", { className: "flex items-center justify-between py-4 last:border-0 gap-3", style: { borderBottom: "1px solid rgba(255,255,255,0.045)" } },
        React.createElement("div", { className: "pr-1" },
            React.createElement("div", { className: "text-[13.5px] text-neutral-300 tracking-[0.02em]" }, label),
            sub && React.createElement("div", { className: "text-[11px] text-neutral-600 mt-1 normal-case tracking-normal" }, sub)),
        React.createElement("div", { className: "w-[124px] shrink-0" },
            React.createElement(Seg, { value: value === undefined ? null : value, onChange: onChange, options: [{ v: true, label: "Yes", tone: yesTone }, { v: false, label: "No", tone: noTone }] }))));
}
function NumField({ label, value, onChange, max = 100, suffix }) {
    return (React.createElement("div", { className: "flex-1" },
        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1" }, label),
        React.createElement("div", { className: "flex items-center gap-1 rounded-xl bull-field px-3 py-2" },
            React.createElement("input", { inputMode: "numeric", value: value === null || value === undefined ? "" : value, onChange: (e) => {
                    const raw = e.target.value.replace(/[^0-9]/g, "");
                    if (raw === "")
                        return onChange(null);
                    onChange(Math.min(max, parseInt(raw, 10)));
                }, placeholder: "\u2014", className: "w-full bg-transparent text-neutral-100 text-base outline-none placeholder-neutral-600" }),
            suffix && React.createElement("span", { className: "text-xs text-neutral-500" }, suffix))));
}
function Ring({ pct, size = 68, stroke = 6, color, label, invertFill = false }) {
    const r = (size - stroke) / 2;
    const c = 2 * Math.PI * r;
    const fillPct = invertFill ? 100 - Math.max(0, Math.min(100, pct)) : Math.max(0, Math.min(100, pct));
    const off = c - (fillPct / 100) * c;
    return (React.createElement("div", { className: "flex flex-col items-center" },
        React.createElement("svg", { width: size, height: size },
            React.createElement("circle", { cx: size / 2, cy: size / 2, r: r, stroke: "#262626", strokeWidth: stroke, fill: "none" }),
            React.createElement("circle", { cx: size / 2, cy: size / 2, r: r, stroke: color, strokeWidth: stroke, fill: "none", strokeDasharray: c, strokeDashoffset: off, strokeLinecap: "round", transform: `rotate(-90 ${size / 2} ${size / 2})`, style: { transition: "stroke-dashoffset 0.6s" } }),
            React.createElement("text", { x: "50%", y: "52%", dominantBaseline: "middle", textAnchor: "middle", fill: "#e5e5e5", fontSize: size / 4.2, fontFamily: "ui-monospace, monospace", fontWeight: "700" }, Math.round(pct))),
        label && React.createElement("div", { className: "text-[10px] uppercase tracking-widest text-neutral-500 mt-1 font-semibold" }, label)));
}
/* ---------- score visuals: shield (risk) + fruit (vigour) ---------- */
function ShieldRisk({ risk, size = 68 }) {
    const protection = 100 - Math.max(0, Math.min(100, risk));
    const top = 92 - (82 * protection) / 100;
    const color = riskColor(risk);
    const crackOpacity = Math.max(0, Math.min(1, (risk - 60) / 30));
    const cid = "shieldClip" + size;
    return (React.createElement("div", { className: "flex flex-col items-center" },
        React.createElement("svg", { width: size, height: size, viewBox: "0 0 100 100" },
            React.createElement("defs", null,
                React.createElement("clipPath", { id: cid },
                    React.createElement("path", { d: "M50 10 L84 21 C84 50, 75 76, 50 92 C25 76, 16 50, 16 21 Z" }))),
            React.createElement("path", { d: "M50 10 L84 21 C84 50, 75 76, 50 92 C25 76, 16 50, 16 21 Z", fill: "#171717", stroke: "#2a231a", strokeWidth: "2" }),
            React.createElement("g", { clipPath: `url(#${cid})` },
                React.createElement("rect", { x: 0, y: top, width: 100, height: 100, fill: color, style: { transition: "y 0.6s, fill 0.6s" } }),
                React.createElement("rect", { x: 0, y: top, width: 100, height: 1.6, fill: "#f5cf7e", opacity: 0.6, style: { transition: "y 0.6s" } })),
            React.createElement("circle", { cx: 50, cy: 44, r: 5.5, fill: "#050403", opacity: 0.5 }),
            React.createElement("g", { stroke: "#050403", strokeWidth: "1.6", fill: "none", strokeLinecap: "round", opacity: crackOpacity, style: { transition: "opacity 0.6s" } },
                React.createElement("path", { d: "M36 26 L42 36 L38 44" }),
                React.createElement("path", { d: "M64 58 L58 66 L62 76" })),
            React.createElement("path", { d: "M50 10 L84 21 C84 50, 75 76, 50 92 C25 76, 16 50, 16 21 Z", fill: "none", stroke: "#3a2f22", strokeWidth: "2" })),
        React.createElement("div", { className: "text-[10px] uppercase tracking-widest text-neutral-500 mt-1 font-semibold" }, "Risk \u00B7 ", Math.round(risk))));
}
const FRUIT_BODY_D = "M46 24 C40 30, 38 40, 39 50 C40 60, 34 64, 33 72 C32 82, 40 89, 50 90 C60 89, 68 82, 67 72 C66 63, 61 59, 60 50 C59 40, 58 30, 54 24 C51 22, 48 22, 46 24 Z";
function VigourFruit({ pct, size = 68 }) {
    const v = Math.max(0, Math.min(100, pct));
    const t = v / 100;
    const rot = 46 * (1 - t);
    const sx = 0.84 + 0.16 * t;
    const sy = 0.92 + 0.08 * t;
    const throbbing = v >= 90;
    return (React.createElement("div", { className: "flex flex-col items-center" },
        React.createElement("div", { style: { position: "relative", width: size, height: size } },
            React.createElement("div", { style: { position: "absolute", inset: 0, transformOrigin: "50% 88%", transform: `rotate(${rot}deg)`, transition: "transform 0.6s" } },
                React.createElement("div", { className: throbbing ? "bull-fruit-throb" : "", style: throbbing ? undefined : { transform: `scale(${sx},${sy})`, transition: "transform 0.6s" } },
                    React.createElement("svg", { width: size, height: size, viewBox: "0 0 100 100" },
                        React.createElement("defs", null,
                            React.createElement("linearGradient", { id: `vFruitGrad${size}`, x1: "0%", y1: "0%", x2: "100%", y2: "100%" },
                                React.createElement("stop", { offset: "0%", stopColor: "#f5cf7e" }),
                                React.createElement("stop", { offset: "100%", stopColor: "#c8912e" }))),
                        React.createElement("g", { transform: "translate(50 50) scale(0.76) translate(-49.54 -53.5)" },
                            React.createElement("path", { fill: `url(#vFruitGrad${size})`, d: FRUIT_BODY_D }),
                            React.createElement("path", { fill: "#f5cf7e", opacity: 0.12 + 0.4 * Math.max(0, t - 0.5), d: FRUIT_BODY_D, style: { transition: "opacity 0.6s" } }),
                            React.createElement("path", { fill: "#8a6218", d: "M36 26 L42 16 L47 22 L50 10 L54 21 L61 17 L58 27 C52 31, 43 31, 36 26 Z" }),
                            React.createElement("path", { fill: "#8a6218", d: "M49 12 C49 8, 51 5, 54 3 L57 6 C54 8, 53 11, 53 14 Z" }),
                            React.createElement("g", { fill: "none", strokeLinecap: "round", opacity: 0.35 + 0.65 * t, style: { transition: "opacity 0.6s" } },
                                React.createElement("path", { stroke: "#8a6218", strokeWidth: "3.4", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                React.createElement("path", { stroke: "#8a6218", strokeWidth: "2.8", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                React.createElement("path", { stroke: "#8a6218", strokeWidth: "2", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" })),
                            React.createElement("ellipse", { cx: 60, cy: 66, rx: 3.2, ry: 6.5, fill: "#f7e2ae", opacity: 0.85, transform: "rotate(18 60 66)" })))))),
        React.createElement("div", { className: "text-[10px] uppercase tracking-widest text-neutral-500 mt-1 font-semibold" }, "Vigour \u00B7 ", Math.round(v))));
}
/* ---------- splash screen ---------- */
const SPLASH_CSS = `
.bull-splash{position:relative;width:100%;max-width:430px;height:100dvh;margin:0 auto;display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden;background:#050403;font-family:'JetBrains Mono',monospace;}
.bull-splash .glow{position:absolute;inset:-20%;background:radial-gradient(circle at 50% 42%,#2a0f06 0%,#050403 62%);opacity:0;transition:opacity 1.4s ease;}
.bull-splash.on .glow{opacity:1;}
.bull-splash .pulse{position:absolute;top:42%;left:50%;width:min(72vw,300px);height:min(72vw,300px);transform:translate(-50%,-50%);border-radius:50%;background:radial-gradient(circle,rgba(224,176,64,0.35) 0%,rgba(224,176,64,0) 70%);opacity:0;}
.bull-splash.on .pulse{opacity:1;animation:bsBreathe 1.9s ease-in-out 3s infinite;}
@keyframes bsBreathe{0%,100%{transform:translate(-50%,-50%) scale(0.92);opacity:.5;}14%{transform:translate(-50%,-50%) scale(1.05);opacity:.85;}38%{transform:translate(-50%,-50%) scale(1.1);opacity:.95;}58%{transform:translate(-50%,-50%) scale(0.95);opacity:.55;}}
.bull-splash .mark{position:relative;width:min(66vw,260px);aspect-ratio:1;margin-top:-6vh;}
.bull-splash.on .mark{animation:bsJolt .16s linear 2.1s 2;}
@keyframes bsJolt{0%,100%{transform:translate(0,0);}25%{transform:translate(1.5px,-1px);}50%{transform:translate(-1.5px,1px);}75%{transform:translate(1px,1px);}}
.bull-splash .mark svg{position:absolute;inset:0;width:100%;height:100%;display:block;}
.bull-splash .ring-track{fill:none;stroke:#1c1712;stroke-width:3;}
.bull-splash .ring-fill{fill:none;stroke:url(#bsGoldGrad);stroke-width:3;stroke-linecap:round;stroke-dasharray:301.6;transform:rotate(-90deg);transform-origin:50% 50%;transition:stroke-dashoffset 1.8s cubic-bezier(.65,0,.35,1) .3s;}
.bull-splash .shockwave{position:absolute;inset:0;border-radius:50%;border:2px solid #f5cf7e;opacity:0;pointer-events:none;}
.bull-splash.on .shockwave{animation:bsShock .55s ease-out 2.0s;}
@keyframes bsShock{0%{opacity:0;transform:scale(.96);}18%{opacity:.55;}100%{opacity:0;transform:scale(1.12);}}
.bull-splash .riser,.bull-splash .grow,.bull-splash .beat{position:absolute;inset:0;}
.bull-splash .riser{transform-origin:50.3% 77.7%;transform:rotate(28deg);}
.bull-splash.on .riser{animation:bsRise 3s forwards;}
@keyframes bsRise{0%{transform:rotate(28deg);animation-timing-function:ease;}16%{transform:rotate(28deg);animation-timing-function:ease-in-out;}24%{transform:rotate(25.5deg);animation-timing-function:ease-in-out;}32%{transform:rotate(27.5deg);animation-timing-function:ease-in-out;}40%{transform:rotate(23.5deg);animation-timing-function:cubic-bezier(.45,0,.15,1);}60%{transform:rotate(-4deg);animation-timing-function:ease-in-out;}70%{transform:rotate(2deg);animation-timing-function:ease-in-out;}79%{transform:rotate(-0.8deg);animation-timing-function:ease-in-out;}86%{transform:rotate(0deg);}100%{transform:rotate(0deg);}}
.bull-splash .grow{opacity:0;transform:scale(.88,.94);}
.bull-splash.on .grow{animation:bsEngorge 3s forwards;}
@keyframes bsEngorge{0%{opacity:0;transform:scale(.88,.94);}10%{opacity:1;transform:scale(.88,.94);}28%{transform:scale(.90,.945);}34%{transform:scale(.945,.955);}46%{transform:scale(.93,.95);}52%{transform:scale(1.0,.98);}62%{transform:scale(1.05,1.03);}78%{transform:scale(.995,.998);}88%{transform:scale(1,1);}100%{opacity:1;transform:scale(1,1);}}
.bull-splash.on .beat{animation:bsThrob 1.9s ease-in-out 3s infinite;}
@keyframes bsThrob{0%,100%{transform:scale(1,1);}14%{transform:scale(1.08,1.045);}26%{transform:scale(1.0,.995);}38%{transform:scale(1.11,1.055);}58%{transform:scale(1,1);}}
.bull-splash .flush-intro{opacity:0;}
.bull-splash.on .flush-intro{animation:bsFlushIntro 3s forwards;}
@keyframes bsFlushIntro{0%{opacity:0;}20%{opacity:0;}34%{opacity:.16;}52%{opacity:.28;}68%{opacity:.5;}80%{opacity:.14;}100%{opacity:.12;}}
.bull-splash .flush-beat{opacity:0;}
.bull-splash.on .flush-beat{animation:bsFlushBeat 1.9s ease-in-out 3s infinite;}
@keyframes bsFlushBeat{0%,100%{opacity:0;}14%{opacity:.16;}38%{opacity:.22;}58%{opacity:0;}}
.bull-splash .vp{stroke:#ffe9b0;fill:none;stroke-linecap:round;stroke-dasharray:16 84;stroke-dashoffset:116;opacity:0;}
.bull-splash.on .vp{animation:bsTravel .65s linear 2 forwards;}
@keyframes bsTravel{0%{stroke-dashoffset:116;opacity:0;}12%{opacity:.95;}88%{opacity:.95;}100%{stroke-dashoffset:-16;opacity:0;}}
.bull-splash.on .vp.d1{animation-delay:.5s;}
.bull-splash.on .vp.d2{animation-delay:.68s;}
.bull-splash.on .vp.d3{animation-delay:.86s;}
.bull-splash.on .vp.d4{animation-delay:1.0s;}
.bull-splash.on .vp.d5{animation-delay:1.12s;}
.bull-splash.on .vp.d6{animation-delay:1.24s;}
.bull-splash.on .vp.d7{animation-delay:1.34s;}
.bull-splash .vc{stroke:#ffe9b0;fill:none;stroke-linecap:round;stroke-dasharray:12 88;stroke-dashoffset:112;opacity:0;}
.bull-splash.on .vc{animation:bsCirculate 1.9s linear infinite;}
@keyframes bsCirculate{0%{stroke-dashoffset:112;opacity:0;}10%{opacity:.32;}90%{opacity:.32;}100%{stroke-dashoffset:-12;opacity:0;}}
.bull-splash.on .vc.c1{animation-delay:3s;}
.bull-splash.on .vc.c2{animation-delay:3.35s;}
.bull-splash.on .vc.c3{animation-delay:3.7s;}
.bull-splash .word{margin-top:22px;font-family:'Oswald',sans-serif;text-transform:uppercase;letter-spacing:0.32em;font-size:1.7rem;font-weight:700;color:#f2e6c9;opacity:0;transform:translateY(8px);transition:opacity .8s ease 2.6s,transform .8s ease 2.6s;}
.bull-splash.on .word{opacity:1;transform:translateY(0);}
.bull-splash .line{font-size:0.72rem;letter-spacing:0.18em;text-transform:uppercase;color:#7a7368;margin-top:8px;opacity:0;transition:opacity .8s ease 2.9s;}
.bull-splash.on .line{opacity:1;}
.bull-splash .stats{display:flex;gap:34px;margin-top:30px;opacity:0;transform:translateY(6px);transition:opacity .7s ease 3.2s,transform .7s ease 3.2s;}
.bull-splash.on .stats{opacity:1;transform:translateY(0);}
.bull-splash .stat{text-align:center;}
.bull-splash .stat .num{font-family:'Oswald',sans-serif;font-weight:700;font-size:1.9rem;color:#f5cf7e;line-height:1;font-variant-numeric:tabular-nums;}
.bull-splash .stat .lbl{font-size:0.6rem;letter-spacing:0.14em;text-transform:uppercase;color:#7a7368;margin-top:6px;}
.bull-splash .bsdivider{width:1px;background:#26201a;align-self:stretch;}
.bull-splash .hype{position:absolute;bottom:15%;left:0;right:0;text-align:center;padding:0 40px;font-family:'Oswald',sans-serif;text-transform:uppercase;letter-spacing:0.08em;font-size:0.98rem;font-weight:600;color:#d8c191;opacity:0;transition:opacity .9s ease 3.6s;}
.bull-splash.on .hype{opacity:1;}
@media (prefers-reduced-motion: reduce){
  .bull-splash *{animation:none !important;transition:none !important;}
  .bull-splash .riser{transform:rotate(0deg) !important;}
  .bull-splash .grow{opacity:1 !important;transform:scale(1,1) !important;}
  .bull-splash .beat{transform:scale(1,1) !important;}
  .bull-splash .glow,.bull-splash .word,.bull-splash .line,.bull-splash .stats,.bull-splash .hype{opacity:1 !important;transform:none !important;}
}
`;
const SPLASH_LINES = [
    "Discipline is rehearsal for the man you're becoming",
    "No one is coming. Show up anyway.",
    "The bull doesn't ask if it feels like charging",
];
function Splash({ vigour, risk, cleanPct, streak, onDone }) {
    const [on, setOn] = useState(false);
    const [hype] = useState(() => SPLASH_LINES[Math.floor(Math.random() * SPLASH_LINES.length)]);
    const [vigDisp, setVigDisp] = useState(0);
    const [riskDisp, setRiskDisp] = useState(0);
    const [cleanDisp, setCleanDisp] = useState(0);
    useEffect(() => {
        const raf1 = requestAnimationFrame(() => requestAnimationFrame(() => setOn(true)));
        const countStart = setTimeout(() => {
            const dur = 1300, t0 = performance.now();
            const tick = (t) => {
                const p = Math.min(1, (t - t0) / dur);
                const eased = 1 - Math.pow(1 - p, 3);
                setVigDisp(Math.round(eased * vigour));
                setRiskDisp(Math.round(eased * risk));
                setCleanDisp(Math.round(eased * cleanPct));
                if (p < 1)
                    requestAnimationFrame(tick);
            };
            requestAnimationFrame(tick);
        }, 3200);
        const done = setTimeout(onDone, 4700);
        return () => { cancelAnimationFrame(raf1); clearTimeout(countStart); clearTimeout(done); };
    }, []);
    const c = 2 * Math.PI * 48;
    const offset = c - (Math.max(0, Math.min(100, vigour)) / 100) * c;
    return (React.createElement("div", { className: "fixed inset-0 z-[70] bg-black", onClick: onDone },
        React.createElement("style", { dangerouslySetInnerHTML: { __html: SPLASH_CSS } }),
        React.createElement("div", { className: "bull-splash" + (on ? " on" : "") },
            React.createElement("div", { className: "glow" }),
            React.createElement("div", { className: "pulse" }),
            React.createElement("div", { className: "mark" },
                React.createElement("svg", { viewBox: "0 0 100 100" },
                    React.createElement("defs", null,
                        React.createElement("linearGradient", { id: "bsGoldGrad", x1: "0%", y1: "0%", x2: "100%", y2: "100%" },
                            React.createElement("stop", { offset: "0%", stopColor: "#f5cf7e" }),
                            React.createElement("stop", { offset: "100%", stopColor: "#c8912e" }))),
                    React.createElement("circle", { className: "ring-track", cx: 50, cy: 50, r: 48 }),
                    React.createElement("circle", { className: "ring-fill", cx: 50, cy: 50, r: 48, style: { strokeDashoffset: on ? offset : c } })),
                React.createElement("div", { className: "shockwave" }),
                React.createElement("div", { className: "riser" },
                    React.createElement("div", { className: "grow" },
                        React.createElement("div", { className: "beat" },
                            React.createElement("svg", { viewBox: "0 0 100 100" },
                                React.createElement("defs", null,
                                    React.createElement("linearGradient", { id: "bsGoldGradF", x1: "0%", y1: "0%", x2: "100%", y2: "100%" },
                                        React.createElement("stop", { offset: "0%", stopColor: "#f5cf7e" }),
                                        React.createElement("stop", { offset: "100%", stopColor: "#c8912e" }))),
                                React.createElement("g", { transform: "translate(50 50) scale(0.76) translate(-49.54 -53.5)" },
                                    React.createElement("path", { fill: "url(#bsGoldGradF)", d: FRUIT_BODY_D }),
                                    React.createElement("path", { className: "flush-intro", fill: "#f5cf7e", d: FRUIT_BODY_D }),
                                    React.createElement("path", { className: "flush-beat", fill: "#f5cf7e", d: FRUIT_BODY_D }),
                                    React.createElement("path", { fill: "#8a6218", d: "M36 26 L42 16 L47 22 L50 10 L54 21 L61 17 L58 27 C52 31, 43 31, 36 26 Z" }),
                                    React.createElement("path", { fill: "#8a6218", d: "M49 12 C49 8, 51 5, 54 3 L57 6 C54 8, 53 11, 53 14 Z" }),
                                    React.createElement("g", { fill: "none", strokeLinecap: "round" },
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "3.8", opacity: "0.9", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                        React.createElement("path", { stroke: "#f5cf7e", strokeWidth: "1.2", opacity: "0.35", transform: "translate(-0.5,-0.5)", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "2.6", opacity: "0.9", d: "M47 59 C52 56, 56 52, 58 46" }),
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "1.7", opacity: "0.85", d: "M58 46 C60 43, 60 39, 59 36" }),
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "2.6", opacity: "0.9", d: "M47 70 C53 68, 58 65, 62 60" }),
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "3.2", opacity: "0.9", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                        React.createElement("path", { stroke: "#f5cf7e", strokeWidth: "1.1", opacity: "0.3", transform: "translate(-0.5,-0.5)", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "1.9", opacity: "0.85", d: "M63 62 C66 58, 67 54, 66 50" }),
                                        React.createElement("path", { stroke: "#8a6218", strokeWidth: "2.2", opacity: "0.9", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" }),
                                        React.createElement("path", { stroke: "#f5cf7e", strokeWidth: "0.9", opacity: "0.3", transform: "translate(-0.5,-0.5)", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" })),
                                    React.createElement("g", null,
                                        React.createElement("path", { className: "vp d1", pathLength: "100", strokeWidth: "4.0", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                        React.createElement("path", { className: "vp d2", pathLength: "100", strokeWidth: "3.4", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                        React.createElement("path", { className: "vp d3", pathLength: "100", strokeWidth: "2.4", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" }),
                                        React.createElement("path", { className: "vp d4", pathLength: "100", strokeWidth: "2.8", d: "M47 70 C53 68, 58 65, 62 60" }),
                                        React.createElement("path", { className: "vp d5", pathLength: "100", strokeWidth: "2.8", d: "M47 59 C52 56, 56 52, 58 46" }),
                                        React.createElement("path", { className: "vp d6", pathLength: "100", strokeWidth: "2.1", d: "M63 62 C66 58, 67 54, 66 50" }),
                                        React.createElement("path", { className: "vp d7", pathLength: "100", strokeWidth: "1.9", d: "M58 46 C60 43, 60 39, 59 36" })),
                                    React.createElement("g", null,
                                        React.createElement("path", { className: "vc c1", pathLength: "100", strokeWidth: "3.4", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                        React.createElement("path", { className: "vc c2", pathLength: "100", strokeWidth: "3.0", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                        React.createElement("path", { className: "vc c3", pathLength: "100", strokeWidth: "2.2", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" })),
                                    React.createElement("ellipse", { cx: 60, cy: 66, rx: 3.2, ry: 6.5, fill: "#f7e2ae", opacity: 0.9, transform: "rotate(18 60 66)" }),
                                    React.createElement("ellipse", { cx: 43, cy: 44, rx: 1.6, ry: 3.8, fill: "#f7e2ae", opacity: 0.25, transform: "rotate(-10 43 44)" }))))))),
            React.createElement("div", { className: "word" }, "Bull"),
            React.createElement("div", { className: "line" }, "Day ", streak, " \u00B7 Discipline compounding"),
            React.createElement("div", { className: "stats" },
                React.createElement("div", { className: "stat" }, React.createElement("div", { className: "num" }, vigDisp), React.createElement("div", { className: "lbl" }, "Vigour")),
                React.createElement("div", { className: "bsdivider" }),
                React.createElement("div", { className: "stat" }, React.createElement("div", { className: "num" }, riskDisp), React.createElement("div", { className: "lbl" }, "Risk")),
                React.createElement("div", { className: "bsdivider" }),
                React.createElement("div", { className: "stat" }, React.createElement("div", { className: "num" }, cleanDisp), React.createElement("div", { className: "lbl" }, "Clean %"))),
            React.createElement("div", { className: "hype" }, hype))));
}
/* ---------- breathe overlay ---------- */
function Breathe({ purposeText, onClose }) {
    const [started, setStarted] = useState(false);
    const [elapsed, setElapsed] = useState(0);
    const TOTAL = 180;
    useEffect(() => {
        if (!started)
            return;
        const t0 = Date.now();
        const iv = setInterval(() => {
            const e = (Date.now() - t0) / 1000;
            setElapsed(e >= TOTAL ? TOTAL : e);
            if (e >= TOTAL)
                clearInterval(iv);
        }, 100);
        return () => clearInterval(iv);
    }, [started]);
    const inCycle = elapsed % 14;
    let phase, scale, dur;
    if (inCycle < 3.5) {
        phase = "Inhale Through The Nose";
        scale = 1.14;
        dur = "3.5s";
    }
    else if (inCycle < 5.5) {
        phase = "Sip In A Little More";
        scale = 1.3;
        dur = "2s";
    }
    else {
        phase = "Long Slow Exhale Through The Mouth";
        scale = 0.7;
        dur = "8.5s";
    }
    const remaining = Math.ceil(TOTAL - elapsed);
    const mm = Math.floor(remaining / 60), ss = pad(remaining % 60);
    const doneAll = elapsed >= TOTAL;
    return (React.createElement("div", { className: "fixed inset-0 z-50 bg-black flex flex-col items-center justify-between p-6 overflow-y-auto" },
        React.createElement("div", { className: "w-full max-w-md pt-4" },
            React.createElement("div", { className: "text-xs uppercase tracking-widest font-bold mb-3", style: { color: TEAL } }, "Win Logged \u2014 Urge Survived"),
            React.createElement("p", { className: "font-serif text-neutral-200 text-lg leading-relaxed whitespace-pre-line" }, purposeText)),
        !started ? (React.createElement("button", { onClick: () => setStarted(true), className: "my-10 px-8 py-4 rounded-2xl font-bold text-lg text-neutral-950", style: { background: TEAL } }, "BEGIN 3-MINUTE RESET")) : (React.createElement("div", { className: "flex flex-col items-center my-8" },
            React.createElement("div", { className: "relative w-52 h-52 flex items-center justify-center" },
                React.createElement("div", { className: "absolute inset-0 rounded-full border border-neutral-800" }),
                React.createElement("div", { className: "w-36 h-36 rounded-full opacity-20", style: { background: TEAL, transform: `scale(${scale})`, transition: `transform ${dur} ease-in-out` } }),
                React.createElement("div", { className: "absolute w-36 h-36 rounded-full border-2", style: { borderColor: TEAL, transform: `scale(${scale})`, transition: `transform ${dur} ease-in-out` } })),
            React.createElement("div", { className: "text-neutral-200 mt-6 text-sm uppercase tracking-wide font-semibold" }, doneAll ? "Steady — The Wave Passed" : phase),
            React.createElement("div", { className: "font-mono text-neutral-500 mt-1 text-sm" }, doneAll ? "0:00" : `${mm}:${ss}`))),
        React.createElement("div", { className: "w-full max-w-md pb-4" },
            React.createElement("button", { onClick: onClose, className: "w-full py-3.5 rounded-2xl font-bold uppercase tracking-wide " + (doneAll ? "text-neutral-950" : "bg-neutral-800 text-neutral-400"), style: doneAll ? { background: TEAL } : undefined }, doneAll ? "Return, Stronger" : started ? "I'm Steady — Return Early" : "Close"))));
}
/* ---------- guide ---------- */
const GUIDE = [
    { t: "The Urge Protocol", b: "Tap Urge the moment it hits — the tap alone is a logged win. Purpose card, then 3 minutes of physiological sighs. Urges peak within minutes and pass if not fed. Still loud after? Change environment: leave the room, leave the house." },
    { t: "Physiological Sigh", b: "Two inhales through the nose — one full, one short sip on top to fully inflate the lungs — then one long slow exhale through the mouth, roughly twice the length of the inhales. Offloads CO2 fast; the quickest evidence-backed way to downshift a stressed nervous system in real time." },
    { t: "Kegels", b: "Find the muscle: the one that stops urine mid-flow (locate it once — don't train while urinating). Each session: 10 slow reps (squeeze 3–5s, relax an equal time; progress toward 10s holds) + 10 fast 1-second flutters. Then equal reverse-kegel work: gentle bearing-down release on a slow exhale, same rep count. Pelvic floor training trials show improved erectile rigidity and ejaculatory control — but a tight floor works against you, so release equals strengthen. Never train to fatigue." },
    { t: "Pelvic Floor Release", b: "5–10 minutes: happy baby, deep squat, child's pose, butterfly. Nasal breathing, letting the floor soften on every exhale. Goal is release, not effort — this is what keeps the kegel work from adding tension." },
    { t: "Cardio", b: "40 minutes moderate-to-vigorous, 4× a week — the dose meta-analyses link to measurably improved erectile function, because erections are vascular events. Boxing counts fully. Mornings only; evening sessions cost sleep." },
    { t: "Strength", b: "2–3× a week, compound lifts: squat, hinge, press, pull. 6–12 reps, 2–3 minutes rest between working sets. Supports testosterone, mood, and body composition. Isometric holds count and build pain tolerance." },
    { t: "Cold Exposure", b: "1–3 minutes, 2–4× a week. Spikes norepinephrine and dopamine, trains the exact discomfort tolerance used to sit through an urge. Keep it 6+ hours away from strength sessions — cold immediately after lifting blunts muscle adaptation." },
    { t: "Breathwork Before Isha", b: "5 minutes diaphragmatic: hand on belly, nasal inhale so the belly rises, exhale longer than the inhale. Anchored to Isha because it's fixed and near bedtime — lowers cortisol going into your most vulnerable window." },
    { t: "Nasal Rinse + Mouth Tape", b: "Rinse before bed for a clear airway; small strip of porous tape over the lips at night — never when congested. Nasal breathing during sleep improves oxygenation and recovery, your biggest vulnerability driver." },
    { t: "Fasting", b: "Mondays, Thursdays, 13th–15th lunar — auto-flagged. Use it as reset and recovery, especially the day after a slip. Discipline transfers." },
    { t: "Supplements", b: "Zinc 15–30 mg with food. Magnesium glycinate 200–400 mg in the evening — also aids sleep. Vitamin D 1000–4000 IU with a fatty meal. Confirm all doses against your blood panel." },
    { t: "After A Slip", b: "The slip doesn't cause the binge — the thought 'already ruined' does. That's the abstinence violation effect, and it's the trap. Protocol: log it honestly, water, shower, out of the house, fast tomorrow, tell your accountability partner. One data point. The percentage barely moves." },
    { t: "Scoring", b: "Risk starts near baseline, rises with active risk factors and falls with protective habits and survived urges — lower is safer, and a fuller ring is always better. Vigour is weighted completion of scheduled actions. Every weight is adjustable in Settings; Patterns shows what actually precedes your relapses." },
];
/* ---------- main ---------- */
function App() {
    const [data, setData] = useState(null);
    const [view, setView] = useState("today");
    const [breathing, setBreathing] = useState(false);
    const [confirmRelapse, setConfirmRelapse] = useState(false);
    const [confirmWetDream, setConfirmWetDream] = useState(false);
    const [justRelapsed, setJustRelapsed] = useState(false);
    const [resetStep, setResetStep] = useState(0);
    const [openGuide, setOpenGuide] = useState(null);
    const [period, setPeriod] = useState("W");
    const [newSup, setNewSup] = useState("");
    const [expandedItem, setExpandedItem] = useState(null);
    const [showAdd, setShowAdd] = useState(false);
    const [viewOffset, setViewOffset] = useState(0);
    const [showSplash, setShowSplash] = useState(true);
    const [addForm, setAddForm] = useState({ label: "", list: "prev", kind: "risk", weight: "med", daily: true, days: [] });
    const saveTimer = useRef(null);
    useEffect(() => {
        (async () => {
            const loaded = migrate(await storageGet());
            if (loaded)
                setData(loaded);
            else
                setData({
                    version: 6, settings: { ...DEFAULT_SETTINGS },
                    items: DEFAULT_ITEMS.map((i) => ({ ...i, freq: Array.isArray(i.freq) ? [...i.freq] : i.freq })),
                    days: {}, urges: [], relapses: [], wetDreams: [], firstUse: Date.now(),
                });
        })();
    }, []);
    const persist = (next) => {
        setData(next);
        if (saveTimer.current)
            clearTimeout(saveTimer.current);
        saveTimer.current = setTimeout(() => storageSet(next), 500);
    };
    if (!data) {
        return (React.createElement("div", { className: "min-h-screen bg-black flex items-center justify-center" },
            React.createElement("div", { className: "text-neutral-500 text-sm uppercase tracking-widest" }, "Loading")));
    }
    const items = data.items || [];
    const tk = todayKey();
    const vk = dateKey(new Date(Date.now() + viewOffset * DAY_MS));
    const isToday = vk === tk;
    const today = { ...emptyDay(), ...(data.days[vk] || {}) };
    const setDay = (k, v) => persist({ ...data, days: { ...data.days, [vk]: { ...today, [k]: v } } });
    const setCheck = (id, v) => setDay("checks", { ...today.checks, [id]: v });
    const urgesToday = data.urges.filter((u) => dateKey(new Date(u.ts)) === vk).length;
    const relapseToday = data.relapses.some((r) => dateKey(new Date(r.ts)) === vk);
    const therapistStatus = (() => {
        const next = data.settings.nextCheckin;
        if (!next)
            return "setup";
        if (next < Date.now())
            return "overdue";
        const windowMs = (data.settings.therapistEveryWeeks || 2) * 7 * DAY_MS;
        return next - Date.now() > windowMs ? "outside" : "scheduled";
    })();
    const accountabilityPenalty = therapistStatus === "setup" || therapistStatus === "overdue" ? 15
        : therapistStatus === "outside" ? 8 : 0;
    const risk = riskScore(today, items, urgesToday, relapseToday, accountabilityPenalty);
    const h = vigourForDay(today, new Date(), items, data.settings);
    const vigourPct = h.total ? (h.done / h.total) * 100 : 0;
    const loggedRelapse = data.relapses.length ? Math.max(...data.relapses.map((r) => r.ts)) : null;
    const manualStart = data.settings.manualLastRelapseDate || null;
    const lastRelapse = Math.max(loggedRelapse || 0, manualStart || 0) || null;
    const streak = Math.max(0, Math.floor((Date.now() - (lastRelapse || data.firstUse)) / DAY_MS));
    const windowDays = Math.min(90, Math.max(1, Math.floor((Date.now() - data.firstUse) / DAY_MS) + 1));
    const relDaySet = new Set(data.relapses.filter((r) => r.ts >= Date.now() - windowDays * DAY_MS).map((r) => dateKey(new Date(r.ts))));
    if (manualStart && manualStart >= Date.now() - windowDays * DAY_MS)
        relDaySet.add(dateKey(new Date(manualStart)));
    const cleanPct = Math.round((100 * (windowDays - relDaySet.size)) / windowDays);
    /* ---------- ambient mood: driven by 30-day rolling averages, flagged days excluded ---------- */
    const ambient = (() => {
        const from = Date.now() - 30 * DAY_MS;
        const relKeySet = new Set(data.relapses.map((r) => dateKey(new Date(r.ts))));
        const isFlagged = (k) => { const d = data.days[k]; return d && (d.sick === true || d.travelling === true); };
        let rSum = 0, rN = 0, hd = 0, ht = 0;
        Object.keys(data.days).forEach((k) => {
            const t = new Date(k + "T12:00:00");
            if (t.getTime() < from || isFlagged(k))
                return;
            if (riskLogged(data.days[k], items)) {
                const uc = data.urges.filter((u) => dateKey(new Date(u.ts)) === k).length;
                rSum += riskScore({ ...emptyDay(), ...data.days[k] }, items, uc, relKeySet.has(k));
                rN++;
            }
            const r = vigourForDay({ ...emptyDay(), ...data.days[k] }, t, items, data.settings);
            hd += r.done;
            ht += r.total;
        });
        const vigAvg = ht ? (hd / ht) : 0.6;
        const protAvg = rN ? 1 - (rSum / rN) / 100 : 0.85;
        const vt = Math.max(0, Math.min(1, vigAvg));
        const dgr = Math.pow(Math.max(0, Math.min(1, 1 - protAvg)), 1.35);
        return {
            vt, dgr, tense: protAvg <= 0.33,
            accent: mixHex("#8a7a55", "#e0b040", Math.min(1, vt * 1.25)),
            vars: {
                "--vig": vt.toFixed(3),
                "--accent": mixHex("#8a7a55", "#e0b040", Math.min(1, vt * 1.25)),
                "--energyOp": (0.12 + 0.5 * vt).toFixed(3),
                "--energyCol": `rgba(224,176,64,${(0.14 + 0.2 * vt).toFixed(3)})`,
                "--breatheA": (0.015 + 0.06 * vt).toFixed(3),
                "--dgrOp": (dgr * 0.5).toFixed(3),
                "--dgrLine": (dgr * 0.9).toFixed(3),
                "--bg": mixHex(mixHex("#050403", "#17110a", vt), "#120406", dgr * 0.8),
            },
        };
    })();
    const logUrge = () => { persist({ ...data, urges: [...data.urges, { ts: Date.now() }] }); setBreathing(true); };
    const logRelapse = () => {
        persist({ ...data, relapses: [...data.relapses, { ts: Date.now() }] });
        setConfirmRelapse(false);
        setJustRelapsed(true);
    };
    const logWetDream = () => {
        persist({ ...data, wetDreams: [...(data.wetDreams || []), { ts: Date.now() }] });
        setConfirmWetDream(false);
    };
    const now = new Date(Date.now() + viewOffset * DAY_MS);
    const prevRisks = items.filter((i) => i.list === "prev" && i.kind === "risk" && scheduledOn(i, now));
    const prevHabits = items.filter((i) => i.list === "prev" && i.kind === "habit" && scheduledOn(i, now));
    const fastToday = fastingSuggested(now, data.settings.fastLunarOnly);
    const primeToday = items.filter((i) => i.list === "prime" && i.kind === "habit" && (i.fastingAuto ? fastToday : scheduledOn(i, now)));
    /* ---- stats ---- */
    const statsFor = () => {
        const nowTs = Date.now();
        let from = 0;
        if (period === "D")
            from = nowTs - DAY_MS;
        else if (period === "W")
            from = nowTs - 7 * DAY_MS;
        else if (period === "M")
            from = nowTs - 30 * DAY_MS;
        else if (period === "Y")
            from = nowTs - 365 * DAY_MS;
        const relKeySet = new Set(data.relapses.map((r) => dateKey(new Date(r.ts))));
        const flagged = (k) => { const d = data.days[k]; return d && (d.sick === true || d.travelling === true); };
        const keys = Object.keys(data.days).filter((k) => {
            const t = new Date(k + "T12:00:00").getTime();
            return t >= from && riskLogged(data.days[k], items) && !flagged(k);
        });
        let sum = 0;
        keys.forEach((k) => {
            const uc = data.urges.filter((u) => dateKey(new Date(u.ts)) === k).length;
            sum += riskScore({ ...emptyDay(), ...data.days[k] }, items, uc, relKeySet.has(k));
        });
        let hd = 0, ht = 0;
        Object.keys(data.days).forEach((k) => {
            const t = new Date(k + "T12:00:00");
            if (t.getTime() < from)
                return;
            if (flagged(k))
                return;
            const r = vigourForDay({ ...emptyDay(), ...data.days[k] }, t, items, data.settings);
            hd += r.done;
            ht += r.total;
        });
        return {
            avgRisk: keys.length ? sum / keys.length : null,
            vigour: ht ? (hd / ht) * 100 : null,
            urges: data.urges.filter((u) => u.ts >= from).length,
            relapses: data.relapses.filter((r) => r.ts >= from).length,
            wetDreams: (data.wetDreams || []).filter((w) => w.ts >= from).length,
        };
    };
    const bestStreak = (() => {
        const relapseTs = data.relapses.map((r) => r.ts);
        if (manualStart)
            relapseTs.push(manualStart);
        const pts = [data.firstUse, ...relapseTs.sort((a, b) => a - b), Date.now()];
        let best = 0;
        for (let i = 1; i < pts.length; i++)
            best = Math.max(best, Math.floor((pts[i] - pts[i - 1]) / DAY_MS));
        return best;
    })();
    const CORRELATION_FACTORS = [
        ...items.filter((i) => i.list === "prev" && i.kind === "risk").map((i) => ({ label: i.label, test: (d) => d.checks && d.checks[i.id] === true })),
        ...items.filter((i) => i.list === "prev" && i.kind === "habit").map((i) => ({ label: "Skipped: " + i.label, test: (d) => !(d.checks && d.checks[i.id] === true) })),
        { label: "Med/High Content Access", test: (d) => d.access === "med" || d.access === "high" },
        { label: "Heavy Visual Triggers", test: (d) => d.checkout === "lot" },
        { label: "Recovery Below 40%", test: (d) => d.recovery !== null && d.recovery !== undefined && d.recovery !== "" && Number(d.recovery) < 40 },
        { label: "Low-Purpose Day (1–2)", test: (d) => d.purposeRating !== null && d.purposeRating !== undefined && d.purposeRating <= 2 },
        { label: "Flagged Sick", test: (d) => d.sick === true },
        { label: "Flagged Travelling", test: (d) => d.travelling === true },
    ];
    const correlationsFor = (eventTimestamps) => {
        const eventKeys = [...new Set(eventTimestamps.map((ts) => dateKey(new Date(ts))))].filter((k) => data.days[k]);
        const allKeys = Object.keys(data.days).filter((k) => riskLogged(data.days[k], items));
        if (!eventKeys.length || !allKeys.length)
            return null;
        return CORRELATION_FACTORS.map((f) => {
            const rel = eventKeys.filter((k) => f.test({ ...emptyDay(), ...data.days[k] })).length / eventKeys.length;
            const base = allKeys.filter((k) => f.test({ ...emptyDay(), ...data.days[k] })).length / allKeys.length;
            return { label: f.label, rel: Math.round(rel * 100), base: Math.round(base * 100) };
        }).filter((x) => x.rel > 0).sort((a, b) => (b.rel - b.base) - (a.rel - a.base)).slice(0, 5);
    };
    const correlations = data.relapses.length < 3 ? null : correlationsFor(data.relapses.map((r) => r.ts));
    const wetDreamCorrelations = (data.wetDreams || []).length < 3 ? null : correlationsFor(data.wetDreams.map((w) => w.ts));
    const last14 = (() => {
        const out = [];
        for (let i = 13; i >= 0; i--) {
            const d = new Date(Date.now() - i * DAY_MS);
            const k = dateKey(d);
            const day = data.days[k];
            const uc = data.urges.filter((u) => dateKey(new Date(u.ts)) === k).length;
            const rel = data.relapses.some((r) => dateKey(new Date(r.ts)) === k);
            out.push({ k, logged: riskLogged(day, items) || rel, rel, score: riskScore({ ...emptyDay(), ...(day || {}) }, items, uc, rel) });
        }
        return out;
    })();
    const st = view === "stats" ? statsFor() : null;
    /* ---- settings / item helpers ---- */
    const setSetting = (k, v) => persist({ ...data, settings: { ...data.settings, [k]: v } });
    const updateItem = (id, patch) => persist({ ...data, items: items.map((i) => (i.id === id ? { ...i, ...patch } : i)) });
    const deleteItem = (id) => persist({ ...data, items: items.filter((i) => i.id !== id) });
    const toggleItemDay = (item, dow) => {
        const cur = Array.isArray(item.freq) ? item.freq : [];
        updateItem(item.id, { freq: cur.includes(dow) ? cur.filter((d) => d !== dow) : [...cur, dow].sort() });
    };
    const addItem = () => {
        const label = addForm.label.trim();
        if (!label)
            return;
        const id = "c" + Date.now().toString(36);
        const freq = addForm.daily ? "daily" : (addForm.days.length ? [...addForm.days].sort() : "daily");
        persist({ ...data, items: [...items, { id, label, list: addForm.list, kind: addForm.list === "prime" ? "habit" : addForm.kind, weight: addForm.weight, freq }] });
        setAddForm({ label: "", list: "prev", kind: "risk", weight: "med", daily: true, days: [] });
        setShowAdd(false);
    };
    const freqSummary = (item) => item.fastingAuto ? (data.settings.fastLunarOnly ? "AUTO (LUNAR ONLY)" : "AUTO (MON/THU/LUNAR)") :
        item.freq === "daily" ? "DAILY" :
            Array.isArray(item.freq) && item.freq.length ? item.freq.map((d) => WD[d]).join(" ") : "DAILY";
    const NavBtn = ({ id, icon: Icon, label }) => (React.createElement("button", { onClick: () => setView(id), className: "flex-1 flex flex-col items-center gap-0.5 py-2 " + (view === id ? "" : "text-neutral-500"), style: view === id ? { color: TEAL } : undefined },
        React.createElement(Icon, { size: 20 }),
        React.createElement("span", { className: "text-[10px] uppercase tracking-wide font-semibold" }, label)));
    const ItemEditorRow = ({ item }) => {
        const kindLabel = item.kind === "risk" ? "RISK" : item.kind === "habit" ? "PROTECTIVE"
            : item.kind === "tier" ? "TIERED" : "AUTO";
        const editable = item.kind === "risk" || item.kind === "habit";
        return (React.createElement("div", { className: "py-2.5 border-b border-neutral-800 last:border-0" },
            React.createElement("button", { onClick: () => setExpandedItem(expandedItem === item.id ? null : item.id), className: "w-full flex items-center justify-between text-left" },
                React.createElement("div", { className: "pr-2" },
                    React.createElement("div", { className: "text-sm text-neutral-200 uppercase tracking-wide font-semibold" }, item.label),
                    React.createElement("div", { className: "text-xs text-neutral-500 mt-0.5" }, kindLabel + " · " + item.weight.toUpperCase() + (editable ? " · " + freqSummary(item) : "")),
                    item.sub && item.list !== "prime" && React.createElement("div", { className: "text-xs text-neutral-600 mt-0.5 normal-case" }, item.sub)),
                React.createElement(Pencil, { size: 14, className: "text-neutral-600 shrink-0" })),
            expandedItem === item.id && (React.createElement("div", { className: "mt-3 space-y-3" },
                item.list === "prev" && editable && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5" }, "Type"),
                    React.createElement(Seg, { value: item.kind, allowClear: false, onChange: (v) => v && updateItem(item.id, { kind: v }), options: [{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }] }))),
                React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5" }, "Weight"),
                    React.createElement(Seg, { value: item.weight, allowClear: false, onChange: (v) => v && updateItem(item.id, { weight: v }), options: [{ v: "low", label: "Low" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }] })),
                editable && !item.fastingAuto && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5" }, "Days"),
                    React.createElement("button", { onClick: () => updateItem(item.id, { freq: "daily" }), className: "px-3 py-1.5 rounded-lg text-xs uppercase border mb-1.5 " + (item.freq === "daily" ? "font-bold text-neutral-950" : "border-neutral-700 text-neutral-400"), style: item.freq === "daily" ? { background: TEAL, borderColor: TEAL } : undefined }, "Every Day"),
                    React.createElement("div", { className: "flex gap-1" }, WD.map((w, i) => {
                        const on = Array.isArray(item.freq) && item.freq.includes(i);
                        return (React.createElement("button", { key: w, onClick: () => toggleItemDay(Array.isArray(item.freq) ? item : { ...item, freq: [] }, i), className: "flex-1 py-1.5 rounded-lg text-xs border " + (on ? "bg-neutral-200 border-neutral-200 text-neutral-950 font-bold" : "border-neutral-700 text-neutral-500") }, w));
                    })))),
                item.fastingAuto && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5" }, "Fasting Days"),
                    React.createElement(Seg, { value: data.settings.fastLunarOnly ? "lunar" : "both", allowClear: false, onChange: (v) => v && setSetting("fastLunarOnly", v === "lunar"), options: [{ v: "both", label: "Mon/Thu + Lunar" }, { v: "lunar", label: "Lunar Only" }] }))),
                editable && (React.createElement("button", { onClick: () => { deleteItem(item.id); setExpandedItem(null); }, className: "text-xs text-rose-400 flex items-center gap-1 uppercase tracking-wide" },
                    React.createElement(Trash2, { size: 13 }),
                    " Remove Item"))))));
    };
    return (React.createElement("div", { className: "min-h-screen text-neutral-200 pb-24", style: { WebkitTapHighlightColor: "transparent", background: "var(--bg, #050403)", transition: "background 0.8s", ...ambient.vars } },
        React.createElement("style", { dangerouslySetInnerHTML: { __html: "@keyframes bullFruitThrob{0%,100%{transform:scale(1,1);}14%{transform:scale(1.07,1.04);}26%{transform:scale(1.0,.995);}38%{transform:scale(1.1,1.05);}58%{transform:scale(1,1);}}.bull-fruit-throb{animation:bullFruitThrob 1.9s ease-in-out infinite;}"
                    + ".bull-energy{position:fixed;top:-16%;left:50%;width:150%;aspect-ratio:1.2;transform:translateX(-50%);background:radial-gradient(ellipse at 50% 30%, var(--energyCol, rgba(224,176,64,.2)) 0%, transparent 62%);opacity:var(--energyOp,.3);pointer-events:none;z-index:0;animation:bullEnergyBreathe 5s ease-in-out infinite;transition:opacity .8s;}"
                    + "@keyframes bullEnergyBreathe{0%,100%{transform:translateX(-50%) scale(1);}50%{transform:translateX(-50%) scale(calc(1 + var(--breatheA,0.03)));}}"
                    + ".bull-danger{position:fixed;inset:0;pointer-events:none;z-index:40;background:radial-gradient(ellipse 120% 100% at 50% 45%, transparent 55%, rgba(150,10,20,var(--dgrOp,0)) 100%);transition:background .8s;}"
                    + ".bull-danger.tense{animation:bullTension 2.4s ease-in-out infinite;}"
                    + "@keyframes bullTension{0%,100%{opacity:1;}50%{opacity:.82;}}"
                    + ".bull-forceline{height:2px;border-radius:2px;margin:16px 0 4px;background:linear-gradient(90deg, var(--accent,#e0b040) 0%, transparent 45%, transparent 55%, rgba(220,38,38,var(--dgrLine,0)) 100%);opacity:.9;transition:background .8s;}"
                    + ".bull-field{background:rgba(255,255,255,0.055);}"
                    + ".bull-nav{background:rgba(6,5,4,0.82);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);border-top:1px solid rgba(255,255,255,0.05);}"
                    + "@media (prefers-reduced-motion: reduce){.bull-energy,.bull-danger.tense,.bull-fruit-throb{animation:none !important;}}" } }),
        React.createElement("div", { className: "bull-energy" }),
        React.createElement("div", { className: "bull-danger" + (ambient.tense ? " tense" : "") }),
        showSplash && data && React.createElement(Splash, { vigour: vigourPct, risk: risk, cleanPct: cleanPct, streak: streak, onDone: () => setShowSplash(false) }),
        breathing && React.createElement(Breathe, { purposeText: data.settings.purposeText, onClose: () => setBreathing(false) }),
        React.createElement("div", { className: "max-w-md mx-auto px-4", style: { paddingTop: "calc(env(safe-area-inset-top, 0px) + 24px)" } },
            view === "today" && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "flex items-center gap-1.5 mb-1" },
                    React.createElement("div", { className: "w-6 h-6 rounded-md", style: { background: AMBER } }),
                    React.createElement("span", { className: "text-xs font-bold tracking-[0.3em]", style: { color: AMBER } }, "BULL")),
                React.createElement("div", { className: "flex items-start justify-between" },
                    React.createElement("div", null,
                        React.createElement("div", { className: "flex items-center gap-1.5" },
                            React.createElement("button", { onClick: () => setViewOffset(viewOffset - 1), className: "text-neutral-600 px-1 -ml-1 text-lg leading-none active:text-neutral-400" }, "\u2039"),
                            React.createElement("div", { className: "font-serif text-2xl text-neutral-100" }, isToday ? now.toLocaleDateString(undefined, { weekday: "long" }) : now.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" })),
                            React.createElement("button", { onClick: () => viewOffset < 0 && setViewOffset(viewOffset + 1), disabled: viewOffset >= 0, className: "text-lg leading-none px-1 " + (viewOffset >= 0 ? "text-neutral-800" : "text-neutral-600 active:text-neutral-400") }, "\u203A")),
                        !isToday && React.createElement("button", { onClick: () => setViewOffset(0), className: "text-[10px] uppercase tracking-widest font-bold mt-0.5", style: { color: AMBER } }, "\u270E Editing Past Day \u2014 Jump To Today"),
                        isToday && React.createElement("div", { className: "text-sm text-neutral-500" },
                            now.toLocaleDateString(undefined, { day: "numeric", month: "long" }),
                            fastToday && React.createElement("span", { style: { color: AMBER } }, " \u00B7 FASTING DAY")),
                        React.createElement("div", { className: "flex items-center gap-1.5 mt-2", style: { color: AMBER } },
                            React.createElement(Flame, { size: 16 }),
                            React.createElement("span", { className: "font-mono text-sm font-bold" },
                                cleanPct,
                                "% CLEAN \u00B7 ",
                                windowDays,
                                "D"))),
                    React.createElement("div", { className: "flex gap-4" },
                        React.createElement(ShieldRisk, { risk: risk, size: 68 }),
                        React.createElement(VigourFruit, { pct: vigourPct, size: 68 }))),
                React.createElement("div", { className: "bull-forceline" }),
                isToday ? (React.createElement(React.Fragment, null,
                    React.createElement("button", { onClick: logUrge, className: "w-full mt-5 py-4 rounded-2xl font-bold text-lg text-black flex items-center justify-center gap-2 active:scale-95 transition-transform uppercase tracking-widest", style: { background: "var(--accent, #e0b040)", boxShadow: "0 6px calc(12px + var(--vig, 0.5)*20px) rgba(224,176,64,calc(0.1 + var(--vig, 0.5)*0.28))" } },
                        React.createElement(Wind, { size: 22 }),
                        " Urge \u2014 Tap To Ride It Out"),
                    React.createElement("div", { className: "text-center text-xs text-neutral-500 mt-1.5 uppercase tracking-wide" },
                        data.urges.length,
                        " urge",
                        data.urges.length === 1 ? "" : "s",
                        " survived all-time"))) : (React.createElement("div", { className: "text-center text-xs text-neutral-600 mt-5 uppercase tracking-wide py-4 border border-dashed border-neutral-800 rounded-2xl" }, "Urge logging only available on today")),
                justRelapsed && (React.createElement(Card, { className: "mt-4 border border-neutral-700" },
                    React.createElement("div", { className: "text-sm text-neutral-300 leading-relaxed" }, "Logged. One slip is one data point \u2014 not a collapse. Water, shower, outside. Fast tomorrow."),
                    React.createElement("button", { onClick: () => setJustRelapsed(false), className: "mt-2 text-xs text-neutral-500 uppercase tracking-wide" }, "Dismiss"))),
                React.createElement(GroupHeader, { icon: Shield, color: TEAL }, "Relapse Prevention"),
                React.createElement(SectionLabel, null, "Morning Intention"),
                React.createElement(Card, null, today.intentionSet ? (React.createElement("div", { className: "flex items-start gap-2" },
                    React.createElement(Check, { size: 18, style: { color: TEAL }, className: "mt-0.5 shrink-0" }),
                    React.createElement("div", { className: "text-sm text-neutral-300" }, today.intentionText || "Intention set."))) : (React.createElement("div", { className: "flex gap-2" },
                    React.createElement("input", { value: today.intentionText, onChange: (e) => setDay("intentionText", e.target.value), placeholder: "One purposeful thing today\u2026", className: "flex-1 rounded-xl bull-field px-3 py-2 text-sm outline-none placeholder-neutral-600" }),
                    React.createElement("button", { onClick: () => setDay("intentionSet", true), className: "px-4 rounded-xl text-neutral-950 text-sm font-bold uppercase", style: { background: TEAL } }, "Set")))),
                React.createElement(SectionLabel, null, "Accountability"),
                React.createElement(Card, { className: therapistStatus !== "scheduled" ? "border border-amber-500/50" : "" },
                    React.createElement("div", { className: "text-xs uppercase tracking-widest font-bold mb-2", style: { color: therapistStatus === "scheduled" ? TEAL : CAUTION } }, therapistStatus === "setup" ? "Nothing Booked"
                        : therapistStatus === "overdue" ? "Overdue"
                            : therapistStatus === "outside" ? "Beyond Window"
                                : "Booked · " + new Date(data.settings.nextCheckin).toLocaleString(undefined, { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })),
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("input", { type: "datetime-local", value: data.settings.nextCheckin ? new Date(data.settings.nextCheckin - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16) : "", onChange: (e) => {
                                const v = e.target.value;
                                setSetting("nextCheckin", v ? new Date(v).getTime() : null);
                            }, className: "flex-1 rounded-xl bull-field px-3 py-2 text-sm outline-none text-neutral-100" }),
                        data.settings.nextCheckin && (React.createElement("button", { onClick: () => setSetting("nextCheckin", null), className: "px-3 rounded-xl bg-neutral-800 text-neutral-400 text-xs uppercase tracking-wide" }, "Clear")))),
                React.createElement(SectionLabel, null, "Risk Factors Today"),
                React.createElement(Rows, null,
                    prevRisks.map((it) => (React.createElement(YesNo, { key: it.id, mode: "risk", label: it.label, value: today.checks[it.id] === undefined ? null : today.checks[it.id], onChange: (v) => setCheck(it.id, v) }))),
                    React.createElement("div", { className: "py-4", style: { borderBottom: "1px solid rgba(255,255,255,0.045)" } },
                        React.createElement("div", { className: "text-[13.5px] text-neutral-300 tracking-[0.02em] mb-2.5" }, "Content Access Today"),
                        React.createElement(Seg, { value: today.access, onChange: (v) => setDay("access", v), options: [{ v: "low", label: "Low", tone: "teal" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }] })),
                    React.createElement("div", { className: "py-4" },
                        React.createElement("div", { className: "text-[13.5px] text-neutral-300 tracking-[0.02em] mb-2.5" }, "Checking Out Women"),
                        React.createElement(Seg, { value: today.checkout, onChange: (v) => setDay("checkout", v), options: [{ v: "none", label: "None", tone: "teal" }, { v: "few", label: "A Few", tone: "warn" }, { v: "lot", label: "A Lot", tone: "risk" }] }))),
                prevHabits.length > 0 && (React.createElement(React.Fragment, null,
                    React.createElement(SectionLabel, null, "Protective Habits"),
                    React.createElement(Rows, null, prevHabits.map((it) => (React.createElement(YesNo, { key: it.id, mode: "protective", label: it.label, value: today.checks[it.id] === true, onChange: (v) => setCheck(it.id, v) })))))),
                React.createElement(SectionLabel, null, "Recovery"),
                React.createElement(Card, null,
                    React.createElement(NumField, { label: "Recovery Score", value: today.recovery, onChange: (v) => setDay("recovery", v), suffix: "%" })),
                React.createElement(SectionLabel, null, "Day Flags"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("button", { onClick: () => setDay("sick", !today.sick), className: "flex-1 py-2.5 rounded-xl text-xs uppercase tracking-wide border font-semibold transition-colors " + (today.sick ? "text-neutral-950 font-bold" : "border-neutral-700 text-neutral-400"), style: today.sick ? { background: CAUTION, borderColor: CAUTION } : undefined }, "Sick"),
                        React.createElement("button", { onClick: () => setDay("travelling", !today.travelling), className: "flex-1 py-2.5 rounded-xl text-xs uppercase tracking-wide border font-semibold transition-colors " + (today.travelling ? "text-neutral-950 font-bold" : "border-neutral-700 text-neutral-400"), style: today.travelling ? { background: CAUTION, borderColor: CAUTION } : undefined }, "Travelling")),
                    React.createElement("div", { className: "text-[10px] text-neutral-600 mt-2 leading-relaxed" }, "Flagged days are left out of your period averages, but Patterns still tests them for correlation with relapses and wet dreams. Today's live score isn't affected.")),
                React.createElement(SectionLabel, null, "Evening Review"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-300 mb-2 font-semibold" }, "How Meaningful Did Today Feel"),
                    React.createElement("div", { className: "flex gap-2" }, [1, 2, 3, 4, 5].map((n) => (React.createElement("button", { key: n, onClick: () => setDay("purposeRating", today.purposeRating === n ? null : n), className: "flex-1 py-2.5 rounded-xl border text-base font-mono font-bold transition-colors " +
                            (today.purposeRating === n ? "bg-neutral-200 text-neutral-950 border-neutral-200" : "border-neutral-700 text-neutral-400") }, n))))),
                React.createElement(GroupHeader, { icon: Zap, color: AMBER }, "Sexual Vigour"),
                React.createElement(SectionLabel, null, "Priming Actions"),
                React.createElement(Rows, null, primeToday.map((it) => (React.createElement(YesNo, { key: it.id, mode: "vigour", label: it.label, value: today.checks[it.id] === true, onChange: (v) => setCheck(it.id, v) })))),
                React.createElement(SectionLabel, null, "Supplements"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex flex-wrap gap-2" }, data.settings.supplements.map((s) => {
                        const on = !!(today.supplementsTaken && today.supplementsTaken[s]);
                        return (React.createElement("button", { key: s, onClick: () => setDay("supplementsTaken", { ...today.supplementsTaken, [s]: !on }), className: "px-3 py-1.5 rounded-full text-xs uppercase tracking-wide border transition-colors font-semibold " +
                                (on ? "text-neutral-950 font-bold" : "border-neutral-700 text-neutral-400"), style: on ? { background: AMBER, borderColor: AMBER } : undefined }, s));
                    }))),
                React.createElement(SectionLabel, null, "Sleep"),
                React.createElement(Card, null,
                    React.createElement(NumField, { label: "Sleep Score", value: today.sleep, onChange: (v) => setDay("sleep", v), suffix: "%" })),
                isToday && React.createElement("div", { className: "mt-8 text-center flex items-center justify-center gap-4" },
                    !confirmRelapse && React.createElement("button", { onClick: () => setConfirmRelapse(true), className: "text-xs text-neutral-600 underline uppercase tracking-wide" }, "Log A Relapse"),
                    !confirmWetDream && React.createElement("button", { onClick: () => setConfirmWetDream(true), className: "text-xs text-neutral-600 underline uppercase tracking-wide" }, "Log A Wet Dream")),
                isToday && confirmRelapse && (React.createElement(Card, { className: "mt-3" },
                    React.createElement("div", { className: "text-sm text-neutral-300 mb-3" }, "Log a relapse now? Honesty keeps the data \u2014 and you \u2014 sharp."),
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("button", { onClick: logRelapse, className: "flex-1 py-2.5 rounded-xl bg-rose-500 text-neutral-50 text-sm font-bold uppercase" }, "Yes, Log It"),
                        React.createElement("button", { onClick: () => setConfirmRelapse(false), className: "flex-1 py-2.5 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase" }, "Cancel")))),
                isToday && confirmWetDream && (React.createElement(Card, { className: "mt-3" },
                    React.createElement("div", { className: "text-sm text-neutral-300 mb-3" }, "Log a wet dream for today? Used only for Pattern correlation \u2014 same as relapses."),
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("button", { onClick: logWetDream, className: "flex-1 py-2.5 rounded-xl text-neutral-950 text-sm font-bold uppercase", style: { background: AMBER } }, "Yes, Log It"),
                        React.createElement("button", { onClick: () => setConfirmWetDream(false), className: "flex-1 py-2.5 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase" }, "Cancel")))))),
            view === "stats" && st && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "font-serif text-2xl text-neutral-100 mb-4" }, "Patterns"),
                React.createElement(Seg, { value: period, allowClear: false, onChange: (v) => v && setPeriod(v), options: [{ v: "D", label: "Day" }, { v: "W", label: "Week" }, { v: "M", label: "Month" }, { v: "Y", label: "Year" }, { v: "A", label: "All" }] }),
                React.createElement("div", { className: "grid grid-cols-2 gap-3 mt-4" },
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Avg Risk"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: st.avgRisk === null ? "#e5e5e5" : riskColor(st.avgRisk) } }, st.avgRisk === null ? "—" : Math.round(st.avgRisk))),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Vigour"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: AMBER } }, st.vigour === null ? "—" : Math.round(st.vigour) + "%")),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Urges Survived"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: TEAL } }, st.urges)),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Relapses"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold text-neutral-100 mt-1" }, st.relapses)),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Wet Dreams"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: AMBER } }, st.wetDreams)),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Clean"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: AMBER } },
                            cleanPct,
                            "%")),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500" }, "Best Streak"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold text-neutral-100 mt-1" },
                            bestStreak,
                            "D"))),
                React.createElement(SectionLabel, null, "Last 14 Days"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex gap-1.5 justify-between" }, last14.map((d) => (React.createElement("div", { key: d.k, title: d.k, className: "flex-1 h-9 rounded", style: { background: d.rel ? ROSE : !d.logged ? "#292524" : riskColor(d.score) } })))),
                    React.createElement("div", { className: "text-xs text-neutral-500 mt-2 uppercase tracking-wide" }, "Teal safe \u00B7 Amber caution \u00B7 Red risk/relapse \u00B7 Grey unlogged")),
                React.createElement(SectionLabel, null, "Relapse Patterns"),
                React.createElement(Card, null, correlations === null ? (React.createElement("div", { className: "text-sm text-neutral-400" }, "Unlocks after 3 logged relapses.")) : correlations.length === 0 ? (React.createElement("div", { className: "text-sm text-neutral-400" }, "Keep logging.")) : (correlations.map((c) => (React.createElement("div", { key: c.label, className: "py-2 border-b border-neutral-800 last:border-0" },
                    React.createElement("div", { className: "text-sm text-neutral-200 uppercase tracking-wide font-semibold" }, c.label),
                    React.createElement("div", { className: "text-xs text-neutral-500" },
                        "Present on ",
                        c.rel,
                        "% of relapse days \u00B7 ",
                        c.base,
                        "% of all days")))))),
                React.createElement(SectionLabel, null, "Wet Dream Patterns"),
                React.createElement(Card, null, wetDreamCorrelations === null ? (React.createElement("div", { className: "text-sm text-neutral-400" }, "Unlocks after 3 logged wet dreams.")) : wetDreamCorrelations.length === 0 ? (React.createElement("div", { className: "text-sm text-neutral-400" }, "Keep logging.")) : (wetDreamCorrelations.map((c) => (React.createElement("div", { key: c.label, className: "py-2 border-b border-neutral-800 last:border-0" },
                    React.createElement("div", { className: "text-sm text-neutral-200 uppercase tracking-wide font-semibold" }, c.label),
                    React.createElement("div", { className: "text-xs text-neutral-500" },
                        "Present on ",
                        c.rel,
                        "% of wet dream days \u00B7 ",
                        c.base,
                        "% of all days")))))))),
            view === "guide" && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "font-serif text-2xl text-neutral-100 mb-4" }, "Guide"),
                GUIDE.map((g, i) => (React.createElement(Card, { key: g.t, className: "mb-2.5" },
                    React.createElement("button", { onClick: () => setOpenGuide(openGuide === i ? null : i), className: "w-full flex items-center justify-between text-left" },
                        React.createElement("span", { className: "text-sm font-bold uppercase tracking-wide text-neutral-200" }, g.t),
                        React.createElement(ChevronDown, { size: 16, className: "text-neutral-500 transition-transform " + (openGuide === i ? "rotate-180" : "") })),
                    openGuide === i && React.createElement("p", { className: "text-sm text-neutral-400 mt-2 leading-relaxed" }, g.b)))))),
            view === "settings" && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "font-serif text-2xl text-neutral-100 mb-4" }, "Settings"),
                React.createElement(SectionLabel, null, "Your Purpose Card"),
                React.createElement(Card, null,
                    React.createElement("textarea", { value: data.settings.purposeText, onChange: (e) => setSetting("purposeText", e.target.value), rows: 6, className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none text-neutral-200 leading-relaxed" }),
                    React.createElement("div", { className: "text-xs text-neutral-500 mt-1" }, "Shown when you tap Urge.")),
                React.createElement(SectionLabel, null, "Prevention Checklist Items"),
                React.createElement(Card, null, items.filter((i) => i.list === "prev").map((it) => React.createElement(ItemEditorRow, { key: it.id, item: it }))),
                React.createElement(SectionLabel, null, "Vigour Checklist Items"),
                React.createElement(Card, null, items.filter((i) => i.list === "prime").map((it) => React.createElement(ItemEditorRow, { key: it.id, item: it }))),
                React.createElement("div", { className: "mt-3" }, !showAdd ? (React.createElement("button", { onClick: () => setShowAdd(true), className: "w-full py-3 rounded-2xl border border-dashed border-neutral-700 text-neutral-400 text-sm flex items-center justify-center gap-1.5 uppercase tracking-wide" },
                    React.createElement(Plus, { size: 16 }),
                    " Add An Item")) : (React.createElement(Card, null,
                    React.createElement("input", { value: addForm.label, onChange: (e) => setAddForm({ ...addForm, label: e.target.value }), placeholder: "Item name\u2026", className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none placeholder-neutral-600 mb-3" }),
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5" }, "List"),
                    React.createElement(Seg, { value: addForm.list, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, list: v }), options: [{ v: "prev", label: "Prevention" }, { v: "prime", label: "Vigour" }] }),
                    addForm.list === "prev" && (React.createElement(React.Fragment, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5 mt-3" }, "Type"),
                        React.createElement(Seg, { value: addForm.kind, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, kind: v }), options: [{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }] }))),
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5 mt-3" }, "Weight"),
                    React.createElement(Seg, { value: addForm.weight, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, weight: v }), options: [{ v: "low", label: "Low" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }] }),
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1.5 mt-3" }, "Days"),
                    React.createElement("div", { className: "flex gap-1 mb-1.5" },
                        React.createElement("button", { onClick: () => setAddForm({ ...addForm, daily: true }), className: "px-3 py-1.5 rounded-lg text-xs uppercase border " + (addForm.daily ? "font-bold text-neutral-950" : "border-neutral-700 text-neutral-400"), style: addForm.daily ? { background: TEAL, borderColor: TEAL } : undefined }, "Every Day"),
                        React.createElement("button", { onClick: () => setAddForm({ ...addForm, daily: false }), className: "px-3 py-1.5 rounded-lg text-xs uppercase border " + (!addForm.daily ? "bg-neutral-200 border-neutral-200 text-neutral-950 font-bold" : "border-neutral-700 text-neutral-400") }, "Specific Days")),
                    !addForm.daily && (React.createElement("div", { className: "flex gap-1" }, WD.map((w, i) => {
                        const on = addForm.days.includes(i);
                        return (React.createElement("button", { key: w, onClick: () => setAddForm({ ...addForm, days: on ? addForm.days.filter((d) => d !== i) : [...addForm.days, i] }), className: "flex-1 py-1.5 rounded-lg text-xs border " + (on ? "bg-neutral-200 border-neutral-200 text-neutral-950 font-bold" : "border-neutral-700 text-neutral-500") }, w));
                    }))),
                    React.createElement("div", { className: "flex gap-2 mt-4" },
                        React.createElement("button", { onClick: addItem, className: "flex-1 py-2.5 rounded-xl text-neutral-950 text-sm font-bold uppercase", style: { background: TEAL } }, "Add Item"),
                        React.createElement("button", { onClick: () => setShowAdd(false), className: "flex-1 py-2.5 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase" }, "Cancel"))))),
                React.createElement(SectionLabel, null, "Supplements"),
                React.createElement(Card, null,
                    data.settings.supplements.map((s) => (React.createElement("div", { key: s, className: "flex items-center justify-between py-2 border-b border-neutral-800 last:border-0" },
                        React.createElement("span", { className: "text-sm text-neutral-300 uppercase tracking-wide" }, s),
                        React.createElement("button", { onClick: () => setSetting("supplements", data.settings.supplements.filter((x) => x !== s)) },
                            React.createElement(Trash2, { size: 15, className: "text-neutral-600" }))))),
                    React.createElement("div", { className: "flex gap-2 mt-3" },
                        React.createElement("input", { value: newSup, onChange: (e) => setNewSup(e.target.value), placeholder: "Add supplement\u2026", className: "flex-1 rounded-xl bull-field px-3 py-2 text-sm outline-none placeholder-neutral-600" }),
                        React.createElement("button", { onClick: () => { const v = newSup.trim(); if (v && !data.settings.supplements.includes(v))
                                setSetting("supplements", [...data.settings.supplements, v]); setNewSup(""); }, className: "px-3 rounded-xl bg-neutral-200 text-neutral-950" },
                            React.createElement(Plus, { size: 16 })))),
                React.createElement(SectionLabel, null, "Daily Reminders"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "text-xs text-neutral-500 mb-3 leading-relaxed" }, "Bull is a static app with no server, so it can't push notifications on its own. This exports two daily recurring reminders as a calendar file \u2014 import it once into iOS Calendar or Reminders for real notifications."),
                    React.createElement("div", { className: "flex gap-2 mb-3" },
                        React.createElement("div", { className: "flex-1" },
                            React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1" }, "Morning"),
                            React.createElement("input", { type: "time", value: data.settings.morningReminderTime || "08:00", onChange: (e) => setSetting("morningReminderTime", e.target.value), className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none text-neutral-100" })),
                        React.createElement("div", { className: "flex-1" },
                            React.createElement("div", { className: "text-xs uppercase tracking-wide text-neutral-500 mb-1" }, "Evening"),
                            React.createElement("input", { type: "time", value: data.settings.eveningReminderTime || "21:30", onChange: (e) => setSetting("eveningReminderTime", e.target.value), className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none text-neutral-100" }))),
                    React.createElement("button", { onClick: () => downloadReminderIcs(data.settings), className: "w-full py-2.5 rounded-xl text-neutral-950 text-xs font-bold uppercase tracking-wide", style: { background: TEAL } }, "Download Reminders (.ics)")),
                React.createElement(SectionLabel, null, "Accountability Frequency"),
                React.createElement(Card, null,
                    React.createElement(Seg, { value: data.settings.therapistEveryWeeks, allowClear: false, onChange: (v) => v && setSetting("therapistEveryWeeks", v), options: [{ v: 1, label: "Weekly" }, { v: 2, label: "2 Wks" }, { v: 3, label: "3 Wks" }, { v: 4, label: "4 Wks" }] })),
                React.createElement(SectionLabel, null, "Backdate Last Relapse"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("input", { type: "date", value: data.settings.manualLastRelapseDate ? new Date(data.settings.manualLastRelapseDate - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10) : "", onChange: (e) => {
                                const v = e.target.value;
                                setSetting("manualLastRelapseDate", v ? new Date(v + "T00:00:00").getTime() : null);
                            }, className: "flex-1 rounded-xl bull-field px-3 py-2 text-sm outline-none text-neutral-100" }),
                        data.settings.manualLastRelapseDate && (React.createElement("button", { onClick: () => setSetting("manualLastRelapseDate", null), className: "px-3 rounded-xl bg-neutral-800 text-neutral-400 text-xs uppercase tracking-wide" }, "Clear")))),
                React.createElement(SectionLabel, null, "Data"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex gap-2 mb-3" },
                        React.createElement("button", { onClick: () => {
                                const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
                                const url = URL.createObjectURL(blob);
                                const a = document.createElement("a");
                                a.href = url;
                                a.download = "bull-backup-" + todayKey() + ".json";
                                a.click();
                                setTimeout(() => URL.revokeObjectURL(url), 5000);
                            }, className: "flex-1 py-2.5 rounded-xl text-black text-xs font-bold uppercase tracking-wide", style: { background: TEAL } }, "Export"),
                        React.createElement("label", { className: "flex-1 py-2.5 rounded-xl bg-neutral-800 text-neutral-300 text-xs font-bold uppercase tracking-wide text-center cursor-pointer" },
                            "Import",
                            React.createElement("input", { type: "file", accept: ".json,application/json", className: "hidden", onChange: (e) => {
                                    const f = e.target.files && e.target.files[0];
                                    if (!f)
                                        return;
                                    const reader = new FileReader();
                                    reader.onload = () => {
                                        try {
                                            const parsed = migrate(JSON.parse(String(reader.result)));
                                            if (parsed && parsed.days && parsed.items)
                                                persist(parsed);
                                        }
                                        catch (err) {
                                            console.error("import failed", err);
                                        }
                                    };
                                    reader.readAsText(f);
                                } }))),
                    resetStep === 0 && React.createElement("button", { onClick: () => setResetStep(1), className: "text-sm text-rose-400 uppercase tracking-wide" }, "Reset All Data"),
                    resetStep === 1 && (React.createElement("div", null,
                        React.createElement("div", { className: "text-sm text-neutral-300 mb-2" }, "This wipes every log, urge, relapse, item and setting. Sure?"),
                        React.createElement("div", { className: "flex gap-2" },
                            React.createElement("button", { onClick: async () => {
                                    await storageClear();
                                    setResetStep(0);
                                    persist({ version: 6, settings: { ...DEFAULT_SETTINGS }, items: DEFAULT_ITEMS.map((i) => ({ ...i, freq: Array.isArray(i.freq) ? [...i.freq] : i.freq })), days: {}, urges: [], relapses: [], firstUse: Date.now() });
                                }, className: "flex-1 py-2 rounded-xl bg-rose-500 text-neutral-50 text-sm font-bold uppercase" }, "Wipe Everything"),
                            React.createElement("button", { onClick: () => setResetStep(0), className: "flex-1 py-2 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase" }, "Cancel")))),
                    React.createElement("div", { className: "text-xs text-neutral-600 mt-3" }, "On-device only."))))),
        React.createElement("div", { className: "fixed bottom-0 inset-x-0 z-[45] bull-nav", style: { paddingBottom: "env(safe-area-inset-bottom, 0px)" } },
            React.createElement("div", { className: "max-w-md mx-auto flex" },
                React.createElement(NavBtn, { id: "today", icon: Shield, label: "Today" }),
                React.createElement(NavBtn, { id: "stats", icon: BarChart3, label: "Patterns" }),
                React.createElement(NavBtn, { id: "guide", icon: BookOpen, label: "Guide" }),
                React.createElement(NavBtn, { id: "settings", icon: SettingsIcon, label: "Settings" })))));
}
import { createRoot } from "https://esm.sh/react-dom@18.3.1/client";
createRoot(document.getElementById("root")).render(React.createElement(App, null));

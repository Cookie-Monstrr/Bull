import React, { useState, useEffect, useRef } from "https://esm.sh/react@18.3.1";
/* ---------- icons (self-contained, no external icon package) ---------- */
const IconBase = ({ children, size = 20, ...p }) => (React.createElement("svg", { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", ...p }, children));
const CalIcon = (p) => React.createElement(IconBase, { ...p }, React.createElement("rect", { x: "3", y: "4", width: "18", height: "18", rx: "2" }), React.createElement("path", { d: "M16 2v4M8 2v4M3 10h18" }));
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
function fastingSuggested(date, mode) {
    const h = hijriDay(date);
    const lunar = h !== null && h >= 13 && h <= 15;
    const weekly = date.getDay() === 1 || date.getDay() === 4;
    if (mode === "lunar")
        return lunar;
    if (mode === "weekly")
        return weekly;
    return weekly || lunar;
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
/* ---------- score visuals: physique (vigour) + devil (risk) ---------- */
function pts(arr) { return arr.map((p) => p[0].toFixed(2) + "," + p[1].toFixed(2)).join(" "); }
function VigourFigure({ pct, size = 58 }) {
    const t = Math.max(0, Math.min(1, (pct || 0) / 100));
    const sw = 7.5 + 11.5 * t, wz = 6.5 + 3.0 * t, aw = 2.2 + 3.4 * t;
    const lg = 3.6 + 3.0 * t, nk = 2.0 + 2.4 * t, hr = 8.6 - 0.6 * t;
    const bd = 1.2 + 7.5 * t, bw = 2.4 + (hr * 0.96 - 2.4) * t;
    const G = "url(#figGrad)";
    return (React.createElement("div", { className: "flex flex-col items-center" },
        React.createElement("svg", { width: size, height: size, viewBox: "0 0 100 100", style: { overflow: "visible" } },
            React.createElement("defs", null,
                React.createElement("linearGradient", { id: "figGrad", x1: "0%", y1: "0%", x2: "100%", y2: "100%" },
                    React.createElement("stop", { offset: "0%", stopColor: "#e6b53f" }),
                    React.createElement("stop", { offset: "100%", stopColor: "#c9962c" }))),
            React.createElement("polygon", { points: pts([[50 - wz, 64], [50 - wz + lg, 64], [50 - 1.2, 93], [50 - 1.2 - lg, 93]]), fill: G }),
            React.createElement("polygon", { points: pts([[50 + wz, 64], [50 + wz - lg, 64], [50 + 1.2, 93], [50 + 1.2 + lg, 93]]), fill: G }),
            React.createElement("polygon", { points: pts([[50 - sw, 41], [50 + sw, 41], [50 + wz, 65], [50 - wz, 65]]), fill: G }),
            React.createElement("polygon", { points: pts([[50 - sw, 41.5], [50 - sw - aw, 43.5], [50 - sw - aw + 0.8, 67], [50 - sw + 1.6, 66]]), fill: G }),
            React.createElement("polygon", { points: pts([[50 + sw, 41.5], [50 + sw + aw, 43.5], [50 + sw + aw - 0.8, 67], [50 + sw - 1.6, 66]]), fill: G }),
            React.createElement("polygon", { points: pts([[50 - nk, 32], [50 + nk, 32], [50 + nk, 42], [50 - nk, 42]]), fill: G }),
            React.createElement("circle", { cx: 50, cy: 24, r: hr, fill: G }),
            React.createElement("path", { d: `M${(50 - bw).toFixed(2)} 26.5 C${(50 - bw - 1.2).toFixed(2)} ${(29 + bd).toFixed(2)}, 50 ${(31.5 + bd).toFixed(2)}, ${(50 + bw + 1.2).toFixed(2)} ${(29 + bd).toFixed(2)} L${(50 + bw).toFixed(2)} 26.5 Z`, fill: "#6b4d10", opacity: 0.45 + 0.55 * t }),
            t > 0.3 && React.createElement("g", { stroke: "#faf6ef", strokeLinecap: "round", fill: "none", opacity: (t - 0.3) / 0.7 },
                React.createElement("path", { strokeWidth: "1.2", d: "M50 44 L50 62" }),
                React.createElement("path", { strokeWidth: "1.2", d: `M${(50 - sw * 0.55).toFixed(2)} 47 L${(50 + sw * 0.55).toFixed(2)} 47` }),
                React.createElement("path", { strokeWidth: "1", d: `M${(50 - wz * 0.6).toFixed(2)} 53 L${(50 + wz * 0.6).toFixed(2)} 53` }),
                React.createElement("path", { strokeWidth: "1", d: `M${(50 - wz * 0.6).toFixed(2)} 58 L${(50 + wz * 0.6).toFixed(2)} 58` }))),
        React.createElement("div", { className: "text-[9px] uppercase tracking-[0.14em] text-[#9a9285] mt-1 font-semibold" }, "Vigour \u00B7 ", Math.round(pct || 0))));
}
function DevilRisk({ risk, size = 58 }) {
    const d = Math.max(0, Math.min(1, (risk || 0) / 100));
    const sc = 0.32 + 0.88 * d, cx = 50, cy = 58;
    const T = (x, y) => [cx + (x - 50) * sc, cy + (y - 50) * sc];
    const col = d < 0.5 ? "#d24a44" : "#b62f2b";
    const tail = [T(59, 64), T(70, 66), T(74, 54), T(70, 46)];
    return (React.createElement("div", { className: "flex flex-col items-center" },
        React.createElement("svg", { width: size, height: size, viewBox: "0 0 100 100", style: { overflow: "visible" } },
            React.createElement("polyline", { points: pts(tail), fill: "none", stroke: col, strokeWidth: 2.2 * sc + 0.7, strokeLinecap: "round" }),
            React.createElement("polygon", { points: pts([T(70, 46), T(66, 42), T(74, 42)]), fill: col }),
            React.createElement("polygon", { points: pts([T(41, 45), T(59, 45), T(62, 75), T(38, 75)]), fill: col }),
            React.createElement("polygon", { points: pts([T(41, 47), T(32, 57), T(35, 60), T(44, 51)]), fill: col }),
            React.createElement("polygon", { points: pts([T(59, 47), T(68, 57), T(65, 60), T(56, 51)]), fill: col }),
            React.createElement("polygon", { points: pts([T(43, 75), T(48, 75), T(47, 89), T(41, 89)]), fill: col }),
            React.createElement("polygon", { points: pts([T(57, 75), T(52, 75), T(53, 89), T(59, 89)]), fill: col }),
            React.createElement("circle", { cx: T(50, 33)[0], cy: T(50, 33)[1], r: 9.5 * sc, fill: col }),
            React.createElement("polygon", { points: pts([T(43, 27), T(38, 16), T(46, 25)]), fill: col }),
            React.createElement("polygon", { points: pts([T(57, 27), T(62, 16), T(54, 25)]), fill: col }),
            React.createElement("circle", { cx: T(46.5, 32)[0], cy: T(46.5, 32)[1], r: 1.3 * sc, fill: "#faf6ef" }),
            React.createElement("circle", { cx: T(53.5, 32)[0], cy: T(53.5, 32)[1], r: 1.3 * sc, fill: "#faf6ef" }),
            React.createElement("polyline", { points: pts([T(45, 37), T(50, 40), T(55, 37)]), fill: "none", stroke: "#faf6ef", strokeWidth: 1.3 * sc + 0.35, strokeLinecap: "round" })),
        React.createElement("div", { className: "text-[9px] uppercase tracking-[0.14em] text-[#9a9285] mt-1 font-semibold" }, "Risk \u00B7 ", Math.round(risk || 0))));
}
/* ---------- month view ---------- */
function riskTileColor(r) {
    const x = Math.max(0, Math.min(100, r));
    return x <= 50 ? mixHex("#5c8a3c", "#c2701e", x / 50) : mixHex("#c2701e", "#b62f2b", (x - 50) / 50);
}
function vigourTileColor(v) {
    const x = Math.max(0, Math.min(100, v));
    return x <= 50 ? mixHex("#e7dcc4", "#c9962c", x / 50) : mixHex("#c9962c", "#8a6318", (x - 50) / 50);
}
function MonthView({ data, items, settings, onPick, onClose }) {
    const [mOff, setMOff] = useState(0);
    const now = new Date();
    const base = new Date(now.getFullYear(), now.getMonth() + mOff, 1);
    const year = base.getFullYear(), month = base.getMonth();
    const daysIn = new Date(year, month + 1, 0).getDate();
    const startDow = base.getDay();
    const tk = todayKey();
    const relByKey = {};
    data.relapses.forEach((r) => { relByKey[dateKey(new Date(r.ts))] = r.type || "orgasm"; });
    const wetKeys = new Set((data.wetDreams || []).map((w) => dateKey(new Date(w.ts))));
    const t0 = new Date(); t0.setHours(12, 0, 0, 0);
    const cells = [];
    for (let i = 0; i < startDow; i++)
        cells.push(React.createElement("div", { key: "b" + i }));
    for (let n = 1; n <= daysIn; n++) {
        const d = new Date(year, month, n, 12, 0, 0, 0);
        const k = dateKey(d);
        const rec = data.days[k];
        const future = d.getTime() > t0.getTime();
        const isToday = k === tk;
        const relType = relByKey[k];
        const wet = wetKeys.has(k);
        const logged = !!rec && riskLogged(rec, items);
        const uc = data.urges.filter((u) => dateKey(new Date(u.ts)) === k).length;
        const rs = logged ? Math.round(riskScore({ ...emptyDay(), ...rec }, items, uc, !!relType)) : null;
        const vh = rec ? vigourForDay({ ...emptyDay(), ...rec }, d, items, settings) : null;
        const vp = vh && vh.total ? Math.round((vh.done / vh.total) * 100) : null;
        const showBand = !future && vp !== null;
        let style = { border: "1px solid rgba(42,36,25,0.10)", background: "transparent", color: "#b8b0a2" };
        if (future)
            style = { border: "1px solid rgba(42,36,25,0.05)", background: "transparent", color: "#d4cec3" };
        else if (relType)
            style = { border: "none", background: relType === "edge" ? "#c9453f" : "#a02623", color: "#fff5f4", fontWeight: 700 };
        else if (rs !== null)
            style = { border: "none", background: riskTileColor(rs), color: "#fff", fontWeight: 600 };
        if (isToday)
            style.boxShadow = "0 0 0 2px #2a2419";
        if (showBand)
            style.paddingBottom = "30%";
        cells.push(React.createElement("button", {
            key: k, disabled: future,
            onClick: () => { if (!future) { onPick(Math.round((d.getTime() - t0.getTime()) / DAY_MS)); onClose(); } },
            style: { ...style, borderRadius: 12 },
            className: "aspect-square flex flex-col items-center justify-center relative active:scale-95 transition-transform leading-none",
        },
            React.createElement("span", { className: "text-[11px]" }, n),
            rs !== null && React.createElement("span", { className: "text-[13px] font-bold mt-0.5" }, rs),
            relType && React.createElement("span", { className: "absolute top-1 right-1.5 text-[8px] font-bold opacity-90" }, relType === "edge" ? "E" : "O"),
            showBand && React.createElement("div", {
                className: "absolute left-0 right-0 bottom-0 flex items-center justify-center",
                style: { height: "30%", borderRadius: "0 0 11px 11px", background: vigourTileColor(vp), color: vp <= 40 ? "#5a4a1f" : "#fff5e0" },
            }, React.createElement("span", { className: "text-[9px] font-bold" }, vp)),
            wet && React.createElement("span", { className: "absolute bottom-1 right-1 w-1.5 h-1.5 rounded-full", style: { background: "#ffffff", boxShadow: "0 0 0 1px rgba(42,36,25,0.25)" } })));
    }
    return (React.createElement("div", { className: "fixed inset-0 z-[60] overflow-y-auto", style: { background: "#faf6ef" } },
        React.createElement("div", { className: "max-w-[430px] mx-auto p-5", style: { paddingTop: "calc(env(safe-area-inset-top,0px) + 18px)" } },
            React.createElement("div", { className: "flex items-center justify-between mb-5" },
                React.createElement("button", { onClick: () => setMOff(mOff - 1), className: "px-3 py-2 text-lg text-[#8a8172]" }, "\u2039"),
                React.createElement("div", { className: "font-serif text-xl text-[#2a2419]" }, base.toLocaleDateString(undefined, { month: "long", year: "numeric" })),
                React.createElement("button", { onClick: () => mOff < 0 && setMOff(mOff + 1), disabled: mOff >= 0, className: "px-3 py-2 text-lg " + (mOff >= 0 ? "text-[#d4cec3]" : "text-[#8a8172]") }, "\u203A")),
            React.createElement("div", { className: "grid grid-cols-7 gap-1.5 mb-2" }, ["S", "M", "T", "W", "T", "F", "S"].map((w, i) => React.createElement("div", { key: i, className: "text-center text-[9px] uppercase tracking-[0.14em] text-[#9a9285]" }, w))),
            React.createElement("div", { className: "grid grid-cols-7 gap-1.5" }, cells),
            React.createElement("div", { className: "mt-7" },
                React.createElement("div", { className: "text-[9px] uppercase tracking-[0.2em] text-[#9a9285] mb-3" }, "Legend"),
                React.createElement("div", { className: "flex items-center gap-2 mb-1.5" },
                    React.createElement("div", { className: "flex-1 h-3 rounded-full", style: { background: "linear-gradient(90deg,#5c8a3c,#c2701e,#b62f2b)" } })),
                React.createElement("div", { className: "flex justify-between text-[9px] uppercase tracking-[0.14em] text-[#9a9285] mb-2.5" },
                    React.createElement("span", null, "Risk 0"),
                    React.createElement("span", null, "Risk 100")),
                React.createElement("div", { className: "flex items-center gap-2 mb-1.5" },
                    React.createElement("div", { className: "flex-1 h-3 rounded-full", style: { background: "linear-gradient(90deg,#e7dcc4,#c9962c,#8a6318)" } })),
                React.createElement("div", { className: "flex justify-between text-[9px] uppercase tracking-[0.14em] text-[#9a9285] mb-4" },
                    React.createElement("span", null, "Vigour 0"),
                    React.createElement("span", null, "Vigour 100")),
                React.createElement("div", { className: "grid grid-cols-2 gap-y-2.5 gap-x-3" },
                    [
                        { sw: { background: "#a02623" }, badge: "O", t: "Relapse \u2014 orgasm" },
                        { sw: { background: "#c9453f" }, badge: "E", t: "Relapse \u2014 edged" },
                        { sw: { background: "transparent", border: "1px solid rgba(42,36,25,0.14)" }, t: "Not logged" },
                        { sw: { background: "transparent", border: "1px solid rgba(42,36,25,0.14)", boxShadow: "0 0 0 2px #2a2419" }, t: "Today" },
                        { sw: { background: "transparent", border: "1px solid rgba(42,36,25,0.14)" }, dot: true, t: "Wet dream" },
                    ].map((L, i) => React.createElement("div", { key: i, className: "flex items-center gap-2.5" },
                        React.createElement("div", { style: { ...L.sw, width: 18, height: 18, borderRadius: 6, flexShrink: 0, position: "relative" } },
                            L.badge && React.createElement("span", { style: { position: "absolute", inset: 0, color: "#fff", fontSize: 9, fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center" } }, L.badge),
                            L.dot && React.createElement("span", { style: { position: "absolute", bottom: 2, left: "50%", marginLeft: -2, width: 4, height: 4, borderRadius: 999, background: "#c2701e" } })),
                        React.createElement("span", { className: "text-[10px] leading-tight text-[#8a8172]" }, L.t))))),
            React.createElement("div", { className: "flex gap-2 mt-7" },
                React.createElement("button", { onClick: () => { onPick(0); onClose(); }, className: "flex-1 py-3.5 rounded-2xl font-bold uppercase tracking-widest text-sm", style: { border: "1px solid rgba(42,36,25,0.18)", color: "#4a4335" } }, "Today"),
                React.createElement("button", { onClick: onClose, className: "flex-1 py-3.5 rounded-2xl text-neutral-950 font-bold uppercase tracking-widest text-sm", style: { background: "var(--accent, #c9962c)" } }, "Close")))));
}
/* ---------- Apple Health receiver (Shortcuts opens Bull with query params) ---------- */
function readHealthParams() {
    try {
        const q = new URLSearchParams(window.location.search);
        const out = {};
        [["hrv", "hrv"], ["recovery", "recovery"], ["sleep", "sleep"], ["strain", "strain"]].forEach(([k, field]) => {
            const raw = q.get(k);
            if (raw !== null && raw !== "" && !isNaN(Number(raw)))
                out[field] = Number(raw);
        });
        const date = q.get("date");
        return Object.keys(out).length ? { values: out, dateKey: date || null } : null;
    } catch (e) { return null; }
}
/* ---------- gamified vigour tiers ---------- */
/* ---------- colours ---------- */
const TEAL = "#c9962c"; /* gold — primary accent */
const AMBER = "#c9962c"; /* gold — vigour */
const ROSE = "#b62f2b"; /* crimson — danger */
/* ---------- ambient color utilities ---------- */
function hexToRgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function lerpN(a, b, t) { return a + (b - a) * t; }
function mixHex(h1, h2, t) {
    const a = hexToRgb(h1), b = hexToRgb(h2);
    const to2 = (n) => Math.round(n).toString(16).padStart(2, "0");
    return "#" + to2(lerpN(a[0], b[0], t)) + to2(lerpN(a[1], b[1], t)) + to2(lerpN(a[2], b[2], t));
}
const CAUTION = "#c2701e";
/* ---------- vigour buckets: group priming actions by the mechanism they act on ---------- */
const BUCKETS = [
    { id: "test", label: "Testosterone" },
    { id: "heart", label: "Heart Health" },
    { id: "no", label: "Nitric Oxide" },
    { id: "pelvic", label: "Pelvic Floor" },
];
const WEIGHT_OPTS = [{ v: "low", label: "Low" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }, { v: "vhigh", label: "V.High", tone: "risk" }];
const wLabel = (w) => (w === "vhigh" ? "V.HIGH" : String(w || "med").toUpperCase());
/* an item on list "both" scores on Prevention (weight) and Vigour (vigourWeight) independently */
const isPrev = (i) => i.list === "prev" || i.list === "both";
const isPrime = (i) => i.list === "prime" || i.list === "both";
/* ---------- weights ---------- */
const W_RISK = { vhigh: 30, high: 20, med: 10, low: 5 };
const W_PROT = { vhigh: 11, high: 8, med: 5, low: 2 };
const W_ADH = { vhigh: 4, high: 3, med: 2, low: 1 };
const WEIGHT_RANK = { vhigh: 4, high: 3, med: 2, low: 1 };
const byWeightDesc = (a, b) => (WEIGHT_RANK[b.weight] || 0) - (WEIGHT_RANK[a.weight] || 0);
const WEIGHT_SCALE = { vhigh: 1.4, high: 1, med: 0.6, low: 0.3 };
/* ---------- default items ---------- */
const DEFAULT_ITEMS = [
    { id: "lonely", label: "Home Alone, Unstructured Time", list: "prev", kind: "risk", weight: "high", freq: "daily" },
    { id: "junk", label: "Junk Food", list: "both", kind: "risk", weight: "med", vigourWeight: "low", bucket: "heart", freq: "daily" },
    { id: "coldplunge", label: "Cold Plunge", list: "both", kind: "habit", weight: "med", vigourWeight: "low", bucket: "heart", freq: "daily", excusable: true },
    { id: "nasalclear", label: "Nasal Rinse", list: "both", kind: "habit", weight: "med", vigourWeight: "med", bucket: "no", freq: "daily" },
    { id: "contentAccess", label: "Content Access", sub: "Low / Medium / High, logged daily", list: "prev", kind: "tier", weight: "high" },
    { id: "checkout", label: "Checking Out Women", sub: "None / A Few / A Lot, logged daily", list: "prev", kind: "tier", weight: "high" },
    { id: "recoveryLow", label: "Recovery Below 40%", sub: "Auto — from your Recovery Score", list: "prev", kind: "derived", weight: "med" },
    { id: "purposeLow", label: "Low-Purpose Day (1–2)", sub: "Auto — from your Evening Review", list: "prev", kind: "derived", weight: "med" },
    { id: "purposeHigh", label: "High-Purpose Day (4–5)", sub: "Auto — protective, from your Evening Review", list: "prev", kind: "derived", weight: "med" },
    { id: "accountabilityGap", label: "Accountability Not On Track", sub: "Auto — nothing booked, overdue, or too far out", list: "prev", kind: "derived", weight: "high" },
    { id: "urgeSurvivalBonus", label: "Urges Survived Today", sub: "Auto — protective, from the Urge button", list: "prev", kind: "derived", weight: "med" },
    { id: "sickFlag", label: "Sick Day", sub: "Auto — from the Sick flag on Today", list: "prev", kind: "derived", weight: "med" },
    { id: "travelFlag", label: "Travelling Day", sub: "Auto — from the Travelling flag on Today", list: "prev", kind: "derived", weight: "high" },
    { id: "kegels", label: "Kegels", list: "prime", kind: "habit", weight: "high", freq: [1, 3, 5, 0], excusable: true, bucket: "pelvic" },
    { id: "stretches", label: "Pelvic Floor Stretches", list: "prime", kind: "habit", weight: "med", freq: [1, 3, 5, 0], excusable: true, bucket: "pelvic" },
    { id: "cardio", label: "Cardio / Boxing", list: "prime", kind: "habit", weight: "high", freq: [1, 3, 5, 0], excusable: true, bucket: "heart" },
    { id: "strength", label: "Strength Training", list: "prime", kind: "habit", weight: "med", freq: [2, 6], excusable: true, bucket: "test" },
    { id: "breathwork", label: "Breathwork Before Isha", list: "prime", kind: "habit", weight: "med", freq: "daily", bucket: "no" },
    { id: "fasting", label: "Fasting", list: "prime", kind: "habit", weight: "med", freq: "daily", fastingAuto: true, bucket: "test" },
];
const DEFAULT_PURPOSE = "I am preparing for her before I have met her. Every clean day is me becoming the man and husband I intend to be on day one — clear-eyed, disciplined, present.\n\nThis urge is a wave. It rises, it peaks, it passes. I do not act on it. I am building something better.";
const DEFAULT_SETTINGS = {
    purposeText: DEFAULT_PURPOSE,
    supplements: ["Zinc", "Magnesium", "Vitamin D"],
    therapistEveryWeeks: 2,
    nextCheckin: null,
    fastMode: "both",
    sleepWeight: 2,
    morningReminderTime: "08:00",
    eveningReminderTime: "21:30",
};
const emptyDay = () => ({
    checks: {}, access: null, checkout: null,
    intentionText: "", intentionSet: false, purposeRating: null,
    recovery: null, sleep: null, hrv: null, strain: null,
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
    base.settings = { fastMode: "both", sleepWeight: 2, morningReminderTime: "08:00", eveningReminderTime: "21:30", ...base.settings };
    base.wetDreams = base.wetDreams || [];
    base.items = (base.items || []).filter((i) => i.id !== "latescreen");
    const NEW_BUILTIN_IDS = ["contentAccess", "checkout", "recoveryLow", "purposeLow", "purposeHigh", "accountabilityGap", "urgeSurvivalBonus", "sickFlag", "travelFlag"];
    NEW_BUILTIN_IDS.forEach((id) => {
        if (!base.items.some((i) => i.id === id)) {
            const def = DEFAULT_ITEMS.find((i) => i.id === id);
            if (def)
                base.items.push({ ...def });
        }
    });
    /* backfill excusable defaults onto existing saved items that predate the flag */
    base.items = base.items.map((i) => {
        if (i.excusable !== undefined)
            return i;
        const def = DEFAULT_ITEMS.find((x) => x.id === i.id);
        return def && def.excusable ? { ...i, excusable: true } : i;
    });
    /* items retired on scientific grounds — drop them from saved data too */
    const RETIRED_IDS = ["mouthtape", "caffeine"];
    base.items = base.items.filter((i) => !RETIRED_IDS.includes(i.id));
    /* fasting moved from a lunar-only boolean to a three-way mode. Keyed off the OLD
       flag, not off fastMode — the defaults line above already gave fastMode a value. */
    if (base.settings && base.settings.fastLunarOnly !== undefined) {
        base.settings.fastMode = base.settings.fastLunarOnly ? "lunar" : "both";
        delete base.settings.fastLunarOnly;
    }
    /* backfill bucket + dual-list scoring onto saved items that predate the buckets */
    base.items = base.items.map((i) => {
        const def = DEFAULT_ITEMS.find((x) => x.id === i.id);
        if (!def)
            return i;
        const patch = {};
        if (i.bucket === undefined && def.bucket !== undefined)
            patch.bucket = def.bucket;
        if (def.list === "both" && i.list !== "both")
            patch.list = "both";
        if (i.vigourWeight === undefined && def.vigourWeight !== undefined)
            patch.vigourWeight = def.vigourWeight;
        return Object.keys(patch).length ? { ...i, ...patch } : i;
    });
    return { ...base, version: 7 };
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
        return fastingSuggested(date, settings && settings.fastMode);
    return scheduledOn(item, date);
}
/* ---------- scoring ---------- */
function riskScore(day, items, urgesSurvived, hadRelapse, accountabilityPenalty = 0) {
    const d = day || emptyDay();
    const wOf = (id, fallback) => (items.find((i) => i.id === id) || {}).weight || fallback;
    const scaleOf = (id, fallback) => WEIGHT_SCALE[wOf(id, fallback)] || WEIGHT_SCALE[fallback] || 1;
    let r = 15;
    const flaggedDay = d.sick === true || d.travelling === true;
    items.filter((i) => isPrev(i) && (i.kind === "risk" || i.kind === "habit")).forEach((it) => {
        const v = d.checks ? d.checks[it.id] : undefined;
        /* excusable items are neutral on a sick/travelling day — neither earned nor lost,
           so the flag's own weight carries the environmental risk without double-counting */
        if (flaggedDay && it.excusable === true)
            return;
        if (it.kind === "risk") {
            if (v === true)
                r += W_RISK[it.weight] || W_RISK.med;
        }
        else {
            if (v === true)
                r -= W_PROT[it.weight] || W_PROT.med;
        }
    });
    if (d.sick === true)
        r += W_RISK[wOf("sickFlag", "med")] || W_RISK.med;
    if (d.travelling === true)
        r += W_RISK[wOf("travelFlag", "high")] || W_RISK.high;
    const hasContentAccess = items.some((i) => i.id === "contentAccess");
    if (hasContentAccess) {
        const accessScale = scaleOf("contentAccess", "high");
        if (d.access === "high")
            r += Math.round(25 * accessScale);
        else if (d.access === "med")
            r += Math.round(12 * accessScale);
    }
    const hasCheckout = items.some((i) => i.id === "checkout");
    if (hasCheckout) {
        const checkoutScale = scaleOf("checkout", "high");
        if (d.checkout === "lot")
            r += Math.round(12 * checkoutScale);
        else if (d.checkout === "few")
            r += Math.round(4 * checkoutScale);
    }
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
    const anyRisk = items.some((i) => isPrev(i) && day.checks && day.checks[i.id] !== undefined && day.checks[i.id] !== null);
    return anyRisk || day.access != null || day.checkout != null || day.purposeRating != null;
}
function vigourForDay(day, date, items, settings) {
    const d = day || emptyDay();
    let total = 0, done = 0;
    const flaggedDay = d.sick === true || d.travelling === true;
    items.filter((i) => isPrime(i) && (i.kind === "habit" || i.kind === "risk")).forEach((it) => {
        if (!adherenceExpected(it, date, settings))
            return;
        if (flaggedDay && it.excusable === true)
            return;
        /* dual items carry their own vigour weight, independent of their prevention weight */
        const w = W_ADH[it.vigourWeight || it.weight] || 2;
        const v = d.checks ? d.checks[it.id] : undefined;
        total += w;
        /* a risk-kind dual item earns vigour by being AVOIDED, not by being done */
        if (it.kind === "risk" ? v === false : v === true)
            done += w;
    });
    const sups = settings.supplements || [];
    if (sups.length) {
        total += 2;
        const taken = sups.filter((s) => d.supplementsTaken && d.supplementsTaken[s]).length;
        done += 2 * (taken / sups.length);
    }
    /* sleep score contributes proportionally once logged */
    const sw = settings.sleepWeight === undefined ? 2 : settings.sleepWeight;
    if (sw > 0 && d.sleep !== null && d.sleep !== undefined && d.sleep !== "") {
        total += sw;
        done += sw * Math.max(0, Math.min(1, Number(d.sleep) / 100));
    }
    return { done, total };
}
function riskColor(r) { return r <= 25 ? TEAL : r <= 55 ? CAUTION : ROSE; }
/* ---------- UI atoms ---------- */
function Card({ children, className = "" }) {
    return React.createElement("div", { className: "rounded-2xl p-4 " + className, style: { background: "rgba(42,36,25,0.035)" } }, children);
}
function Rows({ children, className = "" }) {
    return React.createElement("div", { className: className }, children);
}
function GroupHeader({ icon: Icon, color, children }) {
    return (React.createElement("div", { className: "flex items-center gap-2.5 mt-7 mb-1" },
        React.createElement(Icon, { size: 17, style: { color, opacity: 0.8 } }),
        React.createElement("div", { className: "font-serif text-[15px] tracking-[0.18em]", style: { color, opacity: 0.95 } }, children)));
}
function EvChip({ ev }) {
    const map = {
        strong: ["Strong", "rgba(92,138,60,0.16)", "#456a2c"],
        moderate: ["Moderate", "rgba(194,112,30,0.16)", "#8f5312"],
        weak: ["Weak", "rgba(182,47,43,0.14)", "#8f2320"],
    };
    const m = map[ev];
    if (!m)
        return null;
    return React.createElement("span", { className: "text-[8px] uppercase tracking-[0.12em] font-bold px-2 py-[3px] rounded-full whitespace-nowrap", style: { background: m[1], color: m[2] } }, m[0]);
}
function SectionLabel({ children }) {
    return React.createElement("div", { className: "text-[10px] uppercase tracking-[0.22em] mb-1 mt-4", style: { color: "#6a6358" } }, children);
}
function Seg({ value, options, onChange, allowClear = true }) {
    return (React.createElement("div", { className: "flex flex-wrap gap-1.5" }, options.map((o) => {
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
function Tile({ label, sub, value, onChange, mode = "risk" }) {
    /* mode "risk": tri-state null -> true(happened) -> false(avoided) -> null
       other modes: binary not-done / done */
    const isRisk = mode === "risk";
    const v = value === undefined ? null : value;
    const next = () => onChange(isRisk ? (v === null ? true : v === true ? false : null) : (v === true ? null : true));
    let style, stateText;
    if (isRisk) {
        if (v === true) {
            style = { background: "linear-gradient(150deg,#d24a44,#b62f2b)", borderColor: "#b62f2b", color: "#fff5f4", fontWeight: 700, boxShadow: "0 4px 14px rgba(182,47,43,0.28)" };
            stateText = "Happened";
        } else if (v === false) {
            style = { background: "rgba(201,150,44,0.10)", borderColor: "rgba(201,150,44,0.38)", color: "#8a7333" };
            stateText = "Avoided";
        } else {
            style = { background: "rgba(200,50,47,0.045)", borderColor: "rgba(200,50,47,0.14)", color: "#8a6360" };
            stateText = "Not logged";
        }
    } else {
        if (v === true) {
            style = { background: "linear-gradient(150deg,#e6b53f,#c9962c)", borderColor: "#c9962c", color: "#2a2005", fontWeight: 700, boxShadow: "0 4px calc(8px + var(--vig,0.5)*18px) rgba(201,150,44,calc(0.18 + var(--vig,0.5)*0.32))" };
            stateText = "Done";
        } else {
            style = { background: "rgba(42,36,25,0.035)", borderColor: "rgba(42,36,25,0.10)", color: "#6f6757" };
            stateText = "Not done";
        }
    }
    return (React.createElement("button", { onClick: next, style: { ...style, borderWidth: 1, borderStyle: "solid" }, className: "text-left rounded-2xl p-3.5 min-h-[76px] flex flex-col justify-between active:scale-[0.97] transition-all" },
        React.createElement("span", { className: "text-[12.5px] leading-snug tracking-[0.01em]" }, label),
        React.createElement("span", { className: "text-[9.5px] uppercase tracking-[0.16em] opacity-75 mt-2" }, stateText)));
}
function TileGrid({ children }) {
    return React.createElement("div", { className: "grid grid-cols-2 gap-2.5" }, children);
}
function NumField({ label, value, onChange, max = 100, suffix }) {
    return (React.createElement("div", { className: "flex-1" },
        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1" }, label),
        React.createElement("div", { className: "flex items-center gap-1 rounded-xl bull-field px-3 py-2" },
            React.createElement("input", { inputMode: "numeric", value: value === null || value === undefined ? "" : value, onChange: (e) => {
                    const raw = e.target.value.replace(/[^0-9]/g, "");
                    if (raw === "")
                        return onChange(null);
                    onChange(Math.min(max, parseInt(raw, 10)));
                }, placeholder: "\u2014", className: "w-full bg-transparent text-[#2a2419] text-base outline-none placeholder-neutral-600" }),
            suffix && React.createElement("span", { className: "text-xs text-[#8a8172]" }, suffix))));
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
        label && React.createElement("div", { className: "text-[10px] uppercase tracking-widest text-[#8a8172] mt-1 font-semibold" }, label)));
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
        React.createElement("div", { className: "text-[10px] uppercase tracking-widest text-[#8a8172] mt-1 font-semibold" }, "Risk \u00B7 ", Math.round(risk))));
}
const SPLASH_CSS = `
.bull-splash{position:relative;width:100%;max-width:430px;height:100dvh;margin:0 auto;display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden;background:#faf6ef;font-family:'JetBrains Mono',monospace;}
.bull-splash .glow{position:absolute;inset:-20%;background:radial-gradient(circle at 50% 42%,#f5e6c4 0%,#faf6ef 62%);opacity:0;transition:opacity 1.4s ease;}
.bull-splash.on .glow{opacity:1;}
.bull-splash .pulse{position:absolute;top:42%;left:50%;width:min(72vw,300px);height:min(72vw,300px);transform:translate(-50%,-50%);border-radius:50%;background:radial-gradient(circle,rgba(201,150,44,0.30) 0%,rgba(201,150,44,0) 70%);opacity:0;}
.bull-splash.on .pulse{opacity:1;animation:bsBreathe 2.4s ease-in-out 4.4s infinite;}
@keyframes bsBreathe{0%,100%{transform:translate(-50%,-50%) scale(0.92);opacity:.5;}14%{transform:translate(-50%,-50%) scale(1.05);opacity:.85;}38%{transform:translate(-50%,-50%) scale(1.1);opacity:.95;}58%{transform:translate(-50%,-50%) scale(0.95);opacity:.55;}}
.bull-splash .mark{position:relative;width:min(66vw,260px);aspect-ratio:1;margin-top:-6vh;}
.bull-splash.on .mark{animation:bsJolt .16s linear 3.1s 2;}
@keyframes bsJolt{0%,100%{transform:translate(0,0);}25%{transform:translate(1.5px,-1px);}50%{transform:translate(-1.5px,1px);}75%{transform:translate(1px,1px);}}
.bull-splash .mark svg{position:absolute;inset:0;width:100%;height:100%;display:block;}
.bull-splash .ring-track{fill:none;stroke:rgba(42,36,25,0.10);stroke-width:3;}
.bull-splash .ring-fill{fill:none;stroke:url(#bsGoldGrad);stroke-width:3;stroke-linecap:round;stroke-dasharray:301.6;transform:rotate(-90deg);transform-origin:50% 50%;transition:stroke-dashoffset 2.7s cubic-bezier(.65,0,.35,1) .4s;}
.bull-splash .shockwave{position:absolute;inset:0;border-radius:50%;border:2px solid #c9962c;opacity:0;pointer-events:none;}
.bull-splash.on .shockwave{animation:bsShock .7s ease-out 2.95s;}
@keyframes bsShock{0%{opacity:0;transform:scale(.96);}18%{opacity:.55;}100%{opacity:0;transform:scale(1.12);}}
.bull-splash .riser,.bull-splash .grow,.bull-splash .beat{position:absolute;inset:0;}
.bull-splash .grow{opacity:0;transform:scale(.88,.94);}
.bull-splash.on .grow{animation:bsEngorge 4.4s forwards;}
@keyframes bsEngorge{0%{opacity:0;transform:scale(.88,.94);}10%{opacity:1;transform:scale(.88,.94);}28%{transform:scale(.90,.945);}34%{transform:scale(.945,.955);}46%{transform:scale(.93,.95);}52%{transform:scale(1.0,.98);}62%{transform:scale(1.05,1.03);}78%{transform:scale(.995,.998);}88%{transform:scale(1,1);}100%{opacity:1;transform:scale(1,1);}}
.bull-splash.on .beat{animation:bsThrob 2.4s ease-in-out 4.4s infinite;}
@keyframes bsThrob{0%,100%{transform:scale(1,1);}14%{transform:scale(1.08,1.045);}26%{transform:scale(1.0,.995);}38%{transform:scale(1.11,1.055);}58%{transform:scale(1,1);}}
.bull-splash .flush-intro{opacity:0;}
.bull-splash.on .flush-intro{animation:bsFlushIntro 4.4s forwards;}
@keyframes bsFlushIntro{0%{opacity:0;}20%{opacity:0;}34%{opacity:.16;}52%{opacity:.28;}68%{opacity:.5;}80%{opacity:.14;}100%{opacity:.12;}}
.bull-splash .flush-beat{opacity:0;}
.bull-splash.on .flush-beat{animation:bsFlushBeat 2.4s ease-in-out 4.4s infinite;}
@keyframes bsFlushBeat{0%,100%{opacity:0;}14%{opacity:.16;}38%{opacity:.22;}58%{opacity:0;}}
.bull-splash .vp{stroke:#ffe9b0;fill:none;stroke-linecap:round;stroke-dasharray:16 84;stroke-dashoffset:116;opacity:0;}
.bull-splash.on .vp{animation:bsTravel .9s linear 2 forwards;}
@keyframes bsTravel{0%{stroke-dashoffset:116;opacity:0;}12%{opacity:.95;}88%{opacity:.95;}100%{stroke-dashoffset:-16;opacity:0;}}
.bull-splash.on .vp.d1{animation-delay:.75s;}
.bull-splash.on .vp.d2{animation-delay:1.0s;}
.bull-splash.on .vp.d3{animation-delay:1.27s;}
.bull-splash.on .vp.d4{animation-delay:1.48s;}
.bull-splash.on .vp.d5{animation-delay:1.66s;}
.bull-splash.on .vp.d6{animation-delay:1.84s;}
.bull-splash.on .vp.d7{animation-delay:1.98s;}
.bull-splash .vc{stroke:#ffe9b0;fill:none;stroke-linecap:round;stroke-dasharray:12 88;stroke-dashoffset:112;opacity:0;}
.bull-splash.on .vc{animation:bsCirculate 2.4s linear infinite;}
@keyframes bsCirculate{0%{stroke-dashoffset:112;opacity:0;}10%{opacity:.32;}90%{opacity:.32;}100%{stroke-dashoffset:-12;opacity:0;}}
.bull-splash.on .vc.c1{animation-delay:4.4s;}
.bull-splash.on .vc.c2{animation-delay:4.85s;}
.bull-splash.on .vc.c3{animation-delay:5.3s;}
.bull-splash .word{margin-top:22px;font-family:'Oswald',sans-serif;text-transform:uppercase;letter-spacing:0.32em;font-size:1.7rem;font-weight:700;color:#2a2419;opacity:0;transform:translateY(8px);transition:opacity 1s ease 3.9s,transform 1s ease 3.9s;}
.bull-splash.on .word{opacity:1;transform:translateY(0);}
.bull-splash .line{font-size:0.72rem;letter-spacing:0.18em;text-transform:uppercase;color:#8a8172;margin-top:8px;opacity:0;transition:opacity 1s ease 4.3s;}
.bull-splash.on .line{opacity:1;}
.bull-splash .stats{display:flex;gap:34px;margin-top:30px;opacity:0;transform:translateY(6px);transition:opacity .9s ease 4.7s,transform .9s ease 4.7s;}
.bull-splash.on .stats{opacity:1;transform:translateY(0);}
.bull-splash .stat{text-align:center;}
.bull-splash .stat .num{font-family:'Oswald',sans-serif;font-weight:700;font-size:1.9rem;color:#a8791f;line-height:1;font-variant-numeric:tabular-nums;}
.bull-splash .stat .lbl{font-size:0.6rem;letter-spacing:0.14em;text-transform:uppercase;color:#8a8172;margin-top:6px;}
.bull-splash .bsdivider{width:1px;background:rgba(42,36,25,0.14);align-self:stretch;}
.bull-splash .hype{position:absolute;bottom:15%;left:0;right:0;text-align:center;padding:0 40px;font-family:'Oswald',sans-serif;text-transform:uppercase;letter-spacing:0.08em;font-size:0.98rem;font-weight:600;color:#5a5140;opacity:0;transition:opacity 1s ease 5.3s;}
.bull-splash.on .hype{opacity:1;}
@media (prefers-reduced-motion: reduce){
  .bull-splash *{animation:none !important;transition:none !important;}
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
/* ---------- arc bend ----------
   Rotates every point of a path about a pivot by an angle proportional to how far
   ABOVE the pivot it sits, so the outline deforms as one connected piece and can
   never split (the old clip-and-rotate is what cracked). Pass refY to rotate a path
   RIGIDLY instead — used for the stem, which otherwise smears into a long streak
   because it sits furthest from the pivot and gets the biggest angle spread. */
const BEND_PIVOT = { x: 50, y: 74 };
const BEND_SPAN = 64;
const _tokCache = {};
function _tokens(d) {
    if (!_tokCache[d])
        _tokCache[d] = d.match(/[MLCZ]|-?\d+\.?\d*/g) || [];
    return _tokCache[d];
}
function bendPath(d, deg, refY, fat) {
    const toks = _tokens(d), out = [];
    const f = fat === undefined ? 1 : fat;
    const rad = (deg * Math.PI) / 180;
    const N = { M: 1, L: 1, C: 3 };
    let i = 0;
    while (i < toks.length) {
        const t = toks[i];
        if (N[t]) {
            out.push(t);
            i++;
            for (let n = 0; n < N[t]; n++) {
                const x0 = parseFloat(toks[i]), y = parseFloat(toks[i + 1]);
                i += 2;
                /* widen about the centreline first — pre-bend the axis is vertical, so
                   this thickens the girth rather than stretching the length */
                const x = BEND_PIVOT.x + (x0 - BEND_PIVOT.x) * f;
                const h = Math.max(0, BEND_PIVOT.y - (refY === undefined ? y : refY));
                const th = rad * (h / BEND_SPAN);
                const dx = x - BEND_PIVOT.x, dy = y - BEND_PIVOT.y;
                const c = Math.cos(th), s = Math.sin(th);
                out.push((BEND_PIVOT.x + dx * c - dy * s).toFixed(2) + " " + (BEND_PIVOT.y + dx * s + dy * c).toFixed(2));
            }
        }
        else if (t === "Z") { out.push("Z"); i++; }
        else i++;
    }
    return out.join(" ");
}
/* Rest angle is deliberately non-zero: erect isn't a straight rod, so the final
   state keeps a slight curve and throbs around it rather than snapping to 0. */
const BEND_LIMP = 142;
/* negative = anticlockwise: the resting curve leans back toward the body, not forward */
const BEND_REST = -13;
const BEND_THROB = 5;
/* fully limp is this much thicker across the girth, tapering off as it fills */
const BEND_FAT = 0.24;
const STEM_REF_Y = 26;
const FRUIT_BODY_D = "M46 24 C40 30, 38 40, 39 50 C40 60, 34 64, 33 72 C32 82, 40 89, 50 90 C60 89, 68 82, 67 72 C66 63, 61 59, 60 50 C59 40, 58 30, 54 24 C51 22, 48 22, 46 24 Z";
function SplashFruit({ sfx, reg }) {
    return (React.createElement("svg", { viewBox: "0 0 100 100" },
                                React.createElement("defs", null,
                                    React.createElement("linearGradient", { id: "bsGoldGradF" + sfx, x1: "0%", y1: "0%", x2: "100%", y2: "100%" },
                                        React.createElement("stop", { offset: "0%", stopColor: "#f5cf7e" }),
                                        React.createElement("stop", { offset: "100%", stopColor: "#c8912e" })),
                                    /* veins are clipped to the body: a vessel sits under the surface,
                                       it doesn't leave the shape and stop in mid-air */
                                    React.createElement("clipPath", { id: "bsBodyClip" + sfx },
                                        React.createElement("path", { ref: (e) => reg(e, FRUIT_BODY_D), d: FRUIT_BODY_D }))),
                                React.createElement("g", { transform: "translate(50 54) scale(0.50) translate(-49.54 -53.5)" },
                                    React.createElement("path", { ref: (e) => reg(e, FRUIT_BODY_D), fill: `url(#bsGoldGradF${sfx})`, d: FRUIT_BODY_D }),
                                    React.createElement("path", { ref: (e) => reg(e, FRUIT_BODY_D), className: "flush-intro", fill: "#f5cf7e", d: FRUIT_BODY_D }),
                                    React.createElement("path", { ref: (e) => reg(e, FRUIT_BODY_D), className: "flush-beat", fill: "#f5cf7e", d: FRUIT_BODY_D }),
                                    React.createElement("path", { ref: (e) => reg(e, "M36 26 L42 16 L47 22 L50 10 L54 21 L61 17 L58 27 C52 31, 43 31, 36 26 Z", STEM_REF_Y), fill: "#8a6218", d: "M36 26 L42 16 L47 22 L50 10 L54 21 L61 17 L58 27 C52 31, 43 31, 36 26 Z" }),
                                    React.createElement("path", { ref: (e) => reg(e, "M49 12 C49 8, 51 5, 54 3 L57 6 C54 8, 53 11, 53 14 Z", STEM_REF_Y), fill: "#8a6218", d: "M49 12 C49 8, 51 5, 54 3 L57 6 C54 8, 53 11, 53 14 Z" }),
                                    React.createElement("g", { clipPath: `url(#bsBodyClip${sfx})` },
                                    React.createElement("g", { fill: "none", strokeLinecap: "round" },
                                        React.createElement("path", { ref: (e) => reg(e, "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26", undefined, true), stroke: "#8a6218", strokeWidth: "3.8", opacity: "0.9", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26", undefined, true), stroke: "#f5cf7e", strokeWidth: "1.2", opacity: "0.35", transform: "translate(-0.5,-0.5)", d: "M48 86 C43 78, 44 68, 47 60 C50 52, 44 46, 44 38 C44 33, 46 29, 48 26" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M47 59 C52 56, 56 52, 58 46", undefined, true), stroke: "#8a6218", strokeWidth: "2.6", opacity: "0.9", d: "M47 59 C52 56, 56 52, 58 46" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M58 46 C60 43, 60 39, 59 36", undefined, true), stroke: "#8a6218", strokeWidth: "1.7", opacity: "0.85", d: "M58 46 C60 43, 60 39, 59 36" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M47 70 C53 68, 58 65, 62 60", undefined, true), stroke: "#8a6218", strokeWidth: "2.6", opacity: "0.9", d: "M47 70 C53 68, 58 65, 62 60" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28", undefined, true), stroke: "#8a6218", strokeWidth: "3.2", opacity: "0.9", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28", undefined, true), stroke: "#f5cf7e", strokeWidth: "1.1", opacity: "0.3", transform: "translate(-0.5,-0.5)", d: "M58 84 C63 77, 65 69, 63 61 C61 54, 58 49, 58 42 C58 37, 59 32, 61 28" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M63 62 C66 58, 67 54, 66 50", undefined, true), stroke: "#8a6218", strokeWidth: "1.9", opacity: "0.85", d: "M63 62 C66 58, 67 54, 66 50" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38", undefined, true), stroke: "#8a6218", strokeWidth: "2.2", opacity: "0.9", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" }),
                                        React.createElement("path", { ref: (e) => reg(e, "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38", undefined, true), stroke: "#f5cf7e", strokeWidth: "0.9", opacity: "0.3", transform: "translate(-0.5,-0.5)", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" })),
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
                                        React.createElement("path", { className: "vc c3", pathLength: "100", strokeWidth: "2.2", d: "M39 74 C37 66, 37 57, 40 50 C41 46, 40 42, 39 38" }))),
                                    React.createElement("ellipse", { cx: 60, cy: 66, rx: 3.2, ry: 6.5, fill: "#f7e2ae", opacity: 0.9, transform: "rotate(18 60 66)" }),
                                    React.createElement("ellipse", { cx: 43, cy: 44, rx: 1.6, ry: 3.8, fill: "#f7e2ae", opacity: 0.25, transform: "rotate(-10 43 44)" }))));
}
function Splash({ vigour, risk, cleanPct, streak, onDone }) {
    const [on, setOn] = useState(false);
    const [exiting, setExiting] = useState(false);
    const exitRef = useRef(false);
    /* The outline is bent per frame directly on the DOM nodes rather than through
       React state — re-rendering the whole splash at 60fps to move a path would be
       wasteful and janky. */
    const partsRef = useRef([]);
    const reg = (el, d, refY, isVein) => {
        if (el && !partsRef.current.some((p) => p.el === el))
            partsRef.current.push({ el, d, refY, isVein });
    };
    useEffect(() => {
        let raf = 0;
        const t0 = performance.now();
        const RISE = 4400;
        const ease = (p) => 1 - Math.pow(1 - p, 3);
        const tick = (now) => {
            const dt = now - t0;
            const deg = dt < RISE
                ? BEND_LIMP + (BEND_REST - BEND_LIMP) * ease(dt / RISE)
                /* settled: each beat pulls it briefly straighter, in step with the heartbeat */
                : BEND_REST + BEND_THROB * 0.5 * (1 - Math.cos(((dt - RISE) / 2400) * Math.PI * 2));
            const erect = Math.max(0, Math.min(1, (BEND_LIMP - deg) / (BEND_LIMP - BEND_REST)));
            const fat = 1 + BEND_FAT * (1 - erect);
            partsRef.current.forEach((p) => {
                p.el.setAttribute("d", bendPath(p.d, deg, p.refY, fat));
                /* veins barely read when limp, swelling in as blood arrives */
                if (p.isVein)
                    p.el.style.opacity = String(0.05 + 0.85 * erect * erect);
            });
            raf = requestAnimationFrame(tick);
        };
        raf = requestAnimationFrame(tick);
        return () => cancelAnimationFrame(raf);
    }, []);
    const finish = () => {
        if (exitRef.current)
            return;
        exitRef.current = true;
        setExiting(true);
        setTimeout(onDone, 480);
    };
    const [hype] = useState(() => SPLASH_LINES[Math.floor(Math.random() * SPLASH_LINES.length)]);
    const [vigDisp, setVigDisp] = useState(0);
    const [riskDisp, setRiskDisp] = useState(0);
    const [cleanDisp, setCleanDisp] = useState(0);
    useEffect(() => {
        const raf1 = requestAnimationFrame(() => requestAnimationFrame(() => setOn(true)));
        const countStart = setTimeout(() => {
            const dur = 1900, t0 = performance.now();
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
        }, 4700);
        const done = setTimeout(finish, 7000);
        return () => { cancelAnimationFrame(raf1); clearTimeout(countStart); clearTimeout(done); };
    }, []);
    const c = 2 * Math.PI * 48;
    const offset = c - (Math.max(0, Math.min(100, vigour)) / 100) * c;
    return (React.createElement("div", { className: "fixed inset-0 z-[70]", style: { background: "#faf6ef", opacity: exiting ? 0 : 1, transform: exiting ? "scale(1.04)" : "scale(1)", transition: "opacity 0.48s ease, transform 0.48s ease" }, onClick: finish },
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
                            React.createElement(SplashFruit, { sfx: "a", reg: reg }))))),
            React.createElement("div", { className: "word" }, "Bull"),
            React.createElement("div", { className: "stats" },
                React.createElement("div", { className: "stat" }, React.createElement("div", { className: "num" }, vigDisp), React.createElement("div", { className: "lbl" }, "Vigour \u00B7 30d")),
                React.createElement("div", { className: "bsdivider" }),
                React.createElement("div", { className: "stat" }, React.createElement("div", { className: "num" }, riskDisp), React.createElement("div", { className: "lbl" }, "Risk \u00B7 30d")),
                React.createElement("div", { className: "bsdivider" }),
                React.createElement("div", { className: "stat" }, React.createElement("div", { className: "num" }, cleanDisp), React.createElement("div", { className: "lbl" }, "Clean \u00B7 30d"))),
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
    return (React.createElement("div", { className: "fixed inset-0 z-50 flex flex-col items-center justify-between p-6 overflow-y-auto", style: { background: "#faf6ef" } },
        React.createElement("div", { className: "w-full max-w-md pt-4" },
            React.createElement("div", { className: "text-xs uppercase tracking-widest font-bold mb-3", style: { color: TEAL } }, "Win Logged \u2014 Urge Survived"),
            React.createElement("p", { className: "font-serif text-[#332d20] text-lg leading-relaxed whitespace-pre-line" }, purposeText)),
        !started ? (React.createElement("button", { onClick: () => setStarted(true), className: "my-10 px-8 py-4 rounded-2xl font-bold text-lg text-neutral-950", style: { background: TEAL } }, "BEGIN 3-MINUTE RESET")) : (React.createElement("div", { className: "flex flex-col items-center my-8" },
            React.createElement("div", { className: "relative w-52 h-52 flex items-center justify-center" },
                React.createElement("div", { className: "absolute inset-0 rounded-full border border-[rgba(42,36,25,0.10)]" }),
                React.createElement("div", { className: "w-36 h-36 rounded-full opacity-20", style: { background: TEAL, transform: `scale(${scale})`, transition: `transform ${dur} ease-in-out` } }),
                React.createElement("div", { className: "absolute w-36 h-36 rounded-full border-2", style: { borderColor: TEAL, transform: `scale(${scale})`, transition: `transform ${dur} ease-in-out` } })),
            React.createElement("div", { className: "text-[#332d20] mt-6 text-sm uppercase tracking-wide font-semibold" }, doneAll ? "Steady — The Wave Passed" : phase),
            React.createElement("div", { className: "font-mono text-[#8a8172] mt-1 text-sm" }, doneAll ? "0:00" : `${mm}:${ss}`))),
        React.createElement("div", { className: "w-full max-w-md pb-4" },
            React.createElement("button", { onClick: onClose, className: "w-full py-3.5 rounded-2xl font-bold uppercase tracking-wide " + (doneAll ? "text-neutral-950" : "bg-[rgba(42,36,25,0.06)] text-[#6f6757]"), style: doneAll ? { background: TEAL } : undefined }, doneAll ? "Return, Stronger" : started ? "I'm Steady — Return Early" : "Close"))));
}
/* ---------- guide ---------- */
const GUIDE = [
    { g: "In The Moment", items: [
            { t: "The Urge Protocol", ev: "strong", lead: "Urges peak and fall within minutes if they aren't fed. The tap itself is the win.",
                rows: [["Do", "Tap Urge the moment it hits. Purpose card, then three minutes of physiological sighs."], ["Then", "If it's still loud, change environment — leave the room, leave the house."], ["Why", "Riding out an urge without acting weakens the loop each time. Acting on it strengthens it."]] },
            { t: "Physiological Sigh", ev: "strong", lead: "The fastest evidenced way to drop arousal in real time.",
                rows: [["Do", "Two nasal inhales \u2014 one full, one short sip on top \u2014 then a long slow mouth exhale, roughly twice the inhale."], ["Why", "The double inhale reopens collapsed alveoli and offloads CO2 fast. Exhales longer than inhales shift you toward parasympathetic tone."], ["Reps", "Three minutes is enough. Longer isn't better."]] },
            { t: "After A Slip", ev: "strong", lead: "The slip doesn't cause the binge. The thought \u201calready ruined\u201d does.",
                rows: [["Why", "The abstinence violation effect is one of the best-replicated findings in relapse research \u2014 the spiral comes from the interpretation, not the act."], ["Do", "Log it honestly. Water, shower, get outside, tell your accountability partner."], ["Avoid", "Recalculating the damage. One data point barely moves the percentage."]] },
        ] },
    { g: "Prevention", items: [
            { t: "Content Access", ev: "strong", lead: "The strongest lever here, and the least ambiguous.",
                rows: [["Why", "Opportunity predicts behaviour better than motivation does."], ["Logged", "Low / Medium / High rather than yes-no \u2014 access is a gradient. A filtered phone is not the same as an unfiltered one on the sofa at midnight."], ["Do", "Reduce access before you need willpower, not while you need it."]] },
            { t: "Checking Out Women", ev: "moderate", lead: "Repeated deliberate looking keeps the arousal loop primed through the day.",
                rows: [["Why", "The loop doesn't settle if it's topped up hourly."], ["Logged", "An honest count, not a moral score. Its value is what Patterns does with it."]] },
            { t: "Home Alone, Unstructured Time", ev: "moderate", lead: "Situational, not moral \u2014 the most commonly reported precondition for relapse.",
                rows: [["Why", "Across self-report studies, unstructured solitude precedes relapse more often than any mood state."], ["Do", "Log it so Patterns can test whether it's true for you specifically rather than assuming it."]] },
            { t: "Junk Food", ev: "moderate", lead: "Scores on both lists, for two different reasons.",
                rows: [["Prevention", "Blood-sugar swings degrade impulse control \u2014 that's the mechanism that matters for relapse."], ["Vigour", "Diet quality tracks erectile function in large cohorts; Mediterranean-pattern eating is associated with better scores, largely via endothelial health."], ["Weight", "Lighter on the Vigour side \u2014 a weaker lever there than training or sleep."]] },
            { t: "Cold Plunge", ev: "weak", lead: "Real benefits, but not the hormonal one it's usually sold on.",
                rows: [["Not true", "Cold exposure does not raise testosterone. That claim isn't supported."], ["Does work", "A large sustained noradrenaline rise \u2014 mood and alertness lift for hours."], ["Also", "A genuine voluntary-discomfort rep, which is its own reason to keep it."]] },
            { t: "Nasal Rinse", ev: "moderate", lead: "Scores on both. Airway on one side, nitric oxide on the other.",
                rows: [["Prevention", "A clear airway means better sleep, and poor sleep is one of your strongest vulnerability drivers."], ["Vigour", "The paranasal sinuses are the body's main nitric oxide reservoir; nasal breathing draws it into the airway."], ["Safety", "Never rinse with untreated tap water."]] },
            { t: "Morning Intention", ev: "strong", lead: "One concrete purposeful thing, set before the day starts.",
                rows: [["Why", "Implementation intentions \u2014 deciding in advance what you'll do and when \u2014 are among the most replicated behaviour-change findings there are."], ["Do", "Be specific. The specificity does the work, not the sentiment."]] },
            { t: "Evening Review \u2014 Purpose", ev: "moderate", lead: "Rated 1\u20135, and it moves the score in both directions.",
                rows: [["Why", "Meaninglessness and boredom are consistently reported antecedents to compulsive use."], ["Scoring", "Low-purpose days raise Risk; high-purpose days lower it."], ["Do", "Rate it fast. A considered rating is usually a rationalised one."]] },
            { t: "Accountability Check-In", ev: "strong", lead: "Booked and dated, not vague.",
                rows: [["Why", "Accountability decays with distance."], ["Scoring", "Risk rises when nothing is booked, when a check-in is overdue, or when the next is beyond your chosen window."], ["Set", "Frequency is configurable in Settings."]] },
            { t: "Urges Survived", ev: "strong", lead: "The only item that rewards difficulty.",
                rows: [["Scoring", "Each logged urge you ride out lowers Risk, up to a daily cap."], ["Why", "A day with three survived urges is a stronger day than one with none, and the score is built to say so."]] },
            { t: "Recovery Below 40%", ev: "moderate", lead: "Automatic, from your Recovery Score \u2014 no judgement required from you.",
                rows: [["Why", "Low recovery means depleted self-regulation \u2014 the same resource that declines urges."], ["Note", "The input most worth automating, because it needs only data."]] },
            { t: "Sick / Travelling Flags", ev: "moderate", lead: "Two independent day flags that count as risk in their own right.",
                rows: [["Why", "Disrupted routine and unfamiliar environments are real triggers, not excuses."], ["Fairness", "Items you mark Excused sit out flagged days, so you aren't penalised twice for one disruption."]] },
        ] },
    { g: "Vigour \u00B7 Testosterone", items: [
            { t: "Sleep", ev: "strong", lead: "The highest-yield item in this bucket by a wide margin.",
                rows: [["Why", "The large majority of daily testosterone release happens during sleep, and it tracks total sleep time closely."], ["Evidence", "Restricting healthy young men to five hours a night for one week has been shown to cut daytime testosterone by 10\u201315%."], ["Note", "Nothing else in this list moves the number that much."]] },
            { t: "Strength Training", ev: "moderate", lead: "Weighted high \u2014 but not for the reason it's usually sold on.",
                rows: [["Oversold", "The acute post-session testosterone spike is real but its effect on resting baseline in healthy men is modest."], ["Real wins", "Body composition, insulin sensitivity, and androgen-receptor density."], ["Do", "Compound, heavy, progressive."]] },
            { t: "Fasting", ev: "weak", lead: "Keep it \u2014 but not on hormonal grounds.",
                rows: [["Not true", "The testosterone case is weak. Some time-restricted-eating trials show total testosterone falling, not rising."], ["Does work", "Insulin sensitivity, plus a repeatable voluntary-discomfort rep with strong personal meaning."], ["Schedule", "Mondays, Thursdays and the 13th\u201315th lunar days \u2014 auto-flagged, and configurable in Settings."]] },
            { t: "Supplements", ev: "weak", lead: "Grouped here, but scored as one lump rather than per-item.",
                rows: [["Note", "Evidence varies sharply by compound. Zinc and vitamin D matter mainly if you're deficient \u2014 correcting a deficiency helps, exceeding normal doesn't."], ["Do", "Treat as a minor lever. Nothing here competes with sleep or training."]] },
        ] },
    { g: "Vigour \u00B7 Heart Health", items: [
            { t: "Cardio / Boxing", ev: "strong", lead: "The best-evidenced item in the whole app for erectile function.",
                rows: [["Why", "Erectile tissue depends on endothelial health, and aerobic exercise improves endothelial function directly."], ["Evidence", "Meta-analyses of aerobic training show clinically meaningful improvement in erectile scores, with the largest gains in men who start out worst."], ["Bigger picture", "Erectile difficulty is often the earliest visible sign of vascular disease. That's why this bucket exists."]] },
            { t: "Junk Food (avoided)", ev: "moderate", lead: "Counted here too \u2014 endothelium is the shared mechanism.",
                rows: [["Why", "The dietary pattern that predicts cardiovascular risk predicts erectile scores."], ["Weight", "Lighter than training: slower and less specific."]] },
            { t: "Cold Plunge", ev: "weak", lead: "Counted here for the acute response, not a lasting adaptation.",
                rows: [["Why", "Circulatory and mood effects on the day."], ["Weight", "Low deliberately \u2014 the evidence supports how it makes you feel and function that day, not cardiovascular remodelling."]] },
        ] },
    { g: "Vigour \u00B7 Nitric Oxide", items: [
            { t: "Why This Bucket Exists", ev: "strong", lead: "Nitric oxide is the actual signalling molecule behind an erection.",
                rows: [["Mechanism", "It relaxes smooth muscle in the penile arteries and lets blood in. This is the pathway PDE5 inhibitors act on."], ["So", "Everything in this bucket is about producing more of it, or losing less of it."]] },
            { t: "Breathwork Before Isha", ev: "moderate", lead: "Five minutes diaphragmatic, anchored to a fixed daily point.",
                rows: [["Do", "Hand on the belly, nasal inhale so the belly rises, exhale longer than the inhale."], ["Why", "Slow breathing at roughly six breaths per minute raises heart-rate variability and shifts autonomic balance toward parasympathetic \u2014 the state erections require."], ["Timing", "Isha is fixed and lands near bedtime, ahead of your most vulnerable window."]] },
            { t: "Nasal Breathing", ev: "strong", lead: "The mechanism the whole bucket rests on.",
                rows: [["Why", "Nitric oxide is produced continuously in the paranasal sinuses and drawn into the lungs on every nasal inhale, where it improves oxygen uptake."], ["Cost of not", "Mouth breathing bypasses that supply entirely."], ["Note", "Well-established physiology \u2014 unlike a lot of what gets claimed downstream of it."]] },
        ] },
    { g: "Vigour \u00B7 Pelvic Floor", items: [
            { t: "Kegels", ev: "strong", lead: "The best-supported non-drug intervention for erectile and ejaculatory control.",
                rows: [["Evidence", "Trial evidence shows pelvic floor training improving erectile rigidity comparably to some first-line approaches."], ["Find it", "The muscle that stops urine mid-flow. Locate it once \u2014 don't make that the exercise."], ["Do", "10 slow reps: squeeze 3\u20135s, relax equally long. Build toward 10-second holds. Then 10 fast one-second flutters."], ["Avoid", "Training to fatigue."]] },
            { t: "Pelvic Floor Stretches", ev: "moderate", lead: "The other half, and the half people skip.",
                rows: [["Why", "A chronically tight floor produces the same symptoms as a weak one. Release isn't optional recovery work \u2014 it's half the training."], ["Do", "5\u201310 minutes: happy baby, deep squat, child's pose, butterfly. Nasal breathing, letting the floor soften on each exhale."], ["Also", "Reverse kegels \u2014 gentle bearing-down release on a slow exhale, matching your squeeze reps."]] },
        ] },
    { g: "How Scoring Works", items: [
            { t: "Relapse Risk", ev: null, lead: "Lower is safer.",
                rows: [["Rises with", "Active risk factors."], ["Falls with", "Protective habits and survived urges."], ["Override", "A logged relapse floors the day at high risk regardless of everything else. The day is what it is."]] },
            { t: "Sexual Vigour", ev: null, lead: "Weighted completion of what was actually scheduled that day.",
                rows: [["Scoring", "Expressed as a percentage of what was available to earn."], ["Fairness", "Items not scheduled today aren't counted against you, so an off day doesn't drag the score."]] },
            { t: "Items That Score On Both", ev: null, lead: "Some things genuinely affect both scores.",
                rows: [["Which", "Junk food, cold plunge, nasal rinse."], ["How", "Two independent weights \u2014 one for Prevention, one for Vigour."], ["Risk-type", "Earns Vigour by being avoided, raises Risk by happening, each at its own weight."]] },
            { t: "Weights", ev: null, lead: "Every item is Low / Med / High / V.High on each side it scores.",
                rows: [["Note", "Defaults are a starting point, not a recommendation."], ["Do", "Tune them against what Patterns actually shows for you, not what should be true in theory."]] },
            { t: "Patterns", ev: null, lead: "A hypothesis generator, not a verdict.",
                rows: [["How", "Compares how often each factor appears on relapse days against how often it appears on all days."], ["Limits", "Association, not causation \u2014 and correlations from a handful of events are noise."], ["Do", "Wait for volume before acting on anything it surfaces."]] },
        ] },
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
    const [healthImported, setHealthImported] = useState(null);
    const [showMonth, setShowMonth] = useState(false);
    const [addForm, setAddForm] = useState({ label: "", list: "prev", kind: "risk", weight: "med", vigourWeight: "low", bucket: "test", daily: true, days: [] });
    const saveTimer = useRef(null);
    useEffect(() => {
        (async () => {
            let loaded = migrate(await storageGet());
            if (!loaded)
                loaded = {
                    version: 6, settings: { ...DEFAULT_SETTINGS },
                    items: DEFAULT_ITEMS.map((i) => ({ ...i, freq: Array.isArray(i.freq) ? [...i.freq] : i.freq })),
                    days: {}, urges: [], relapses: [], wetDreams: [], firstUse: Date.now(),
                };
            /* Apple Health handoff: Shortcuts opens Bull with ?hrv=..&recovery=..&sleep=.. */
            const incoming = readHealthParams();
            if (incoming) {
                const k = incoming.dateKey || todayKey();
                loaded = { ...loaded, days: { ...loaded.days, [k]: { ...emptyDay(), ...(loaded.days[k] || {}), ...incoming.values } } };
                setHealthImported(Object.keys(incoming.values));
                storageSet(loaded);
                try { window.history.replaceState({}, "", window.location.pathname); } catch (e) { }
            }
            setData(loaded);
        })();
    }, []);
    const persist = (next) => {
        setData(next);
        if (saveTimer.current)
            clearTimeout(saveTimer.current);
        saveTimer.current = setTimeout(() => storageSet(next), 500);
    };
    if (!data) {
        return (React.createElement("div", { className: "min-h-screen flex items-center justify-center", style: { background: "#faf6ef" } },
            React.createElement("div", { className: "text-[#8a8172] text-sm uppercase tracking-widest" }, "Loading")));
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
    const existingRelapseIdx = data.relapses.findIndex((r) => dateKey(new Date(r.ts)) === vk);
    const existingRelapse = existingRelapseIdx !== -1 ? data.relapses[existingRelapseIdx] : null;
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
    const lastRelapse = loggedRelapse || null;
    const streak = Math.max(0, Math.floor((Date.now() - (lastRelapse || data.firstUse)) / DAY_MS));
    const windowDays = Math.min(90, Math.max(1, Math.floor((Date.now() - data.firstUse) / DAY_MS) + 1));
    const relDaySet = new Set(data.relapses.filter((r) => r.ts >= Date.now() - windowDays * DAY_MS).map((r) => dateKey(new Date(r.ts))));
    const cleanPct = Math.round((100 * (windowDays - relDaySet.size)) / windowDays);
    /* ---------- ambient mood: driven by 30-day rolling averages, flagged days excluded ---------- */
    const ambient = (() => {
        const from = Date.now() - 30 * DAY_MS;
        const relKeySet = new Set(data.relapses.map((r) => dateKey(new Date(r.ts))));
        const isFlagged = (k) => { const d = data.days[k]; return d && (d.sick === true || d.travelling === true); };
        let rSum = 0, rN = 0, hd = 0, ht = 0;
        Object.keys(data.days).forEach((k) => {
            const t = new Date(k + "T12:00:00");
            if (t.getTime() < from)
                return;
            if (riskLogged(data.days[k], items)) {
                const uc = data.urges.filter((u) => dateKey(new Date(u.ts)) === k).length;
                rSum += riskScore({ ...emptyDay(), ...data.days[k] }, items, uc, relKeySet.has(k));
                rN++;
            }
            if (!isFlagged(k)) {
                const r = vigourForDay({ ...emptyDay(), ...data.days[k] }, t, items, data.settings);
                hd += r.done;
                ht += r.total;
            }
        });
        const vigAvg = ht ? (hd / ht) : 0.6;
        const protAvg = rN ? 1 - (rSum / rN) / 100 : 0.85;
        const vt = Number.isFinite(vigAvg) ? Math.max(0, Math.min(1, vigAvg)) : 0.6;
        const dgr = Number.isFinite(protAvg) ? Math.pow(Math.max(0, Math.min(1, 1 - protAvg)), 1.35) : 0.15;
        return {
            vt, dgr, tense: protAvg <= 0.33,
            accent: mixHex("#a9946a", "#c9962c", Math.min(1, vt * 1.25)),
            vars: {
                "--vig": vt.toFixed(3),
                "--accent": mixHex("#a9946a", "#c9962c", Math.min(1, vt * 1.25)),
                "--energyOp": (0.12 + 0.5 * vt).toFixed(3),
                "--energyCol": `rgba(214,164,52,${(0.12 + 0.22 * vt).toFixed(3)})`,
                "--breatheA": (0.015 + 0.06 * vt).toFixed(3),
                "--dgrOp": (dgr * 0.30).toFixed(3),
                "--dgrLine": (dgr * 0.9).toFixed(3),
                "--bg": mixHex(mixHex("#faf6ef", "#f7eed6", vt), "#f4e3e0", dgr * 0.75),
                "--ink": mixHex("#2a2419", "#3a1e1c", dgr * 0.6),
            },
        };
    })();
    /* splash shows 30-day averages, not today's live numbers — one bad morning shouldn't
       define the number you're greeted with. Flagged days excluded, same as the ambient mood. */
    const splashAvgs = (() => {
        const from = Date.now() - 30 * DAY_MS;
        const relKeys = new Set(data.relapses.map((r) => dateKey(new Date(r.ts))));
        const flagged = (k) => { const d = data.days[k]; return d && (d.sick === true || d.travelling === true); };
        let rSum = 0, rN = 0, hd = 0, ht = 0;
        Object.keys(data.days).forEach((k) => {
            const t = new Date(k + "T12:00:00");
            if (t.getTime() < from)
                return;
            if (riskLogged(data.days[k], items)) {
                const uc = data.urges.filter((u) => dateKey(new Date(u.ts)) === k).length;
                rSum += riskScore({ ...emptyDay(), ...data.days[k] }, items, uc, relKeys.has(k));
                rN++;
            }
            if (!flagged(k)) {
                const v = vigourForDay({ ...emptyDay(), ...data.days[k] }, t, items, data.settings);
                hd += v.done;
                ht += v.total;
            }
        });
        const spanDays = Math.min(30, Math.max(1, Math.floor((Date.now() - data.firstUse) / DAY_MS) + 1));
        const relIn30 = new Set(data.relapses.filter((r) => r.ts >= from).map((r) => dateKey(new Date(r.ts))));
        return {
            vigour: ht ? Math.round((hd / ht) * 100) : Math.round(vigourPct),
            risk: rN ? Math.round(rSum / rN) : Math.round(risk),
            clean: Math.round((100 * (spanDays - relIn30.size)) / spanDays),
        };
    })();
    const logUrge = () => { persist({ ...data, urges: [...data.urges, { ts: Date.now() }] }); setBreathing(true); };
    const logRelapse = (type) => {
        const ts = isToday ? Date.now() : new Date(vk + "T12:00:00").getTime();
        persist({ ...data, relapses: [...data.relapses, { ts, type: type || "orgasm" }] });
        setConfirmRelapse(false);
        if (isToday)
            setJustRelapsed(true);
    };
    const editRelapseType = (type) => {
        if (existingRelapseIdx === -1)
            return;
        const next = [...data.relapses];
        next[existingRelapseIdx] = { ...next[existingRelapseIdx], type };
        persist({ ...data, relapses: next });
    };
    const removeRelapse = () => {
        if (existingRelapseIdx === -1)
            return;
        persist({ ...data, relapses: data.relapses.filter((_, i) => i !== existingRelapseIdx) });
    };
    const logWetDream = () => {
        persist({ ...data, wetDreams: [...(data.wetDreams || []), { ts: Date.now() }] });
        setConfirmWetDream(false);
    };
    const now = new Date(Date.now() + viewOffset * DAY_MS);
    const prevRisks = items.filter((i) => isPrev(i) && i.kind === "risk" && scheduledOn(i, now)).sort(byWeightDesc);
    const prevHabits = items.filter((i) => isPrev(i) && i.kind === "habit" && scheduledOn(i, now)).sort(byWeightDesc);
    const fastToday = fastingSuggested(now, data.settings.fastMode);
    const primeToday = items.filter((i) => isPrime(i) && (i.kind === "habit" || i.kind === "risk") && (i.fastingAuto ? fastToday : scheduledOn(i, now))).sort(byWeightDesc);
    const primeByBucket = BUCKETS.map((b) => ({ ...b, items: primeToday.filter((i) => (i.bucket || "test") === b.id) })).filter((b) => b.items.length);
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
            return t >= from && riskLogged(data.days[k], items);
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
            orgasms: data.relapses.filter((r) => r.ts >= from && (r.type || "orgasm") === "orgasm").length,
            edges: data.relapses.filter((r) => r.ts >= from && r.type === "edge").length,
            wetDreams: (data.wetDreams || []).filter((w) => w.ts >= from).length,
        };
    };
    const bestStreak = (() => {
        const relapseTs = data.relapses.map((r) => r.ts);
        const pts = [data.firstUse, ...relapseTs.sort((a, b) => a - b), Date.now()];
        let best = 0;
        for (let i = 1; i < pts.length; i++)
            best = Math.max(best, Math.floor((pts[i] - pts[i - 1]) / DAY_MS));
        return best;
    })();
    const CORRELATION_FACTORS = [
        ...items.filter((i) => isPrev(i) && i.kind === "risk").map((i) => ({ label: i.label, test: (d) => d.checks && d.checks[i.id] === true })),
        ...items.filter((i) => isPrev(i) && i.kind === "habit").map((i) => ({ label: "Skipped: " + i.label, test: (d) => !(d.checks && d.checks[i.id] === true) })),
        items.some((i) => i.id === "contentAccess") && { label: "Med/High Content Access", test: (d) => d.access === "med" || d.access === "high" },
        items.some((i) => i.id === "checkout") && { label: "Heavy Visual Triggers", test: (d) => d.checkout === "lot" },
        { label: "Recovery Below 40%", test: (d) => d.recovery !== null && d.recovery !== undefined && d.recovery !== "" && Number(d.recovery) < 40 },
        { label: "Low-Purpose Day (1–2)", test: (d) => d.purposeRating !== null && d.purposeRating !== undefined && d.purposeRating <= 2 },
        { label: "HRV 10%+ Below Baseline", test: (d, ctx) => d.hrv !== null && d.hrv !== undefined && d.hrv !== "" && ctx && ctx.hrvBaseline && Number(d.hrv) < ctx.hrvBaseline * 0.9 },
        { label: "Flagged Sick", test: (d) => d.sick === true },
        { label: "Flagged Travelling", test: (d) => d.travelling === true },
    ].filter(Boolean);
    const hrvBaseline = (() => {
        const vals = Object.keys(data.days).map((k) => data.days[k] && data.days[k].hrv).filter((x) => x !== null && x !== undefined && x !== "" && !isNaN(Number(x))).map(Number);
        return vals.length >= 7 ? vals.reduce((a, b) => a + b, 0) / vals.length : null;
    })();
    const corrCtx = { hrvBaseline };
    const correlationsFor = (eventTimestamps) => {
        const eventKeys = [...new Set(eventTimestamps.map((ts) => dateKey(new Date(ts))))].filter((k) => data.days[k]);
        const allKeys = Object.keys(data.days).filter((k) => riskLogged(data.days[k], items));
        if (!eventKeys.length || !allKeys.length)
            return null;
        return CORRELATION_FACTORS.map((f) => {
            const rel = eventKeys.filter((k) => f.test({ ...emptyDay(), ...data.days[k] }, corrCtx)).length / eventKeys.length;
            const base = allKeys.filter((k) => f.test({ ...emptyDay(), ...data.days[k] }, corrCtx)).length / allKeys.length;
            return { label: f.label, rel: Math.round(rel * 100), base: Math.round(base * 100) };
        }).filter((x) => x.rel > 0).sort((a, b) => (b.rel - b.base) - (a.rel - a.base)).slice(0, 5);
    };
    const correlations = data.relapses.length < 3 ? null : correlationsFor(data.relapses.map((r) => r.ts));
    const wetDreamCorrelations = (data.wetDreams || []).length < 3 ? null : correlationsFor(data.wetDreams.map((w) => w.ts));
    const edgeEvents = data.relapses.filter((r) => r.type === "edge");
    const edgeCorrelations = edgeEvents.length < 3 ? null : correlationsFor(edgeEvents.map((r) => r.ts));
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
        persist({ ...data, items: [...items, { id, label, list: addForm.list, kind: addForm.list === "prime" ? "habit" : addForm.kind, weight: addForm.weight, vigourWeight: addForm.list === "both" ? addForm.vigourWeight : undefined, bucket: addForm.list !== "prev" ? addForm.bucket : undefined, freq }] });
        setAddForm({ label: "", list: "prev", kind: "risk", weight: "med", vigourWeight: "low", bucket: "test", daily: true, days: [] });
        setShowAdd(false);
    };
    const freqSummary = (item) => item.fastingAuto ? ("AUTO (" + (data.settings.fastMode === "lunar" ? "LUNAR ONLY" : data.settings.fastMode === "weekly" ? "MON/THU ONLY" : "MON/THU + LUNAR") + ")") :
        item.freq === "daily" ? "DAILY" :
            Array.isArray(item.freq) && item.freq.length ? item.freq.map((d) => WD[d]).join(" ") : "DAILY";
    const NavBtn = ({ id, icon: Icon, label }) => (React.createElement("button", { onClick: () => setView(id), className: "flex-1 flex flex-col items-center gap-0.5 py-2 " + (view === id ? "" : "text-[#8a8172]"), style: view === id ? { color: TEAL } : undefined },
        React.createElement(Icon, { size: 20 }),
        React.createElement("span", { className: "text-[10px] uppercase tracking-wide font-semibold" }, label)));
    const ItemEditorRow = ({ item, side }) => {
        const dual = item.list === "both";
        const kindLabel = dual ? "BOTH"
            : item.kind === "tier" ? "TIERED"
                : item.kind === "derived" ? "AUTO"
                    : item.list === "prime" ? "VIGOUR"
                        : item.kind === "risk" ? "RISK" : "PROTECTIVE";
        const editable = item.kind === "risk" || item.kind === "habit";
        const deletable = editable || item.kind === "tier";
        return (React.createElement("div", { key: item.id, className: "py-2.5 border-b border-[rgba(42,36,25,0.10)] last:border-0" },
            React.createElement("button", { onClick: () => setExpandedItem(expandedItem === item.id ? null : item.id), className: "w-full flex items-center justify-between text-left" },
                React.createElement("div", { className: "pr-2" },
                    React.createElement("div", { className: "text-sm text-[#332d20] uppercase tracking-wide font-semibold" }, item.label),
                    React.createElement("div", { className: "text-xs text-[#8a8172] mt-0.5" }, kindLabel + " \u00B7 " + wLabel(side === "prime" && dual ? (item.vigourWeight || item.weight) : item.weight) + (editable ? " \u00B7 " + freqSummary(item) : "")),
                    item.sub && item.list !== "prime" && React.createElement("div", { className: "text-xs text-[#9a9285] mt-0.5 normal-case" }, item.sub)),
                React.createElement(Pencil, { size: 14, className: "text-[#9a9285] shrink-0" })),
            expandedItem === item.id && (React.createElement("div", { className: "mt-3 space-y-3" },
                React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Name"),
                    React.createElement("input", { type: "text", value: item.label, onChange: (e) => updateItem(item.id, { label: e.target.value }), className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none text-[#2a2419]" })),
                item.list === "prev" && editable && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Type"),
                    React.createElement(Seg, { value: item.kind, allowClear: false, onChange: (v) => v && updateItem(item.id, { kind: v }), options: [{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }] }))),
                React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, dual ? "Weight \u2014 Prevention" : "Weight"),
                    React.createElement(Seg, { value: item.weight, allowClear: false, onChange: (v) => v && updateItem(item.id, { weight: v }), options: WEIGHT_OPTS })),
                dual && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Weight \u2014 Vigour"),
                    React.createElement(Seg, { value: item.vigourWeight || item.weight, allowClear: false, onChange: (v) => v && updateItem(item.id, { vigourWeight: v }), options: WEIGHT_OPTS }),
                    React.createElement("div", { className: "text-[10px] text-[#9a9285] mt-1.5 leading-relaxed" }, item.kind === "risk"
                        ? "Scores on both. Avoiding it earns Vigour; doing it raises Risk \u2014 each at its own weight."
                        : "Scores on both, at a different weight on each side."))),
                editable && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Scores On"),
                    React.createElement(Seg, { value: item.list, allowClear: false, onChange: (v) => v && updateItem(item.id, { list: v, bucket: item.bucket || "test" }), options: [{ v: "prev", label: "Prevention" }, { v: "prime", label: "Vigour", tone: "warn" }, { v: "both", label: "Both", tone: "teal" }] }))),
                editable && isPrime(item) && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Vigour Bucket"),
                    React.createElement(Seg, { value: item.bucket || "test", allowClear: false, onChange: (v) => v && updateItem(item.id, { bucket: v }), options: BUCKETS.map((b) => ({ v: b.id, label: b.label })) }))),
                editable && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "On Sick / Travelling Days"),
                    React.createElement(Seg, { value: item.excusable === true ? "excuse" : "count", allowClear: false, onChange: (v) => v && updateItem(item.id, { excusable: v === "excuse" }), options: [{ v: "count", label: "Still Counts" }, { v: "excuse", label: "Excused", tone: "teal" }] }),
                    React.createElement("div", { className: "text-[10px] text-[#9a9285] mt-1.5 leading-relaxed" }, item.excusable === true ? "Ignored entirely on flagged days \u2014 no credit, no penalty." : "Counts as normal even when you're sick or travelling."))),
                editable && !item.fastingAuto && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Days"),
                    React.createElement("button", { onClick: () => updateItem(item.id, { freq: "daily" }), className: "px-3 py-1.5 rounded-lg text-xs uppercase border mb-1.5 " + (item.freq === "daily" ? "font-bold text-neutral-950" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]"), style: item.freq === "daily" ? { background: TEAL, borderColor: TEAL } : undefined }, "Every Day"),
                    React.createElement("div", { className: "flex gap-1" }, WD.map((w, i) => {
                        const on = Array.isArray(item.freq) && item.freq.includes(i);
                        return (React.createElement("button", { key: w, onClick: () => toggleItemDay(Array.isArray(item.freq) ? item : { ...item, freq: [] }, i), className: "flex-1 py-1.5 rounded-lg text-xs border " + (on ? "bg-[#2a2419] border-[#2a2419] text-white font-bold" : "border-[rgba(42,36,25,0.16)] text-[#8a8172]") }, w));
                    })))),
                item.fastingAuto && (React.createElement("div", null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "Fasting Days"),
                    React.createElement(Seg, { value: data.settings.fastMode || "both", allowClear: false, onChange: (v) => v && setSetting("fastMode", v), options: [{ v: "both", label: "Mon/Thu + Lunar" }, { v: "lunar", label: "Lunar Only" }, { v: "weekly", label: "Mon/Thu Only" }] }))),
                deletable && (React.createElement("button", { onClick: () => { deleteItem(item.id); setExpandedItem(null); }, className: "text-xs text-rose-400 flex items-center gap-1 uppercase tracking-wide" },
                    React.createElement(Trash2, { size: 13 }),
                    " Remove Item"))))));
    };
    return (React.createElement("div", { className: "min-h-screen pb-24 overflow-x-hidden", style: { WebkitTapHighlightColor: "transparent", background: "var(--bg, #faf6ef)", color: "var(--ink, #2a2419)", transition: "background 0.8s, color 0.8s", ...ambient.vars } },
        React.createElement("style", { dangerouslySetInnerHTML: { __html: "@keyframes bullFruitThrob{0%,100%{transform:scale(1,1);}14%{transform:scale(1.07,1.04);}26%{transform:scale(1.0,.995);}38%{transform:scale(1.1,1.05);}58%{transform:scale(1,1);}}.bull-fruit-throb{animation:bullFruitThrob 1.9s ease-in-out infinite;}"
                    + ".bull-energy{position:fixed;top:-16%;left:50%;width:150%;aspect-ratio:1.2;transform:translateX(-50%);background:radial-gradient(ellipse at 50% 30%, var(--energyCol, rgba(214,164,52,.18)) 0%, transparent 62%);opacity:var(--energyOp,.3);pointer-events:none;z-index:0;animation:bullEnergyBreathe 5s ease-in-out infinite;transition:opacity .8s;}"
                    + "@keyframes bullEnergyBreathe{0%,100%{transform:translateX(-50%) scale(1);}50%{transform:translateX(-50%) scale(calc(1 + var(--breatheA,0.03)));}}"
                    + ".bull-danger{position:fixed;inset:0;pointer-events:none;z-index:40;background:radial-gradient(ellipse 120% 100% at 50% 45%, transparent 55%, rgba(190,45,40,var(--dgrOp,0)) 100%);transition:background .8s;}"
                    + ".bull-danger.tense{animation:bullTension 2.4s ease-in-out infinite;}"
                    + "@keyframes bullTension{0%,100%{opacity:1;}50%{opacity:.82;}}"
                    + ".bull-forceline{height:2px;border-radius:2px;margin:16px 0 4px;background:linear-gradient(90deg, var(--accent,#e0b040) 0%, transparent 45%, transparent 55%, rgba(220,38,38,var(--dgrLine,0)) 100%);opacity:.9;transition:background .8s;}"
                    + ".bull-field{background:rgba(42,36,25,0.05);}"
                    + ".bull-urge{position:relative;overflow:hidden;border:none;padding:0;background:linear-gradient(150deg,#f0c869 0%,var(--accent,#c9962c) 46%,#a87a1c 100%);box-shadow:0 2px 4px rgba(120,86,16,0.16), 0 10px calc(16px + var(--vig,0.5)*22px) rgba(201,150,44,calc(0.16 + var(--vig,0.5)*0.30)), inset 0 1px 0 rgba(255,255,255,0.42), inset 0 -1px 0 rgba(120,86,16,0.28);transition:transform .18s, box-shadow .5s;}"
                    + ".bull-urge-inner{display:flex;align-items:center;justify-content:center;gap:13px;padding:15px 18px;}"
                    + ".bull-urge-ring{display:flex;align-items:center;justify-content:center;width:35px;height:35px;border-radius:999px;background:rgba(255,255,255,0.22);border:1px solid rgba(255,255,255,0.34);color:#3d2c07;flex-shrink:0;}"
                    + ".bull-urge-copy{display:flex;flex-direction:column;align-items:flex-start;line-height:1.05;}"
                    + ".bull-urge-main{font-family:\'Oswald\',sans-serif;text-transform:uppercase;letter-spacing:0.2em;font-size:1.12rem;font-weight:700;color:#2e2105;}"
                    + ".bull-urge-sub{font-size:0.6rem;letter-spacing:0.15em;text-transform:uppercase;color:rgba(46,33,5,0.62);margin-top:3px;}"
                    + ".bull-urge-sheen{position:absolute;top:0;bottom:0;width:38%;left:-45%;background:linear-gradient(100deg,transparent,rgba(255,255,255,0.42),transparent);animation:bullUrgeSheen 5.2s ease-in-out infinite;pointer-events:none;}"
                    + "@keyframes bullUrgeSheen{0%,72%{left:-45%;}92%,100%{left:112%;}}"
                    + ".bull-nav{background:rgba(250,246,239,0.92);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);border-top:1px solid rgba(42,36,25,0.10);}"
                    + "@media (prefers-reduced-motion: reduce){.bull-energy,.bull-danger.tense,.bull-fruit-throb,.bull-urge-sheen{animation:none !important;}}" } }),
        React.createElement("div", { className: "bull-energy" }),
        React.createElement("div", { className: "bull-danger" + (ambient.tense ? " tense" : "") }),
        showMonth && React.createElement(MonthView, { data: data, items: items, settings: data.settings, onPick: (off) => { setViewOffset(off); setView("today"); }, onClose: () => setShowMonth(false) }),
        showSplash && data && React.createElement(Splash, { vigour: splashAvgs.vigour, risk: splashAvgs.risk, cleanPct: splashAvgs.clean, streak: streak, onDone: () => setShowSplash(false) }),
        breathing && React.createElement(Breathe, { purposeText: data.settings.purposeText, onClose: () => setBreathing(false) }),
        React.createElement("div", { className: "max-w-md mx-auto px-4", style: { paddingTop: "calc(env(safe-area-inset-top, 0px) + 24px)" } },
            view === "today" && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "flex items-center gap-1.5 mb-1" },
                    React.createElement("div", { className: "w-6 h-6 rounded-md", style: { background: AMBER } }),
                    React.createElement("span", { className: "text-xs font-bold tracking-[0.3em]", style: { color: AMBER } }, "BULL")),
                React.createElement("div", { className: "flex items-start justify-between" },
                    React.createElement("div", { className: "min-w-0 flex-1" },
                        React.createElement("div", { className: "flex items-center gap-1.5" },
                            React.createElement("button", { onClick: () => setViewOffset(viewOffset - 1), className: "text-[#9a9285] px-1 -ml-1 text-lg leading-none active:text-[#6f6757]" }, "\u2039"),
                            React.createElement("div", { className: "font-serif text-2xl text-[#2a2419] truncate" }, isToday ? now.toLocaleDateString(undefined, { weekday: "long" }) : now.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" })),
                            React.createElement("button", { onClick: () => viewOffset < 0 && setViewOffset(viewOffset + 1), disabled: viewOffset >= 0, className: "text-lg leading-none px-1 " + (viewOffset >= 0 ? "text-[#d4cec3]" : "text-[#9a9285] active:text-[#6f6757]") }, "\u203A"),
                            ),
                        !isToday && React.createElement("div", { className: "text-[10px] uppercase tracking-widest font-bold mt-0.5", style: { color: AMBER } }, "\u270E Editing Past Day"),
                        React.createElement("button", { onClick: () => setShowMonth(true), className: "text-sm text-[#8a8172] text-left flex items-center gap-1.5 active:opacity-60" },
                            React.createElement("span", { style: { borderBottom: "1px dashed rgba(42,36,25,0.28)" } }, now.toLocaleDateString(undefined, { day: "numeric", month: "long" })),
                            React.createElement(CalIcon, { size: 12, style: { opacity: 0.55 } }),
                            fastToday && React.createElement("span", { style: { color: AMBER } }, " \u00B7 FASTING DAY")),
                        React.createElement("div", { className: "flex items-center gap-1.5 mt-2", style: { color: AMBER } },
                            React.createElement(Flame, { size: 16 }),
                            React.createElement("span", { className: "font-mono text-sm font-bold" },
                                cleanPct,
                                "% CLEAN \u00B7 ",
                                windowDays,
                                "D"))),
                    React.createElement("div", { className: "flex gap-3 shrink-0" },
                        React.createElement(DevilRisk, { risk: risk, size: 62 }),
                        React.createElement(VigourFigure, { pct: vigourPct, size: 62 }))),
                React.createElement("div", { className: "bull-forceline" }),
                healthImported && isToday && (React.createElement("div", { className: "mt-3 rounded-xl px-3 py-2 text-[11px] tracking-wide", style: { background: "rgba(201,150,44,0.12)", color: "#8a7333" } },
                    "Imported from Health: " + healthImported.join(", "))),
                justRelapsed && (React.createElement(Card, { className: "mt-4 border border-[rgba(42,36,25,0.16)]" },
                    React.createElement("div", { className: "text-sm text-[#4a4335] leading-relaxed" }, "Logged. One slip is one data point \u2014 not a collapse. Water, shower, outside. Fast tomorrow."),
                    React.createElement("button", { onClick: () => setJustRelapsed(false), className: "mt-2 text-xs text-[#8a8172] uppercase tracking-wide" }, "Dismiss"))),
                React.createElement(GroupHeader, { icon: Shield, color: TEAL }, "Relapse Prevention"),
                isToday ? (React.createElement(React.Fragment, null,
                    React.createElement("button", { onClick: logUrge, className: "bull-urge w-full mt-1 rounded-2xl active:scale-[0.97] transition-transform" },
                        React.createElement("span", { className: "bull-urge-sheen" }),
                        React.createElement("span", { className: "bull-urge-inner" },
                            React.createElement("span", { className: "bull-urge-ring" }, React.createElement(Wind, { size: 19 })),
                            React.createElement("span", { className: "bull-urge-copy" },
                                React.createElement("span", { className: "bull-urge-main" }, "Urge"),
                                React.createElement("span", { className: "bull-urge-sub" }, "Tap to ride it out")))),
                    React.createElement("div", { className: "text-center text-xs text-[#8a8172] mt-1.5 uppercase tracking-wide" },
                        data.urges.length,
                        " urge",
                        data.urges.length === 1 ? "" : "s",
                        " survived all-time"))) : (React.createElement("div", { className: "text-center text-xs text-[#9a9285] mt-1 uppercase tracking-wide py-4 border border-dashed border-[rgba(42,36,25,0.10)] rounded-2xl" }, "Urge logging only available on today")),
                React.createElement(SectionLabel, null, "Morning Intention"),
                React.createElement(Card, null, today.intentionSet ? (React.createElement("div", { className: "flex items-start gap-2" },
                    React.createElement(Check, { size: 18, style: { color: TEAL }, className: "mt-0.5 shrink-0" }),
                    React.createElement("div", { className: "text-sm text-[#4a4335]" }, today.intentionText || "Intention set."))) : (React.createElement("div", { className: "flex gap-2" },
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
                            }, className: "flex-1 rounded-xl bull-field px-3 py-2 text-sm outline-none text-[#2a2419]" }),
                        data.settings.nextCheckin && (React.createElement("button", { onClick: () => setSetting("nextCheckin", null), className: "px-3 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#6f6757] text-xs uppercase tracking-wide" }, "Clear")))),
                React.createElement(SectionLabel, null, "Risk Factors Today"),
                React.createElement(TileGrid, null, prevRisks.map((it) => (React.createElement(Tile, { key: it.id, mode: "risk", label: it.label, value: today.checks[it.id] === undefined ? null : today.checks[it.id], onChange: (v) => setCheck(it.id, v) })))),
                React.createElement(Rows, null,
                    (() => { const it = items.find((i) => i.id === "contentAccess"); return it && React.createElement("div", { className: "pt-5 pb-4" },
                        React.createElement("div", { className: "text-[13.5px] text-[#4a4335] tracking-[0.02em] mb-2.5" }, it.label + " Today"),
                        React.createElement(Seg, { value: today.access, onChange: (v) => setDay("access", v), options: [{ v: "low", label: "Low", tone: "teal" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }] })); })(),
                    (() => { const it = items.find((i) => i.id === "checkout"); return it && React.createElement("div", { className: "py-4" },
                        React.createElement("div", { className: "text-[13.5px] text-[#4a4335] tracking-[0.02em] mb-2.5" }, it.label),
                        React.createElement(Seg, { value: today.checkout, onChange: (v) => setDay("checkout", v), options: [{ v: "none", label: "None", tone: "teal" }, { v: "few", label: "A Few", tone: "warn" }, { v: "lot", label: "A Lot", tone: "risk" }] })); })()),
                prevHabits.length > 0 && (React.createElement(React.Fragment, null,
                    React.createElement(SectionLabel, null, "Protective Habits"),
                    React.createElement(TileGrid, null, prevHabits.map((it) => (React.createElement(Tile, { key: it.id, mode: "protective", label: it.label, value: today.checks[it.id] === true, onChange: (v) => setCheck(it.id, v) })))))),
                React.createElement(SectionLabel, null, "Recovery"),
                React.createElement(Card, null,
                    React.createElement(NumField, { label: "Recovery Score", value: today.recovery, onChange: (v) => setDay("recovery", v), suffix: "%" }),
                    (() => {
                        if (!hrvBaseline || today.hrv === null || today.hrv === undefined || today.hrv === "")
                            return null;
                        const pct = Math.round((Number(today.hrv) / hrvBaseline - 1) * 100);
                        const low = pct <= -10;
                        return React.createElement("div", { className: "text-[10px] mt-2 leading-relaxed", style: { color: low ? "#b62f2b" : "#8a7333" } },
                            "HRV " + (pct >= 0 ? "+" : "") + pct + "% vs your " + Math.round(hrvBaseline) + "ms baseline" + (low ? " \u2014 notably suppressed" : ""));
                    })()),
                React.createElement(SectionLabel, null, "Day Flags"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("button", { onClick: () => setDay("sick", !today.sick), className: "flex-1 py-2.5 rounded-xl text-xs uppercase tracking-wide border font-semibold transition-colors " + (today.sick ? "text-neutral-950 font-bold" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]"), style: today.sick ? { background: CAUTION, borderColor: CAUTION } : undefined }, "Sick"),
                        React.createElement("button", { onClick: () => setDay("travelling", !today.travelling), className: "flex-1 py-2.5 rounded-xl text-xs uppercase tracking-wide border font-semibold transition-colors " + (today.travelling ? "text-neutral-950 font-bold" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]"), style: today.travelling ? { background: CAUTION, borderColor: CAUTION } : undefined }, "Travelling"))),
                React.createElement(SectionLabel, null, "Evening Review"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#4a4335] mb-2 font-semibold" }, "How Meaningful Did Today Feel"),
                    React.createElement("div", { className: "flex gap-2" }, [1, 2, 3, 4, 5].map((n) => (React.createElement("button", { key: n, onClick: () => setDay("purposeRating", today.purposeRating === n ? null : n), className: "flex-1 py-2.5 rounded-xl border text-base font-mono font-bold transition-colors " +
                            (today.purposeRating === n ? "bg-[#2a2419] text-white border-[#2a2419]" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]") }, n))))),
                React.createElement(GroupHeader, { icon: Zap, color: AMBER }, "Sexual Vigour"),
                primeByBucket.map((b) => React.createElement(React.Fragment, { key: b.id },
                    React.createElement(SectionLabel, null, b.label),
                    React.createElement(TileGrid, null, b.items.map((it) => (it.kind === "risk"
                        ? React.createElement(Tile, { key: it.id, mode: "risk", label: it.label, value: today.checks[it.id], onChange: (v) => setCheck(it.id, v) })
                        : React.createElement(Tile, { key: it.id, mode: "vigour", label: it.label, value: today.checks[it.id] === true, onChange: (v) => setCheck(it.id, v) })))),
                    /* supplements sit under Testosterone \u2014 they're scored as one lump, not per-bucket */
                    b.id === "test" && React.createElement(Card, { className: "mt-2" },
                        React.createElement("div", { className: "flex flex-wrap gap-2" }, data.settings.supplements.map((s) => {
                            const on = !!(today.supplementsTaken && today.supplementsTaken[s]);
                            return (React.createElement("button", { key: s, onClick: () => setDay("supplementsTaken", { ...today.supplementsTaken, [s]: !on }), className: "px-3 py-1.5 rounded-full text-xs uppercase tracking-wide border transition-colors font-semibold " +
                                    (on ? "text-neutral-950 font-bold" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]"), style: on ? { background: AMBER, borderColor: AMBER } : undefined }, s));
                        }))))),
                React.createElement(SectionLabel, null, "Sleep"),
                React.createElement(Card, null,
                    React.createElement(NumField, { label: "Sleep Score", value: today.sleep, onChange: (v) => setDay("sleep", v), suffix: "%" })),
                React.createElement("div", { className: "mt-8 text-center flex items-center justify-center gap-4" },
                    !confirmRelapse && !existingRelapse && React.createElement("button", { onClick: () => setConfirmRelapse(true), className: "text-xs text-[#9a9285] underline uppercase tracking-wide" }, "Log A Relapse"),
                    isToday && !confirmWetDream && React.createElement("button", { onClick: () => setConfirmWetDream(true), className: "text-xs text-[#9a9285] underline uppercase tracking-wide" }, "Log A Wet Dream")),
                confirmRelapse && !existingRelapse && (React.createElement(Card, { className: "mt-3" },
                    React.createElement("div", { className: "text-sm text-[#4a4335] mb-3" }, "What happened? Honesty keeps the data \u2014 and you \u2014 sharp."),
                    React.createElement("div", { className: "flex gap-2 mb-2" },
                        React.createElement("button", { onClick: () => logRelapse("orgasm"), className: "flex-1 py-2.5 rounded-xl text-white text-xs font-bold uppercase tracking-wide", style: { background: "#b62f2b" } }, "Orgasmed"),
                        React.createElement("button", { onClick: () => logRelapse("edge"), className: "flex-1 py-2.5 rounded-xl text-white text-xs font-bold uppercase tracking-wide", style: { background: "#c2701e" } }, "Edged Only")),
                    React.createElement("button", { onClick: () => setConfirmRelapse(false), className: "w-full py-2.5 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#4a4335] text-sm uppercase" }, "Cancel"))),
                existingRelapse && (React.createElement(Card, { className: "mt-3" },
                    React.createElement("div", { className: "text-xs uppercase tracking-widest font-bold mb-2 text-[#8a8172]" }, (isToday ? "Logged today \u2014 " : "Logged \u2014 ") + (existingRelapse.type === "edge" ? "Edged Only" : "Orgasmed")),
                    React.createElement("div", { className: "flex gap-2 mb-2" },
                        React.createElement("button", { onClick: () => editRelapseType("orgasm"), className: "flex-1 py-2.5 rounded-xl text-white text-xs font-bold uppercase tracking-wide transition-opacity " + (existingRelapse.type === "edge" ? "opacity-40" : ""), style: { background: "#b62f2b" } }, "Orgasmed"),
                        React.createElement("button", { onClick: () => editRelapseType("edge"), className: "flex-1 py-2.5 rounded-xl text-white text-xs font-bold uppercase tracking-wide transition-opacity " + (existingRelapse.type === "orgasm" || !existingRelapse.type ? "opacity-40" : ""), style: { background: "#c2701e" } }, "Edged Only")),
                    React.createElement("button", { onClick: removeRelapse, className: "w-full py-2.5 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#4a4335] text-sm uppercase" }, "Remove Log"))),
                isToday && confirmWetDream && (React.createElement(Card, { className: "mt-3" },
                    React.createElement("div", { className: "text-sm text-[#4a4335] mb-3" }, "Log a wet dream for today? Used only for Pattern correlation \u2014 same as relapses."),
                    React.createElement("div", { className: "flex gap-2" },
                        React.createElement("button", { onClick: logWetDream, className: "flex-1 py-2.5 rounded-xl text-neutral-950 text-sm font-bold uppercase", style: { background: AMBER } }, "Yes, Log It"),
                        React.createElement("button", { onClick: () => setConfirmWetDream(false), className: "flex-1 py-2.5 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#4a4335] text-sm uppercase" }, "Cancel")))))),
            view === "stats" && st && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "font-serif text-2xl text-[#2a2419] mb-4" }, "Patterns"),
                React.createElement(Seg, { value: period, allowClear: false, onChange: (v) => v && setPeriod(v), options: [{ v: "D", label: "Day" }, { v: "W", label: "Week" }, { v: "M", label: "Month" }, { v: "Y", label: "Year" }, { v: "A", label: "All" }] }),
                React.createElement("div", { className: "grid grid-cols-2 gap-3 mt-4" },
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Avg Risk"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: st.avgRisk === null ? "#e5e5e5" : riskColor(st.avgRisk) } }, st.avgRisk === null ? "—" : Math.round(st.avgRisk))),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Vigour"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: AMBER } }, st.vigour === null ? "—" : Math.round(st.vigour) + "%")),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Urges Survived"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: TEAL } }, st.urges)),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Relapses"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold text-[#2a2419] mt-1" }, st.relapses),
                        React.createElement("div", { className: "text-[10px] text-[#9a9285] mt-1 tracking-wide" }, st.orgasms + " orgasm \u00B7 " + st.edges + " edged")),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Wet Dreams"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: AMBER } }, st.wetDreams)),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Clean"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold mt-1", style: { color: AMBER } },
                            cleanPct,
                            "%")),
                    React.createElement(Card, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172]" }, "Best Streak"),
                        React.createElement("div", { className: "font-mono text-2xl font-bold text-[#2a2419] mt-1" },
                            bestStreak,
                            "D"))),
                React.createElement(SectionLabel, null, "Last 14 Days"),
                React.createElement(Card, null,
                    React.createElement("div", { className: "flex gap-1.5 justify-between" }, last14.map((d) => (React.createElement("div", { key: d.k, title: d.k, className: "flex-1 h-9 rounded", style: { background: d.rel ? ROSE : !d.logged ? "#292524" : riskColor(d.score) } })))),
                    React.createElement("div", { className: "text-xs text-[#8a8172] mt-2 uppercase tracking-wide" }, "Teal safe \u00B7 Amber caution \u00B7 Red risk/relapse \u00B7 Grey unlogged")),
                React.createElement(SectionLabel, null, "Relapse Patterns"),
                React.createElement(Card, null, correlations === null ? (React.createElement("div", { className: "text-sm text-[#6f6757]" }, "Unlocks after 3 logged relapses.")) : correlations.length === 0 ? (React.createElement("div", { className: "text-sm text-[#6f6757]" }, "Keep logging.")) : (correlations.map((c) => (React.createElement("div", { key: c.label, className: "py-2 border-b border-[rgba(42,36,25,0.10)] last:border-0" },
                    React.createElement("div", { className: "text-sm text-[#332d20] uppercase tracking-wide font-semibold" }, c.label),
                    React.createElement("div", { className: "text-xs text-[#8a8172]" },
                        "Present on ",
                        c.rel,
                        "% of relapse days \u00B7 ",
                        c.base,
                        "% of all days")))))),
                React.createElement(SectionLabel, null, "Edging Patterns"),
                React.createElement(Card, null, edgeCorrelations === null ? (React.createElement("div", { className: "text-sm text-[#6f6757]" }, "Unlocks after 3 logged edging episodes.")) : edgeCorrelations.length === 0 ? (React.createElement("div", { className: "text-sm text-[#6f6757]" }, "Keep logging.")) : (edgeCorrelations.map((c) => (React.createElement("div", { key: c.label, className: "py-2", style: { borderBottom: "1px solid rgba(42,36,25,0.09)" } },
                    React.createElement("div", { className: "text-sm text-[#332d20] uppercase tracking-wide font-semibold" }, c.label),
                    React.createElement("div", { className: "text-xs text-[#8a8172]" },
                        "Present on ",
                        c.rel,
                        "% of edging days \u00B7 ",
                        c.base,
                        "% of all days")))))),
                React.createElement(SectionLabel, null, "Wet Dream Patterns"),
                React.createElement(Card, null, wetDreamCorrelations === null ? (React.createElement("div", { className: "text-sm text-[#6f6757]" }, "Unlocks after 3 logged wet dreams.")) : wetDreamCorrelations.length === 0 ? (React.createElement("div", { className: "text-sm text-[#6f6757]" }, "Keep logging.")) : (wetDreamCorrelations.map((c) => (React.createElement("div", { key: c.label, className: "py-2 border-b border-[rgba(42,36,25,0.10)] last:border-0" },
                    React.createElement("div", { className: "text-sm text-[#332d20] uppercase tracking-wide font-semibold" }, c.label),
                    React.createElement("div", { className: "text-xs text-[#8a8172]" },
                        "Present on ",
                        c.rel,
                        "% of wet dream days \u00B7 ",
                        c.base,
                        "% of all days")))))))),
            view === "guide" && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "font-serif text-2xl text-[#2a2419] mb-4" }, "Guide"),
                GUIDE.map((grp) => React.createElement(React.Fragment, { key: grp.g },
                    React.createElement(SectionLabel, null, grp.g),
                    React.createElement(Card, null, grp.items.map((g) => {
                        const key = grp.g + "/" + g.t;
                        const open = openGuide === key;
                        return React.createElement("div", { key: key, className: "border-b border-[rgba(42,36,25,0.09)] last:border-0" },
                            React.createElement("button", { onClick: () => setOpenGuide(open ? null : key), className: "w-full flex items-center justify-between text-left py-3 gap-2.5" },
                                React.createElement("span", { className: "font-serif text-[13px] tracking-[0.05em] text-[#332d20] leading-snug" }, g.t),
                                React.createElement("span", { className: "flex items-center gap-2 shrink-0" },
                                    g.ev && React.createElement(EvChip, { ev: g.ev }),
                                    React.createElement(ChevronDown, { size: 15, className: "text-[#9a9285] transition-transform " + (open ? "rotate-180" : "") }))),
                            open && React.createElement("div", { className: "pb-3.5" },
                                React.createElement("div", { className: "text-[13px] font-semibold text-[#3a3327] leading-[1.5] mb-2.5" }, g.lead),
                                g.rows.map(([k, v], n) => React.createElement("div", { key: n, className: "flex gap-2.5 py-1.5 border-b border-[rgba(42,36,25,0.06)] last:border-0" },
                                    React.createElement("div", { className: "text-[10px] uppercase tracking-[0.1em] text-[#9a9285] font-bold pt-0.5 shrink-0", style: { flexBasis: 72 } }, k),
                                    React.createElement("div", { className: "text-[12.5px] text-[#6f6757] leading-[1.6]" }, v)))));
                    })))))),
            view === "settings" && (React.createElement(React.Fragment, null,
                React.createElement("div", { className: "font-serif text-2xl text-[#2a2419] mb-4" }, "Settings"),
                React.createElement(SectionLabel, null, "Your Purpose Card"),
                React.createElement(Card, null,
                    React.createElement("textarea", { value: data.settings.purposeText, onChange: (e) => setSetting("purposeText", e.target.value), rows: 6, className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none text-[#332d20] leading-relaxed" }),
                    React.createElement("div", { className: "text-xs text-[#8a8172] mt-1" }, "Shown when you tap Urge.")),
                React.createElement(SectionLabel, null, "Prevention Checklist Items"),
                React.createElement(Card, null, items.filter(isPrev).sort(byWeightDesc).map((it) => ItemEditorRow({ item: it, side: "prev" }))),
                BUCKETS.map((b) => {
                    const rows = items.filter((i) => isPrime(i) && (i.bucket || "test") === b.id).sort(byWeightDesc);
                    if (!rows.length)
                        return null;
                    return React.createElement(React.Fragment, { key: b.id },
                        React.createElement(SectionLabel, null, "Vigour \u00B7 " + b.label),
                        React.createElement(Card, null, rows.map((it) => ItemEditorRow({ item: it, side: "prime" }))));
                }),
                React.createElement("div", { className: "mt-3" }, !showAdd ? (React.createElement("button", { onClick: () => setShowAdd(true), className: "w-full py-3 rounded-2xl border border-dashed border-[rgba(42,36,25,0.16)] text-[#6f6757] text-sm flex items-center justify-center gap-1.5 uppercase tracking-wide" },
                    React.createElement(Plus, { size: 16 }),
                    " Add An Item")) : (React.createElement(Card, null,
                    React.createElement("input", { value: addForm.label, onChange: (e) => setAddForm({ ...addForm, label: e.target.value }), placeholder: "Item name\u2026", className: "w-full rounded-xl bull-field px-3 py-2 text-sm outline-none placeholder-neutral-600 mb-3" }),
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5" }, "List"),
                    React.createElement(Seg, { value: addForm.list, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, list: v }), options: [{ v: "prev", label: "Prevention" }, { v: "prime", label: "Vigour" }, { v: "both", label: "Both", tone: "teal" }] }),
                    addForm.list !== "prev" && (React.createElement(React.Fragment, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5 mt-3" }, "Vigour Bucket"),
                        React.createElement(Seg, { value: addForm.bucket, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, bucket: v }), options: BUCKETS.map((b) => ({ v: b.id, label: b.label })) }))),
                    addForm.list === "both" && (React.createElement(React.Fragment, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5 mt-3" }, "Type"),
                        React.createElement(Seg, { value: addForm.kind, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, kind: v }), options: [{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }] }),
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5 mt-3" }, "Weight \u2014 Vigour"),
                        React.createElement(Seg, { value: addForm.vigourWeight, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, vigourWeight: v }), options: WEIGHT_OPTS }))),
                    addForm.list === "prev" && (React.createElement(React.Fragment, null,
                        React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5 mt-3" }, "Type"),
                        React.createElement(Seg, { value: addForm.kind, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, kind: v }), options: [{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }] }))),
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5 mt-3" }, "Weight"),
                    React.createElement(Seg, { value: addForm.weight, allowClear: false, onChange: (v) => v && setAddForm({ ...addForm, weight: v }), options: [{ v: "low", label: "Low" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }, { v: "vhigh", label: "V.High", tone: "risk" }] }),
                    React.createElement("div", { className: "text-xs uppercase tracking-wide text-[#8a8172] mb-1.5 mt-3" }, "Days"),
                    React.createElement("div", { className: "flex gap-1 mb-1.5" },
                        React.createElement("button", { onClick: () => setAddForm({ ...addForm, daily: true }), className: "px-3 py-1.5 rounded-lg text-xs uppercase border " + (addForm.daily ? "font-bold text-neutral-950" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]"), style: addForm.daily ? { background: TEAL, borderColor: TEAL } : undefined }, "Every Day"),
                        React.createElement("button", { onClick: () => setAddForm({ ...addForm, daily: false }), className: "px-3 py-1.5 rounded-lg text-xs uppercase border " + (!addForm.daily ? "bg-[#2a2419] border-[#2a2419] text-white font-bold" : "border-[rgba(42,36,25,0.16)] text-[#6f6757]") }, "Specific Days")),
                    !addForm.daily && (React.createElement("div", { className: "flex gap-1" }, WD.map((w, i) => {
                        const on = addForm.days.includes(i);
                        return (React.createElement("button", { key: w, onClick: () => setAddForm({ ...addForm, days: on ? addForm.days.filter((d) => d !== i) : [...addForm.days, i] }), className: "flex-1 py-1.5 rounded-lg text-xs border " + (on ? "bg-[#2a2419] border-[#2a2419] text-white font-bold" : "border-[rgba(42,36,25,0.16)] text-[#8a8172]") }, w));
                    }))),
                    React.createElement("div", { className: "flex gap-2 mt-4" },
                        React.createElement("button", { onClick: addItem, className: "flex-1 py-2.5 rounded-xl text-neutral-950 text-sm font-bold uppercase", style: { background: TEAL } }, "Add Item"),
                        React.createElement("button", { onClick: () => setShowAdd(false), className: "flex-1 py-2.5 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#4a4335] text-sm uppercase" }, "Cancel"))))),
                React.createElement(SectionLabel, null, "Supplements"),
                React.createElement(Card, null,
                    data.settings.supplements.map((s) => (React.createElement("div", { key: s, className: "flex items-center justify-between py-2 border-b border-[rgba(42,36,25,0.10)] last:border-0" },
                        React.createElement("span", { className: "text-sm text-[#4a4335] uppercase tracking-wide" }, s),
                        React.createElement("button", { onClick: () => setSetting("supplements", data.settings.supplements.filter((x) => x !== s)) },
                            React.createElement(Trash2, { size: 15, className: "text-[#9a9285]" }))))),
                    React.createElement("div", { className: "flex gap-2 mt-3" },
                        React.createElement("input", { value: newSup, onChange: (e) => setNewSup(e.target.value), placeholder: "Add supplement\u2026", className: "flex-1 rounded-xl bull-field px-3 py-2 text-sm outline-none placeholder-neutral-600" }),
                        React.createElement("button", { onClick: () => { const v = newSup.trim(); if (v && !data.settings.supplements.includes(v))
                                setSetting("supplements", [...data.settings.supplements, v]); setNewSup(""); }, className: "px-3 rounded-xl bg-neutral-200 text-neutral-950" },
                            React.createElement(Plus, { size: 16 })))),
                React.createElement(SectionLabel, null, "Accountability Frequency"),
                React.createElement(Card, null,
                    React.createElement(Seg, { value: data.settings.therapistEveryWeeks, allowClear: false, onChange: (v) => v && setSetting("therapistEveryWeeks", v), options: [{ v: 1, label: "Weekly" }, { v: 2, label: "2 Wks" }, { v: 3, label: "3 Wks" }, { v: 4, label: "4 Wks" }] })),
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
                        React.createElement("label", { className: "flex-1 py-2.5 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#4a4335] text-xs font-bold uppercase tracking-wide text-center cursor-pointer" },
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
                        React.createElement("div", { className: "text-sm text-[#4a4335] mb-2" }, "This wipes every log, urge, relapse, item and setting. Sure?"),
                        React.createElement("div", { className: "flex gap-2" },
                            React.createElement("button", { onClick: async () => {
                                    await storageClear();
                                    setResetStep(0);
                                    persist({ version: 6, settings: { ...DEFAULT_SETTINGS }, items: DEFAULT_ITEMS.map((i) => ({ ...i, freq: Array.isArray(i.freq) ? [...i.freq] : i.freq })), days: {}, urges: [], relapses: [], firstUse: Date.now() });
                                }, className: "flex-1 py-2 rounded-xl bg-rose-500 text-white text-sm font-bold uppercase" }, "Wipe Everything"),
                            React.createElement("button", { onClick: () => setResetStep(0), className: "flex-1 py-2 rounded-xl bg-[rgba(42,36,25,0.06)] text-[#4a4335] text-sm uppercase" }, "Cancel")))),
                    React.createElement("div", { className: "text-xs text-[#9a9285] mt-3" }, "On-device only."))))),
        React.createElement("div", { className: "fixed bottom-0 inset-x-0 z-[45] bull-nav", style: { paddingBottom: "env(safe-area-inset-bottom, 0px)" } },
            React.createElement("div", { className: "max-w-md mx-auto flex" },
                React.createElement(NavBtn, { id: "today", icon: Shield, label: "Today" }),
                React.createElement(NavBtn, { id: "stats", icon: BarChart3, label: "Patterns" }),
                React.createElement(NavBtn, { id: "guide", icon: BookOpen, label: "Guide" }),
                React.createElement(NavBtn, { id: "settings", icon: SettingsIcon, label: "Settings" })))));
}
import { createRoot } from "https://esm.sh/react-dom@18.3.1/client";
createRoot(document.getElementById("root")).render(React.createElement(App, null));

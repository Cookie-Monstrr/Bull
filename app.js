import React, { useState, useEffect, useRef } from "react";

/* ---------- icons (self-contained, no external icon package) ---------- */
const IconBase = ({ children, size = 20, ...p }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}>{children}</svg>
);
const Flame = (p) => <IconBase {...p}><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" /></IconBase>;
const Wind = (p) => <IconBase {...p}><path d="M9.59 4.59A2 2 0 1 1 11 8H2" /><path d="M12.59 19.41A2 2 0 1 0 14 16H2" /><path d="M17.73 7.73A2.5 2.5 0 1 1 19.5 12H2" /></IconBase>;
const Shield = (p) => <IconBase {...p}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" /></IconBase>;
const BookOpen = (p) => <IconBase {...p}><path d="M2 4h6a4 4 0 0 1 4 4v12a3 3 0 0 0-3-3H2z" /><path d="M22 4h-6a4 4 0 0 0-4 4v12a3 3 0 0 1 3-3h7z" /></IconBase>;
const SettingsIcon = (p) => <IconBase {...p}><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" /></IconBase>;
const Check = (p) => <IconBase {...p}><path d="M20 6 9 17l-5-5" /></IconBase>;
const Plus = (p) => <IconBase {...p}><path d="M12 5v14M5 12h14" /></IconBase>;
const Trash2 = (p) => <IconBase {...p}><path d="M3 6h18" /><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" /><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" /><path d="M10 11v6M14 11v6" /></IconBase>;
const ChevronDown = (p) => <IconBase {...p}><path d="m6 9 6 6 6-6" /></IconBase>;
const BarChart3 = (p) => <IconBase {...p}><path d="M3 3v18h18" /><rect x="7" y="12" width="3" height="6" /><rect x="12" y="8" width="3" height="10" /><rect x="17" y="5" width="3" height="13" /></IconBase>;
const Pencil = (p) => <IconBase {...p}><path d="M12 20h9" /><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z" /></IconBase>;
const Zap = (p) => <IconBase {...p}><path d="M13 2 3 14h9l-1 8 10-12h-9z" /></IconBase>;

/* ---------- storage (browser localStorage — persists on-device between visits) ---------- */
const KEY = "bull-tracker-data";
async function storageGet() {
  try {
    const raw = window.localStorage.getItem(KEY);
    return raw ? JSON.parse(raw) : null;
  } catch (e) { return null; }
}
async function storageSet(obj) {
  try { window.localStorage.setItem(KEY, JSON.stringify(obj)); }
  catch (e) { console.error("save failed", e); }
}
async function storageClear() {
  try { window.localStorage.removeItem(KEY); } catch (e) {}
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
  } catch (e) { return null; }
}
function fastingSuggested(date) {
  const dow = date.getDay();
  if (dow === 1 || dow === 4) return true;
  const h = hijriDay(date);
  return h !== null && h >= 13 && h <= 15;
}

/* ---------- colours ---------- */
const TEAL = "#2dd4bf";
const AMBER = "#f59e0b";
const ROSE = "#f43f5e";
const CAUTION = "#fbbf24";

/* ---------- weights ---------- */
const W_RISK = { high: 20, med: 10, low: 5 };
const W_PROT = { high: 8, med: 5, low: 2 };
const W_ADH = { high: 3, med: 2, low: 1 };

/* ---------- default items ---------- */
const DEFAULT_ITEMS = [
  { id: "lonely", label: "Home Alone, Unstructured Time", list: "prev", kind: "risk", weight: "high", freq: "daily" },
  { id: "junk", label: "Junk Food", list: "prev", kind: "risk", weight: "med", freq: "daily" },
  { id: "caffeine", label: "Caffeine", list: "prev", kind: "risk", weight: "med", freq: "daily" },
  { id: "latescreen", label: "Late Night Screens", sub: "Screens in bed after dark", list: "prev", kind: "risk", weight: "med", freq: "daily" },
  { id: "coldplunge", label: "Cold Plunge", sub: "1–3 min cold exposure", list: "prev", kind: "habit", weight: "med", freq: "daily" },
  { id: "nasalclear", label: "Nasal Rinse", sub: "Clear airway before bed", list: "prev", kind: "habit", weight: "med", freq: "daily" },
  { id: "kegels", label: "Kegels", sub: "3×10, hold 3–5s, then release", list: "prime", kind: "habit", weight: "high", freq: [1, 3, 5, 0] },
  { id: "stretches", label: "Pelvic Floor Stretches", sub: "5–10 min release work", list: "prime", kind: "habit", weight: "med", freq: [1, 3, 5, 0] },
  { id: "cardio", label: "Cardio / Boxing", sub: "40 min moderate–vigorous", list: "prime", kind: "habit", weight: "high", freq: [1, 3, 5, 0] },
  { id: "strength", label: "Strength Training", sub: "Compounds + isometrics", list: "prime", kind: "habit", weight: "med", freq: [2, 6] },
  { id: "breathwork", label: "Breathwork Before Isha", sub: "5 min diaphragmatic — lowers stress before bed", list: "prime", kind: "habit", weight: "med", freq: "daily" },
  { id: "mouthtape", label: "Mouth Tape", sub: "Nasal breathing overnight", list: "prime", kind: "habit", weight: "low", freq: "daily" },
  { id: "fasting", label: "Fasting", sub: "Mon / Thu / 13–15 lunar — recovery reset", list: "prime", kind: "habit", weight: "med", freq: "daily", fastingAuto: true },
];

const DEFAULT_PURPOSE =
  "I am preparing for her before I have met her. Every clean day is me becoming the man and husband I intend to be on day one — clear-eyed, disciplined, present.\n\nThis urge is a wave. It rises, it peaks, it passes. I do not act on it. I am building something better.";

const DEFAULT_SETTINGS = {
  purposeText: DEFAULT_PURPOSE,
  supplements: ["Zinc", "Magnesium", "Vitamin D"],
  therapistEveryWeeks: 2,
  nextCheckin: null,
  manualLastRelapseDate: null,
};

const emptyDay = () => ({
  checks: {}, access: null, checkout: null,
  intentionText: "", intentionSet: false, purposeRating: null,
  recovery: null, sleep: null,
  supplementsTaken: {},
});

/* ---------- migration ---------- */
function migrate(old) {
  if (!old) return null;
  if (old.version === 5) return old;
  const base = old.version === 2 ? old : (() => {
    const items = DEFAULT_ITEMS.map((it) => {
      const c = { ...it, freq: Array.isArray(it.freq) ? [...it.freq] : it.freq };
      if (["kegels", "stretches", "cardio"].includes(it.id) && Array.isArray(old.settings?.stackDays)) c.freq = [...old.settings.stackDays];
      if (it.id === "strength" && Array.isArray(old.settings?.strengthDays)) c.freq = [...old.settings.strengthDays];
      return c;
    });
    const days = {};
    Object.entries(old.days || {}).forEach(([k, d]) => {
      const checks = {};
      ["lonely", "junk", "caffeine"].forEach((f) => { if (d[f] !== null && d[f] !== undefined) checks[f] = d[f]; });
      if (d.lateScreen !== null && d.lateScreen !== undefined) checks.latescreen = d.lateScreen;
      ["kegels", "stretches", "cardio", "strength"].forEach((f) => { if (d[f]) checks[f] = true; });
      if (d.breathing) checks.breathwork = true;
      if (d.mouthTape) { checks.mouthtape = true; checks.nasalclear = true; }
      if (d.fasted) checks.fasting = true;
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
  base.settings = { manualLastRelapseDate: null, ...base.settings };
  return { ...base, version: 5 };
}

/* ---------- scheduling ---------- */
function scheduledOn(item, date) {
  if (item.freq === "daily") return true;
  if (Array.isArray(item.freq)) return item.freq.length === 0 ? true : item.freq.includes(date.getDay());
  return true;
}
function adherenceExpected(item, date) {
  if (item.fastingAuto) return fastingSuggested(date);
  return scheduledOn(item, date);
}

/* ---------- scoring ---------- */
function riskScore(day, items, urgesSurvived, hadRelapse, accountabilityPenalty = 0) {
  const d = day || emptyDay();
  let r = 15;
  items.filter((i) => i.list === "prev").forEach((it) => {
    const v = d.checks ? d.checks[it.id] : undefined;
    if (it.kind === "risk") { if (v === true) r += W_RISK[it.weight]; }
    else { if (v === true) r -= W_PROT[it.weight]; }
  });
  if (d.access === "high") r += 25; else if (d.access === "med") r += 12;
  if (d.checkout === "lot") r += 12; else if (d.checkout === "few") r += 4;
  if (d.recovery !== null && d.recovery !== undefined && d.recovery !== "" && Number(d.recovery) < 40) r += 10;
  if (d.purposeRating !== null && d.purposeRating !== undefined) {
    if (d.purposeRating <= 2) r += 10;
    else if (d.purposeRating >= 4) r -= 5;
  }
  r -= Math.min((urgesSurvived || 0) * 4, 12);
  r += accountabilityPenalty;
  if (hadRelapse) r = Math.max(r, 85);
  return Math.max(0, Math.min(100, r));
}
function riskLogged(day, items) {
  if (!day) return false;
  const anyRisk = items.some((i) => i.list === "prev" && day.checks && day.checks[i.id] !== undefined && day.checks[i.id] !== null);
  return anyRisk || day.access != null || day.checkout != null || day.purposeRating != null;
}
function vigourForDay(day, date, items, settings) {
  const d = day || emptyDay();
  let total = 0, done = 0;
  items.filter((i) => i.list === "prime" && i.kind === "habit").forEach((it) => {
    if (!adherenceExpected(it, date)) return;
    const w = W_ADH[it.weight] || 2;
    total += w;
    if (d.checks && d.checks[it.id] === true) done += w;
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
  return <div className={"bg-neutral-900 border border-neutral-800 rounded-2xl p-4 " + className}>{children}</div>;
}
function GroupHeader({ icon: Icon, color, children }) {
  return (
    <div className="flex items-center gap-2 mt-8 mb-3">
      <Icon size={16} style={{ color }} />
      <div className="text-sm font-bold uppercase tracking-widest" style={{ color }}>{children}</div>
    </div>
  );
}
function SectionLabel({ children }) {
  return <div className="text-xs uppercase tracking-widest text-neutral-500 mb-2 mt-5">{children}</div>;
}
function Seg({ value, options, onChange, allowClear = true }) {
  return (
    <div className="flex gap-1.5">
      {options.map((o) => {
        const active = value === o.v;
        const tone = o.tone || "neutral";
        let cls = "bg-neutral-800 text-neutral-400 border-neutral-700";
        if (active) {
          if (tone === "teal") cls = "border-2 font-bold text-neutral-950";
          else if (tone === "amber") cls = "border-2 font-bold text-neutral-950";
          else if (tone === "warn") cls = "bg-amber-300 text-neutral-950 border-amber-300 font-bold";
          else if (tone === "risk") cls = "bg-rose-500 text-neutral-50 border-rose-500 font-bold";
          else cls = "bg-neutral-200 text-neutral-950 border-neutral-200 font-bold";
        }
        const style = active && tone === "teal" ? { background: TEAL, borderColor: TEAL } :
          active && tone === "amber" ? { background: AMBER, borderColor: AMBER } : undefined;
        return (
          <button key={String(o.v)} style={style} onClick={() => onChange(active && allowClear ? null : o.v)}
            className={"flex-1 py-2 px-2 rounded-xl border text-xs uppercase tracking-wide transition-colors " + cls}>
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
function YesNo({ label, sub, value, onChange, mode = "risk" }) {
  const yesTone = mode === "risk" ? "risk" : mode === "vigour" ? "amber" : "teal";
  const noTone = mode === "risk" ? "teal" : "neutral";
  return (
    <div className="flex items-center justify-between py-2.5 border-b border-neutral-800 last:border-0 gap-3">
      <div className="pr-1">
        <div className="text-[13px] uppercase tracking-wide text-neutral-200 font-semibold">{label}</div>
        {sub && <div className="text-xs text-neutral-500 mt-0.5 normal-case tracking-normal">{sub}</div>}
      </div>
      <div className="w-28 shrink-0">
        <Seg value={value === undefined ? null : value} onChange={onChange}
          options={[{ v: true, label: "Yes", tone: yesTone }, { v: false, label: "No", tone: noTone }]} />
      </div>
    </div>
  );
}
function NumField({ label, value, onChange, max = 100, suffix }) {
  return (
    <div className="flex-1">
      <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1">{label}</div>
      <div className="flex items-center gap-1 bg-neutral-800 rounded-xl px-3 py-2">
        <input inputMode="numeric" value={value === null || value === undefined ? "" : value}
          onChange={(e) => {
            const raw = e.target.value.replace(/[^0-9]/g, "");
            if (raw === "") return onChange(null);
            onChange(Math.min(max, parseInt(raw, 10)));
          }}
          placeholder="—"
          className="w-full bg-transparent text-neutral-100 text-base outline-none placeholder-neutral-600" />
        {suffix && <span className="text-xs text-neutral-500">{suffix}</span>}
      </div>
    </div>
  );
}
function Ring({ pct, size = 68, stroke = 6, color, label }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const off = c - (Math.max(0, Math.min(100, pct)) / 100) * c;
  return (
    <div className="flex flex-col items-center">
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={r} stroke="#262626" strokeWidth={stroke} fill="none" />
        <circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeWidth={stroke} fill="none"
          strokeDasharray={c} strokeDashoffset={off} strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`} style={{ transition: "stroke-dashoffset 0.6s" }} />
        <text x="50%" y="52%" dominantBaseline="middle" textAnchor="middle" fill="#e5e5e5"
          fontSize={size / 4.2} fontFamily="ui-monospace, monospace" fontWeight="700">{Math.round(pct)}</text>
      </svg>
      {label && <div className="text-[10px] uppercase tracking-widest text-neutral-500 mt-1 font-semibold">{label}</div>}
    </div>
  );
}

/* ---------- breathe overlay ---------- */
function Breathe({ purposeText, onClose }) {
  const [started, setStarted] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const TOTAL = 180;
  useEffect(() => {
    if (!started) return;
    const t0 = Date.now();
    const iv = setInterval(() => {
      const e = (Date.now() - t0) / 1000;
      setElapsed(e >= TOTAL ? TOTAL : e);
      if (e >= TOTAL) clearInterval(iv);
    }, 100);
    return () => clearInterval(iv);
  }, [started]);

  const inCycle = elapsed % 10;
  let phase, scale, dur;
  if (inCycle < 2.5) { phase = "Inhale Through The Nose"; scale = 1.14; dur = "2.5s"; }
  else if (inCycle < 4) { phase = "Sip In A Little More"; scale = 1.3; dur = "1.5s"; }
  else { phase = "Long Slow Exhale Through The Mouth"; scale = 0.7; dur = "6s"; }
  const remaining = Math.ceil(TOTAL - elapsed);
  const mm = Math.floor(remaining / 60), ss = pad(remaining % 60);
  const doneAll = elapsed >= TOTAL;

  return (
    <div className="fixed inset-0 z-50 bg-neutral-950 flex flex-col items-center justify-between p-6 overflow-y-auto">
      <div className="w-full max-w-md pt-4">
        <div className="text-xs uppercase tracking-widest font-bold mb-3" style={{ color: TEAL }}>Win Logged — Urge Survived</div>
        <p className="font-serif text-neutral-200 text-lg leading-relaxed whitespace-pre-line">{purposeText}</p>
      </div>
      {!started ? (
        <button onClick={() => setStarted(true)}
          className="my-10 px-8 py-4 rounded-2xl font-bold text-lg text-neutral-950" style={{ background: TEAL }}>
          BEGIN 3-MINUTE RESET
        </button>
      ) : (
        <div className="flex flex-col items-center my-8">
          <div className="relative w-52 h-52 flex items-center justify-center">
            <div className="absolute inset-0 rounded-full border border-neutral-800" />
            <div className="w-36 h-36 rounded-full opacity-20" style={{ background: TEAL, transform: `scale(${scale})`, transition: `transform ${dur} ease-in-out` }} />
            <div className="absolute w-36 h-36 rounded-full border-2" style={{ borderColor: TEAL, transform: `scale(${scale})`, transition: `transform ${dur} ease-in-out` }} />
          </div>
          <div className="text-neutral-200 mt-6 text-sm uppercase tracking-wide font-semibold">{doneAll ? "Steady — The Wave Passed" : phase}</div>
          <div className="font-mono text-neutral-500 mt-1 text-sm">{doneAll ? "0:00" : `${mm}:${ss}`}</div>
        </div>
      )}
      <div className="w-full max-w-md pb-4">
        <button onClick={onClose}
          className={"w-full py-3.5 rounded-2xl font-bold uppercase tracking-wide " + (doneAll ? "text-neutral-950" : "bg-neutral-800 text-neutral-400")}
          style={doneAll ? { background: TEAL } : undefined}>
          {doneAll ? "Return, Stronger" : started ? "I'm Steady — Return Early" : "Close"}
        </button>
      </div>
    </div>
  );
}

/* ---------- guide ---------- */
const GUIDE = [
  { t: "The Urge Protocol", b: "Tap the Urge button the moment it hits. The tap alone is a win, logged permanently. Your purpose card appears, then a 3-minute physiological sigh. Urges peak within minutes and pass if not fed. Still strong afterward — change environment. Leave the room, leave the house." },
  { t: "Physiological Sigh", b: "Double inhale through the nose — one full breath, then a short extra sip on top — followed by a long, slow exhale through the mouth. Fastest evidence-backed way to downshift the nervous system in real time." },
  { t: "Cold Exposure", b: "Cold plunges spike norepinephrine and dopamine, train stress tolerance, and act as a hard pattern-interrupt — the same discomfort skill used to sit through an urge without acting. 1–3 minutes is enough. Also supports HRV over time." },
  { t: "Nasal Rinse", b: "A blocked nose forces mouth breathing at night, degrading sleep quality and recovery — your biggest vulnerability driver. Rinse daily, especially before bed. A clear airway is a protective habit in its own right." },
  { t: "Kegels + Reverse Kegels", b: "Find the muscle by imagining stopping urine mid-flow. Protocol: 3 sets of 10, holding 3–5 seconds, equal relaxation between reps. Pair every session with reverse kegels — a gentle bearing-down release on the exhale. Strengthening without releasing worsens pelvic tension." },
  { t: "Pelvic Floor Stretches", b: "5–10 minutes on scheduled days: happy baby, deep squat, child's pose, butterfly. Slow nasal breathing throughout, letting the pelvic floor soften on each exhale. The goal is release, not effort." },
  { t: "Breathwork Before Isha", b: "5 minutes of diaphragmatic breathing, anchored to Isha prayer for consistency. Hand on the belly, inhale through the nose so the belly rises, exhale longer than the inhale. Lowers stress and cortisol right before the evening window when urges are most likely — your daily nervous-system reset, timed to a fixed anchor you already have." },
  { t: "Mouth Tape", b: "Small strip of porous tape over the lips at night — never when congested. Keeps nasal breathing during sleep, improving oxygenation and recovery. Pair with the nasal rinse. Stop if it ever feels unsafe." },
  { t: "Cardio Target", b: "40 minutes moderate-to-vigorous, 4× per week — the threshold linked to improved erectile and vascular function. Boxing counts fully. Mornings only — evening sessions cost sleep." },
  { t: "Strength Training", b: "2–3× per week, compound lifts — squat, hinge, press, pull. Supports testosterone, mood, body composition. Isometric holds count here and build pain tolerance." },
  { t: "Supplements", b: "Zinc with food. Magnesium glycinate in the evening — also aids sleep. Vitamin D in the morning, with a fatty meal. Confirm doses against your blood panel." },
  { t: "Fasting Rhythm", b: "Mondays, Thursdays, and the 13th–15th of the lunar month, auto-suggested. Treat fasting as recovery and reset — rebuilds discipline and clarity, especially in the days after a slip." },
  { t: "How Scoring Works", b: "Relapse Risk starts near baseline and rises with each active risk factor (weighted High/Med/Low) and falls with protective habits and surviving urges — lower is safer. Sexual Vigour is the weighted percentage of scheduled priming actions completed. Every item's weight is yours to set from experience — the Patterns tab shows what actually precedes your relapses over time." },
];

/* ---------- main ---------- */
function App() {
  const [data, setData] = useState(null);
  const [view, setView] = useState("today");
  const [breathing, setBreathing] = useState(false);
  const [confirmRelapse, setConfirmRelapse] = useState(false);
  const [justRelapsed, setJustRelapsed] = useState(false);
  const [resetStep, setResetStep] = useState(0);
  const [openGuide, setOpenGuide] = useState(null);
  const [period, setPeriod] = useState("W");
  const [newSup, setNewSup] = useState("");
  const [expandedItem, setExpandedItem] = useState(null);
  const [showAdd, setShowAdd] = useState(false);
  const [addForm, setAddForm] = useState({ label: "", list: "prev", kind: "risk", weight: "med", daily: true, days: [] });
  const saveTimer = useRef(null);

  useEffect(() => {
    (async () => {
      const loaded = migrate(await storageGet());
      if (loaded) setData(loaded);
      else setData({
        version: 5, settings: { ...DEFAULT_SETTINGS },
        items: DEFAULT_ITEMS.map((i) => ({ ...i, freq: Array.isArray(i.freq) ? [...i.freq] : i.freq })),
        days: {}, urges: [], relapses: [], firstUse: Date.now(),
      });
    })();
  }, []);

  const persist = (next) => {
    setData(next);
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => storageSet(next), 500);
  };

  if (!data) {
    return (
      <div className="min-h-screen bg-neutral-950 flex items-center justify-center">
        <div className="text-neutral-500 text-sm uppercase tracking-widest">Loading</div>
      </div>
    );
  }

  const items = data.items || [];
  const tk = todayKey();
  const today = { ...emptyDay(), ...(data.days[tk] || {}) };
  const setDay = (k, v) => persist({ ...data, days: { ...data.days, [tk]: { ...today, [k]: v } } });
  const setCheck = (id, v) => setDay("checks", { ...today.checks, [id]: v });

  const urgesToday = data.urges.filter((u) => dateKey(new Date(u.ts)) === tk).length;
  const relapseToday = data.relapses.some((r) => dateKey(new Date(r.ts)) === tk);

  const therapistStatus = (() => {
    const next = data.settings.nextCheckin;
    if (!next) return "setup";
    if (next < Date.now()) return "overdue";
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

  const logUrge = () => { persist({ ...data, urges: [...data.urges, { ts: Date.now() }] }); setBreathing(true); };
  const logRelapse = () => {
    persist({ ...data, relapses: [...data.relapses, { ts: Date.now() }] });
    setConfirmRelapse(false); setJustRelapsed(true);
  };

  const now = new Date();
  const prevRisks = items.filter((i) => i.list === "prev" && i.kind === "risk" && scheduledOn(i, now));
  const prevHabits = items.filter((i) => i.list === "prev" && i.kind === "habit" && scheduledOn(i, now));
  const primeToday = items.filter((i) => i.list === "prime" && i.kind === "habit" && (i.fastingAuto || scheduledOn(i, now)));
  const fastToday = fastingSuggested(now);

  /* ---- stats ---- */
  const statsFor = () => {
    const nowTs = Date.now();
    let from = 0;
    if (period === "D") from = nowTs - DAY_MS;
    else if (period === "W") from = nowTs - 7 * DAY_MS;
    else if (period === "M") from = nowTs - 30 * DAY_MS;
    else if (period === "Y") from = nowTs - 365 * DAY_MS;
    const relKeySet = new Set(data.relapses.map((r) => dateKey(new Date(r.ts))));
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
      if (t.getTime() < from) return;
      const r = vigourForDay({ ...emptyDay(), ...data.days[k] }, t, items, data.settings);
      hd += r.done; ht += r.total;
    });
    return {
      avgRisk: keys.length ? sum / keys.length : null,
      vigour: ht ? (hd / ht) * 100 : null,
      urges: data.urges.filter((u) => u.ts >= from).length,
      relapses: data.relapses.filter((r) => r.ts >= from).length,
    };
  };

  const bestStreak = (() => {
    const relapseTs = data.relapses.map((r) => r.ts);
    if (manualStart) relapseTs.push(manualStart);
    const pts = [data.firstUse, ...relapseTs.sort((a, b) => a - b), Date.now()];
    let best = 0;
    for (let i = 1; i < pts.length; i++) best = Math.max(best, Math.floor((pts[i] - pts[i - 1]) / DAY_MS));
    return best;
  })();

  const correlations = (() => {
    if (data.relapses.length < 3) return null;
    const relKeys = [...new Set(data.relapses.map((r) => dateKey(new Date(r.ts))))].filter((k) => data.days[k]);
    const allKeys = Object.keys(data.days).filter((k) => riskLogged(data.days[k], items));
    if (!relKeys.length || !allKeys.length) return null;
    const factors = [
      ...items.filter((i) => i.list === "prev" && i.kind === "risk").map((i) => ({ label: i.label, test: (d) => d.checks && d.checks[i.id] === true })),
      ...items.filter((i) => i.list === "prev" && i.kind === "habit").map((i) => ({ label: "Skipped: " + i.label, test: (d) => !(d.checks && d.checks[i.id] === true) })),
      { label: "Med/High Content Access", test: (d) => d.access === "med" || d.access === "high" },
      { label: "Heavy Visual Triggers", test: (d) => d.checkout === "lot" },
      { label: "Recovery Below 40%", test: (d) => d.recovery !== null && d.recovery !== undefined && d.recovery !== "" && Number(d.recovery) < 40 },
      { label: "Low-Purpose Day (1–2)", test: (d) => d.purposeRating !== null && d.purposeRating !== undefined && d.purposeRating <= 2 },
    ];
    return factors.map((f) => {
      const rel = relKeys.filter((k) => f.test({ ...emptyDay(), ...data.days[k] })).length / relKeys.length;
      const base = allKeys.filter((k) => f.test({ ...emptyDay(), ...data.days[k] })).length / allKeys.length;
      return { label: f.label, rel: Math.round(rel * 100), base: Math.round(base * 100) };
    }).filter((x) => x.rel > 0).sort((a, b) => (b.rel - b.base) - (a.rel - a.base)).slice(0, 5);
  })();

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
    if (!label) return;
    const id = "c" + Date.now().toString(36);
    const freq = addForm.daily ? "daily" : (addForm.days.length ? [...addForm.days].sort() : "daily");
    persist({ ...data, items: [...items, { id, label, list: addForm.list, kind: addForm.list === "prime" ? "habit" : addForm.kind, weight: addForm.weight, freq }] });
    setAddForm({ label: "", list: "prev", kind: "risk", weight: "med", daily: true, days: [] });
    setShowAdd(false);
  };
  const freqSummary = (item) =>
    item.fastingAuto ? "AUTO (MON/THU/LUNAR)" :
      item.freq === "daily" ? "DAILY" :
        Array.isArray(item.freq) && item.freq.length ? item.freq.map((d) => WD[d]).join(" ") : "DAILY";

  const NavBtn = ({ id, icon: Icon, label }) => (
    <button onClick={() => setView(id)}
      className={"flex-1 flex flex-col items-center gap-0.5 py-2 " + (view === id ? "" : "text-neutral-500")}
      style={view === id ? { color: TEAL } : undefined}>
      <Icon size={20} />
      <span className="text-[10px] uppercase tracking-wide font-semibold">{label}</span>
    </button>
  );

  const ItemEditorRow = ({ item }) => (
    <div className="py-2.5 border-b border-neutral-800 last:border-0">
      <button onClick={() => setExpandedItem(expandedItem === item.id ? null : item.id)} className="w-full flex items-center justify-between text-left">
        <div className="pr-2">
          <div className="text-sm text-neutral-200 uppercase tracking-wide font-semibold">{item.label}</div>
          <div className="text-xs text-neutral-500 mt-0.5">{(item.kind === "risk" ? "RISK" : "PROTECTIVE") + " · " + item.weight.toUpperCase() + " · " + freqSummary(item)}</div>
        </div>
        <Pencil size={14} className="text-neutral-600 shrink-0" />
      </button>
      {expandedItem === item.id && (
        <div className="mt-3 space-y-3">
          {item.list === "prev" && (
            <div>
              <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5">Type</div>
              <Seg value={item.kind} allowClear={false} onChange={(v) => v && updateItem(item.id, { kind: v })}
                options={[{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }]} />
            </div>
          )}
          <div>
            <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5">Weight</div>
            <Seg value={item.weight} allowClear={false} onChange={(v) => v && updateItem(item.id, { weight: v })}
              options={[{ v: "low", label: "Low" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }]} />
          </div>
          {!item.fastingAuto && (
            <div>
              <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5">Days</div>
              <button onClick={() => updateItem(item.id, { freq: "daily" })}
                className={"px-3 py-1.5 rounded-lg text-xs uppercase border mb-1.5 " + (item.freq === "daily" ? "font-bold text-neutral-950" : "border-neutral-700 text-neutral-400")}
                style={item.freq === "daily" ? { background: TEAL, borderColor: TEAL } : undefined}>
                Every Day
              </button>
              <div className="flex gap-1">
                {WD.map((w, i) => {
                  const on = Array.isArray(item.freq) && item.freq.includes(i);
                  return (
                    <button key={w} onClick={() => toggleItemDay(Array.isArray(item.freq) ? item : { ...item, freq: [] }, i)}
                      className={"flex-1 py-1.5 rounded-lg text-xs border " + (on ? "bg-neutral-200 border-neutral-200 text-neutral-950 font-bold" : "border-neutral-700 text-neutral-500")}>
                      {w}
                    </button>
                  );
                })}
              </div>
            </div>
          )}
          <button onClick={() => { deleteItem(item.id); setExpandedItem(null); }} className="text-xs text-rose-400 flex items-center gap-1 uppercase tracking-wide">
            <Trash2 size={13} /> Remove Item
          </button>
        </div>
      )}
    </div>
  );

  return (
    <div className="min-h-screen bg-neutral-950 text-neutral-200 pb-24" style={{ WebkitTapHighlightColor: "transparent" }}>
      {breathing && <Breathe purposeText={data.settings.purposeText} onClose={() => setBreathing(false)} />}

      <div className="max-w-md mx-auto px-4 pt-6">

        {/* ============ TODAY ============ */}
        {view === "today" && (
          <>
            <div className="flex items-center gap-1.5 mb-1">
              <div className="w-6 h-6 rounded-md" style={{ background: AMBER }} />
              <span className="text-xs font-bold tracking-[0.3em]" style={{ color: AMBER }}>BULL</span>
            </div>
            <div className="flex items-start justify-between">
              <div>
                <div className="font-serif text-2xl text-neutral-100">{now.toLocaleDateString(undefined, { weekday: "long" })}</div>
                <div className="text-sm text-neutral-500">
                  {now.toLocaleDateString(undefined, { day: "numeric", month: "long" })}
                  {fastToday && <span style={{ color: AMBER }}> · FASTING DAY</span>}
                </div>
                <div className="flex items-center gap-1.5 mt-2" style={{ color: AMBER }}>
                  <Flame size={16} />
                  <span className="font-mono text-sm font-bold">{streak} DAY{streak === 1 ? "" : "S"} CLEAN</span>
                </div>
              </div>
              <div className="flex gap-4">
                <Ring pct={risk} color={riskColor(risk)} label="Risk" />
                <Ring pct={vigourPct} color={AMBER} label="Vigour" />
              </div>
            </div>

            <button onClick={logUrge}
              className="w-full mt-5 py-4 rounded-2xl font-bold text-lg text-neutral-950 flex items-center justify-center gap-2 shadow-lg active:scale-95 transition-transform uppercase tracking-wide"
              style={{ background: TEAL }}>
              <Wind size={22} /> Urge — Tap To Ride It Out
            </button>
            <div className="text-center text-xs text-neutral-500 mt-1.5 uppercase tracking-wide">
              {data.urges.length} urge{data.urges.length === 1 ? "" : "s"} survived all-time
            </div>

            {justRelapsed && (
              <Card className="mt-4 border-neutral-700">
                <div className="text-sm text-neutral-300 leading-relaxed">
                  Logged. This is data now — it makes you sharper. Reset protocol: water, shower, out of the house, consider fasting tomorrow. Streak restarts today.
                </div>
                <button onClick={() => setJustRelapsed(false)} className="mt-2 text-xs text-neutral-500 uppercase tracking-wide">Dismiss</button>
              </Card>
            )}

            {/* ================= PREVENTION ================= */}
            <GroupHeader icon={Shield} color={TEAL}>Relapse Prevention</GroupHeader>

            <SectionLabel>Morning Intention</SectionLabel>
            <Card>
              {today.intentionSet ? (
                <div className="flex items-start gap-2">
                  <Check size={18} style={{ color: TEAL }} className="mt-0.5 shrink-0" />
                  <div className="text-sm text-neutral-300">{today.intentionText || "Intention set."}</div>
                </div>
              ) : (
                <div className="flex gap-2">
                  <input value={today.intentionText} onChange={(e) => setDay("intentionText", e.target.value)}
                    placeholder="One purposeful thing today…"
                    className="flex-1 bg-neutral-800 rounded-xl px-3 py-2 text-sm outline-none placeholder-neutral-600" />
                  <button onClick={() => setDay("intentionSet", true)} className="px-4 rounded-xl text-neutral-950 text-sm font-bold uppercase" style={{ background: TEAL }}>Set</button>
                </div>
              )}
            </Card>

            <SectionLabel>Accountability Check-In</SectionLabel>
            <Card className={therapistStatus !== "scheduled" ? "border-amber-400" : ""}>
              <div className="text-sm text-neutral-300">
                {therapistStatus === "setup"
                  ? "Nothing scheduled. Your accountability partner holds you to all three areas — prevention, vigour, purpose."
                  : therapistStatus === "overdue"
                    ? "That date has passed. Schedule the next one."
                    : therapistStatus === "outside"
                      ? "Scheduled, but further out than your " + (data.settings.therapistEveryWeeks || 2) + "-week target — this still raises risk."
                      : "Scheduled — " + new Date(data.settings.nextCheckin).toLocaleString(undefined, { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}
              </div>
              <div className="text-xs uppercase tracking-wide text-neutral-500 mt-3 mb-1">Next Check-In Date & Time</div>
              <div className="flex gap-2">
                <input type="datetime-local"
                  value={data.settings.nextCheckin ? new Date(data.settings.nextCheckin - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16) : ""}
                  onChange={(e) => {
                    const v = e.target.value;
                    setSetting("nextCheckin", v ? new Date(v).getTime() : null);
                  }}
                  className="flex-1 bg-neutral-800 rounded-xl px-3 py-2 text-sm outline-none text-neutral-100" />
                {data.settings.nextCheckin && (
                  <button onClick={() => setSetting("nextCheckin", null)}
                    className="px-3 rounded-xl bg-neutral-800 text-neutral-400 text-xs uppercase tracking-wide">Clear</button>
                )}
              </div>
              <div className="text-xs text-neutral-500 mt-1">A date booked within your check-in window keeps risk unaffected — nothing scheduled, overdue, or too far out all raise it.</div>
            </Card>

            <SectionLabel>Risk Factors Today</SectionLabel>
            <Card>
              {prevRisks.map((it) => (
                <YesNo key={it.id} mode="risk" label={it.label} sub={it.sub}
                  value={today.checks[it.id] === undefined ? null : today.checks[it.id]}
                  onChange={(v) => setCheck(it.id, v)} />
              ))}
              <div className="py-2.5 border-b border-neutral-800">
                <div className="text-xs uppercase tracking-wide text-neutral-300 mb-2 font-semibold">Content Access Today</div>
                <Seg value={today.access} onChange={(v) => setDay("access", v)}
                  options={[{ v: "low", label: "Low", tone: "teal" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }]} />
              </div>
              <div className="py-2.5">
                <div className="text-xs uppercase tracking-wide text-neutral-300 mb-2 font-semibold">Checking Out Women</div>
                <Seg value={today.checkout} onChange={(v) => setDay("checkout", v)}
                  options={[{ v: "none", label: "None", tone: "teal" }, { v: "few", label: "A Few", tone: "warn" }, { v: "lot", label: "A Lot", tone: "risk" }]} />
              </div>
            </Card>

            {prevHabits.length > 0 && (
              <>
                <SectionLabel>Protective Habits</SectionLabel>
                <Card>
                  {prevHabits.map((it) => (
                    <YesNo key={it.id} mode="protective" label={it.label} sub={it.sub}
                      value={today.checks[it.id] === true} onChange={(v) => setCheck(it.id, v)} />
                  ))}
                </Card>
              </>
            )}

            <SectionLabel>Recovery</SectionLabel>
            <Card>
              <NumField label="Recovery Score" value={today.recovery} onChange={(v) => setDay("recovery", v)} suffix="%" />
            </Card>

            <SectionLabel>Evening Review</SectionLabel>
            <Card>
              <div className="text-xs uppercase tracking-wide text-neutral-300 mb-2 font-semibold">How Meaningful Did Today Feel</div>
              <div className="flex gap-2">
                {[1, 2, 3, 4, 5].map((n) => (
                  <button key={n} onClick={() => setDay("purposeRating", today.purposeRating === n ? null : n)}
                    className={"flex-1 py-2.5 rounded-xl border text-base font-mono font-bold transition-colors " +
                      (today.purposeRating === n ? "bg-neutral-200 text-neutral-950 border-neutral-200" : "border-neutral-700 text-neutral-400")}>
                    {n}
                  </button>
                ))}
              </div>
            </Card>

            {/* ================= VIGOUR ================= */}
            <GroupHeader icon={Zap} color={AMBER}>Sexual Vigour</GroupHeader>

            <SectionLabel>Priming Actions</SectionLabel>
            <Card>
              {primeToday.map((it) => (
                <YesNo key={it.id} mode="vigour"
                  label={it.fastingAuto && fastToday ? it.label + " (Suggested Today)" : it.label} sub={it.sub}
                  value={today.checks[it.id] === true} onChange={(v) => setCheck(it.id, v)} />
              ))}
            </Card>

            <SectionLabel>Supplements</SectionLabel>
            <Card>
              <div className="flex flex-wrap gap-2">
                {data.settings.supplements.map((s) => {
                  const on = !!(today.supplementsTaken && today.supplementsTaken[s]);
                  return (
                    <button key={s} onClick={() => setDay("supplementsTaken", { ...today.supplementsTaken, [s]: !on })}
                      className={"px-3 py-1.5 rounded-full text-xs uppercase tracking-wide border transition-colors font-semibold " +
                        (on ? "text-neutral-950 font-bold" : "border-neutral-700 text-neutral-400")}
                      style={on ? { background: AMBER, borderColor: AMBER } : undefined}>
                      {s}
                    </button>
                  );
                })}
              </div>
            </Card>

            <SectionLabel>Sleep</SectionLabel>
            <Card>
              <NumField label="Sleep Score" value={today.sleep} onChange={(v) => setDay("sleep", v)} suffix="%" />
            </Card>

            <div className="mt-8 text-center">
              {!confirmRelapse ? (
                <button onClick={() => setConfirmRelapse(true)} className="text-xs text-neutral-600 underline uppercase tracking-wide">Log A Relapse</button>
              ) : (
                <Card>
                  <div className="text-sm text-neutral-300 mb-3">Log a relapse now? Honesty keeps the data — and you — sharp.</div>
                  <div className="flex gap-2">
                    <button onClick={logRelapse} className="flex-1 py-2.5 rounded-xl bg-rose-500 text-neutral-50 text-sm font-bold uppercase">Yes, Log It</button>
                    <button onClick={() => setConfirmRelapse(false)} className="flex-1 py-2.5 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase">Cancel</button>
                  </div>
                </Card>
              )}
            </div>
          </>
        )}

        {/* ============ STATS ============ */}
        {view === "stats" && st && (
          <>
            <div className="font-serif text-2xl text-neutral-100 mb-4">Patterns</div>
            <Seg value={period} allowClear={false} onChange={(v) => v && setPeriod(v)}
              options={[{ v: "D", label: "Day" }, { v: "W", label: "Week" }, { v: "M", label: "Month" }, { v: "Y", label: "Year" }, { v: "A", label: "All" }]} />

            <div className="grid grid-cols-2 gap-3 mt-4">
              <Card><div className="text-xs uppercase tracking-wide text-neutral-500">Avg Risk</div>
                <div className="font-mono text-2xl font-bold mt-1" style={{ color: st.avgRisk === null ? "#e5e5e5" : riskColor(st.avgRisk) }}>{st.avgRisk === null ? "—" : Math.round(st.avgRisk)}</div></Card>
              <Card><div className="text-xs uppercase tracking-wide text-neutral-500">Vigour</div>
                <div className="font-mono text-2xl font-bold mt-1" style={{ color: AMBER }}>{st.vigour === null ? "—" : Math.round(st.vigour) + "%"}</div></Card>
              <Card><div className="text-xs uppercase tracking-wide text-neutral-500">Urges Survived</div>
                <div className="font-mono text-2xl font-bold mt-1" style={{ color: TEAL }}>{st.urges}</div></Card>
              <Card><div className="text-xs uppercase tracking-wide text-neutral-500">Relapses</div>
                <div className="font-mono text-2xl font-bold text-neutral-100 mt-1">{st.relapses}</div></Card>
              <Card><div className="text-xs uppercase tracking-wide text-neutral-500">Current Streak</div>
                <div className="font-mono text-2xl font-bold mt-1" style={{ color: AMBER }}>{streak}D</div></Card>
              <Card><div className="text-xs uppercase tracking-wide text-neutral-500">Best Streak</div>
                <div className="font-mono text-2xl font-bold text-neutral-100 mt-1">{bestStreak}D</div></Card>
            </div>

            <SectionLabel>Last 14 Days</SectionLabel>
            <Card>
              <div className="flex gap-1.5 justify-between">
                {last14.map((d) => (
                  <div key={d.k} title={d.k} className="flex-1 h-9 rounded"
                    style={{ background: d.rel ? ROSE : !d.logged ? "#292524" : riskColor(d.score) }} />
                ))}
              </div>
              <div className="text-xs text-neutral-500 mt-2 uppercase tracking-wide">Teal safe · Amber caution · Red risk/relapse · Grey unlogged</div>
            </Card>

            <SectionLabel>Relapse Patterns</SectionLabel>
            <Card>
              {correlations === null ? (
                <div className="text-sm text-neutral-400">Patterns unlock after 3 logged relapse days. Ideally this stays locked forever — but if slips happen, this is where they start paying you back.</div>
              ) : correlations.length === 0 ? (
                <div className="text-sm text-neutral-400">Not enough factor data on relapse days yet. Keep the daily check-ins going.</div>
              ) : (
                correlations.map((c) => (
                  <div key={c.label} className="py-2 border-b border-neutral-800 last:border-0">
                    <div className="text-sm text-neutral-200 uppercase tracking-wide font-semibold">{c.label}</div>
                    <div className="text-xs text-neutral-500">Present on {c.rel}% of relapse days · {c.base}% of all days</div>
                  </div>
                ))
              )}
            </Card>
          </>
        )}

        {/* ============ GUIDE ============ */}
        {view === "guide" && (
          <>
            <div className="font-serif text-2xl text-neutral-100 mb-4">Guide</div>
            {GUIDE.map((g, i) => (
              <Card key={g.t} className="mb-2.5">
                <button onClick={() => setOpenGuide(openGuide === i ? null : i)} className="w-full flex items-center justify-between text-left">
                  <span className="text-sm font-bold uppercase tracking-wide text-neutral-200">{g.t}</span>
                  <ChevronDown size={16} className={"text-neutral-500 transition-transform " + (openGuide === i ? "rotate-180" : "")} />
                </button>
                {openGuide === i && <p className="text-sm text-neutral-400 mt-2 leading-relaxed">{g.b}</p>}
              </Card>
            ))}
          </>
        )}

        {/* ============ SETTINGS ============ */}
        {view === "settings" && (
          <>
            <div className="font-serif text-2xl text-neutral-100 mb-4">Settings</div>

            <SectionLabel>Your Purpose Card</SectionLabel>
            <Card>
              <textarea value={data.settings.purposeText} onChange={(e) => setSetting("purposeText", e.target.value)} rows={6}
                className="w-full bg-neutral-800 rounded-xl px-3 py-2 text-sm outline-none text-neutral-200 leading-relaxed" />
              <div className="text-xs text-neutral-500 mt-1">Shown the moment you tap the Urge button. Write it in your own words.</div>
            </Card>

            <SectionLabel>Prevention Checklist Items</SectionLabel>
            <Card>{items.filter((i) => i.list === "prev").map((it) => <ItemEditorRow key={it.id} item={it} />)}</Card>

            <SectionLabel>Vigour Checklist Items</SectionLabel>
            <Card>{items.filter((i) => i.list === "prime").map((it) => <ItemEditorRow key={it.id} item={it} />)}</Card>

            <div className="mt-3">
              {!showAdd ? (
                <button onClick={() => setShowAdd(true)} className="w-full py-3 rounded-2xl border border-dashed border-neutral-700 text-neutral-400 text-sm flex items-center justify-center gap-1.5 uppercase tracking-wide">
                  <Plus size={16} /> Add An Item
                </button>
              ) : (
                <Card>
                  <input value={addForm.label} onChange={(e) => setAddForm({ ...addForm, label: e.target.value })} placeholder="Item name…"
                    className="w-full bg-neutral-800 rounded-xl px-3 py-2 text-sm outline-none placeholder-neutral-600 mb-3" />
                  <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5">List</div>
                  <Seg value={addForm.list} allowClear={false} onChange={(v) => v && setAddForm({ ...addForm, list: v })}
                    options={[{ v: "prev", label: "Prevention" }, { v: "prime", label: "Vigour" }]} />
                  {addForm.list === "prev" && (
                    <>
                      <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5 mt-3">Type</div>
                      <Seg value={addForm.kind} allowClear={false} onChange={(v) => v && setAddForm({ ...addForm, kind: v })}
                        options={[{ v: "risk", label: "Risk", tone: "risk" }, { v: "habit", label: "Protective", tone: "teal" }]} />
                    </>
                  )}
                  <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5 mt-3">Weight</div>
                  <Seg value={addForm.weight} allowClear={false} onChange={(v) => v && setAddForm({ ...addForm, weight: v })}
                    options={[{ v: "low", label: "Low" }, { v: "med", label: "Med", tone: "warn" }, { v: "high", label: "High", tone: "risk" }]} />
                  <div className="text-xs uppercase tracking-wide text-neutral-500 mb-1.5 mt-3">Days</div>
                  <div className="flex gap-1 mb-1.5">
                    <button onClick={() => setAddForm({ ...addForm, daily: true })}
                      className={"px-3 py-1.5 rounded-lg text-xs uppercase border " + (addForm.daily ? "font-bold text-neutral-950" : "border-neutral-700 text-neutral-400")}
                      style={addForm.daily ? { background: TEAL, borderColor: TEAL } : undefined}>Every Day</button>
                    <button onClick={() => setAddForm({ ...addForm, daily: false })}
                      className={"px-3 py-1.5 rounded-lg text-xs uppercase border " + (!addForm.daily ? "bg-neutral-200 border-neutral-200 text-neutral-950 font-bold" : "border-neutral-700 text-neutral-400")}>
                      Specific Days
                    </button>
                  </div>
                  {!addForm.daily && (
                    <div className="flex gap-1">
                      {WD.map((w, i) => {
                        const on = addForm.days.includes(i);
                        return (
                          <button key={w} onClick={() => setAddForm({ ...addForm, days: on ? addForm.days.filter((d) => d !== i) : [...addForm.days, i] })}
                            className={"flex-1 py-1.5 rounded-lg text-xs border " + (on ? "bg-neutral-200 border-neutral-200 text-neutral-950 font-bold" : "border-neutral-700 text-neutral-500")}>
                            {w}
                          </button>
                        );
                      })}
                    </div>
                  )}
                  <div className="flex gap-2 mt-4">
                    <button onClick={addItem} className="flex-1 py-2.5 rounded-xl text-neutral-950 text-sm font-bold uppercase" style={{ background: TEAL }}>Add Item</button>
                    <button onClick={() => setShowAdd(false)} className="flex-1 py-2.5 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase">Cancel</button>
                  </div>
                </Card>
              )}
            </div>

            <SectionLabel>Supplements</SectionLabel>
            <Card>
              {data.settings.supplements.map((s) => (
                <div key={s} className="flex items-center justify-between py-2 border-b border-neutral-800 last:border-0">
                  <span className="text-sm text-neutral-300 uppercase tracking-wide">{s}</span>
                  <button onClick={() => setSetting("supplements", data.settings.supplements.filter((x) => x !== s))}>
                    <Trash2 size={15} className="text-neutral-600" />
                  </button>
                </div>
              ))}
              <div className="flex gap-2 mt-3">
                <input value={newSup} onChange={(e) => setNewSup(e.target.value)} placeholder="Add supplement…"
                  className="flex-1 bg-neutral-800 rounded-xl px-3 py-2 text-sm outline-none placeholder-neutral-600" />
                <button onClick={() => { const v = newSup.trim(); if (v && !data.settings.supplements.includes(v)) setSetting("supplements", [...data.settings.supplements, v]); setNewSup(""); }}
                  className="px-3 rounded-xl bg-neutral-200 text-neutral-950"><Plus size={16} /></button>
              </div>
            </Card>

            <SectionLabel>Accountability Frequency</SectionLabel>
            <Card>
              <Seg value={data.settings.therapistEveryWeeks} allowClear={false} onChange={(v) => v && setSetting("therapistEveryWeeks", v)}
                options={[{ v: 1, label: "Weekly" }, { v: 2, label: "2 Wks" }, { v: 3, label: "3 Wks" }, { v: 4, label: "4 Wks" }]} />
            </Card>

            <SectionLabel>Backdate Last Relapse</SectionLabel>
            <Card>
              <div className="text-xs text-neutral-500 mb-2">Already clean for a while? Set the actual date so your streak reflects reality.</div>
              <div className="flex gap-2">
                <input type="date"
                  value={data.settings.manualLastRelapseDate ? new Date(data.settings.manualLastRelapseDate - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10) : ""}
                  onChange={(e) => {
                    const v = e.target.value;
                    setSetting("manualLastRelapseDate", v ? new Date(v + "T00:00:00").getTime() : null);
                  }}
                  className="flex-1 bg-neutral-800 rounded-xl px-3 py-2 text-sm outline-none text-neutral-100" />
                {data.settings.manualLastRelapseDate && (
                  <button onClick={() => setSetting("manualLastRelapseDate", null)}
                    className="px-3 rounded-xl bg-neutral-800 text-neutral-400 text-xs uppercase tracking-wide">Clear</button>
                )}
              </div>
            </Card>

            <SectionLabel>Data</SectionLabel>
            <Card>
              {resetStep === 0 && <button onClick={() => setResetStep(1)} className="text-sm text-rose-400 uppercase tracking-wide">Reset All Data</button>}
              {resetStep === 1 && (
                <div>
                  <div className="text-sm text-neutral-300 mb-2">This wipes every log, urge, relapse, item and setting. Sure?</div>
                  <div className="flex gap-2">
                    <button onClick={async () => {
                      await storageClear(); setResetStep(0);
                      persist({ version: 5, settings: { ...DEFAULT_SETTINGS }, items: DEFAULT_ITEMS.map((i) => ({ ...i, freq: Array.isArray(i.freq) ? [...i.freq] : i.freq })), days: {}, urges: [], relapses: [], firstUse: Date.now() });
                    }} className="flex-1 py-2 rounded-xl bg-rose-500 text-neutral-50 text-sm font-bold uppercase">Wipe Everything</button>
                    <button onClick={() => setResetStep(0)} className="flex-1 py-2 rounded-xl bg-neutral-800 text-neutral-300 text-sm uppercase">Cancel</button>
                  </div>
                </div>
              )}
              <div className="text-xs text-neutral-600 mt-3">Stored privately in this app's own storage. Nothing leaves your device unless you export it.</div>
            </Card>
          </>
        )}
      </div>

      <div className="fixed bottom-0 inset-x-0 bg-neutral-950 border-t border-neutral-800">
        <div className="max-w-md mx-auto flex">
          <NavBtn id="today" icon={Shield} label="Today" />
          <NavBtn id="stats" icon={BarChart3} label="Patterns" />
          <NavBtn id="guide" icon={BookOpen} label="Guide" />
          <NavBtn id="settings" icon={SettingsIcon} label="Settings" />
        </div>
      </div>
    </div>
  );
}

import { createRoot } from "react-dom/client";
createRoot(document.getElementById("root")).render(<App />);

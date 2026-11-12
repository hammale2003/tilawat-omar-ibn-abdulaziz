/* تلاوات عمر بن عبد العزيز — web player.
 *
 * Mirrors the Flutter app: one recording at a time, an explicit "what plays
 * next" rule, per-recording resume, and nothing ever leaving the device.
 *
 * Offline audio is kept as a Blob in IndexedDB rather than in a Cache the
 * service worker replays. A blob: URL gives the browser the whole file, so
 * seeking works without hand-rolling HTTP Range replies — which is what
 * breaks audio in a service worker on iOS.
 */

const $ = (s) => document.querySelector(s);
const $$ = (s) => Array.from(document.querySelectorAll(s));

/* ---------- formatting ---------- */

const AR_DIGITS = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
const arabicDigits = (n) => String(n).split('').map((c) => (c >= '0' && c <= '9' ? AR_DIGITS[+c] : c)).join('');

function fmt(total) {
  if (!isFinite(total) || total < 0) total = 0;
  const s = Math.floor(total % 60), m = Math.floor(total / 60) % 60, h = Math.floor(total / 3600);
  const p = (n) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${p(m)}:${p(s)}` : `${p(m)}:${p(s)}`;
}
const ltr = (s) => `<span dir="ltr">${s}</span>`;
const mb = (bytes) => (bytes / 1e6).toFixed(bytes < 1e7 ? 1 : 0);

/* Strips harakat and unifies alif/ya/ta-marbuta, so "الاخلاص" finds "الإخلاص". */
const normalise = (s) => s
  .replace(/[ً-ْـ]/g, '')
  .replace(/[إأآا]/g, 'ا')
  .replace(/ى/g, 'ي')
  .replace(/ة/g, 'ه');

/* ---------- stored preferences (device-only, same shape as Prefs) ---------- */

const Store = {
  get(k, d) { try { const v = localStorage.getItem(k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} },
  del(k) { try { localStorage.removeItem(k); } catch {} },
};

const Prefs = {
  get last() { return Store.get('last_recording', null); },
  set last(v) { Store.set('last_recording', v); },
  posFor(id) { return Store.get('pos_' + id, 0); },
  savePos(id, secs) { Store.set('pos_' + id, secs); },
  clearPos(id) { Store.del('pos_' + id); },
  get speed() { return Store.get('speed', 1); },
  set speed(v) { Store.set('speed', v); },
  get repeat() { return Store.get('repeat_mode', 0); },
  set repeat(v) { Store.set('repeat_mode', v); },
  get section() { return Store.get('section', 'surahs'); },
  set section(v) { Store.set('section', v); },
  get bookmarks() { return Store.get('bookmarks', []); },
  set bookmarks(v) { Store.set('bookmarks', v); },
  get theme() { return Store.get('theme', 'system'); },
  set theme(v) { Store.set('theme', v); },
};

/* ---------- saved audio ---------- */

const DB = {
  _p: null,
  open() {
    if (!this._p) {
      this._p = new Promise((res, rej) => {
        const r = indexedDB.open('tilawa', 1);
        r.onupgradeneeded = () => r.result.createObjectStore('audio');
        r.onsuccess = () => res(r.result);
        r.onerror = () => rej(r.error);
      }).catch(() => null);
    }
    return this._p;
  },
  async _tx(mode, fn) {
    const db = await this.open();
    if (!db) return undefined;
    return new Promise((res, rej) => {
      const req = fn(db.transaction('audio', mode).objectStore('audio'));
      req.onsuccess = () => res(req.result);
      req.onerror = () => rej(req.error);
    }).catch(() => undefined);
  },
  get(id) { return this._tx('readonly', (s) => s.get(id)); },
  put(id, blob) { return this._tx('readwrite', (s) => s.put(blob, id)); },
  del(id) { return this._tx('readwrite', (s) => s.delete(id)); },
  keys() { return this._tx('readonly', (s) => s.getAllKeys()); },
  clear() { return this._tx('readwrite', (s) => s.clear()); },
};

/* ---------- state ---------- */

const S = {
  reciter: null, sections: [], recordings: [], surahs: new Map(),
  section: Prefs.section, query: '',
  current: null, queue: [], playing: false,
  repeat: Prefs.repeat, speed: Prefs.speed,
  sleepAt: null, sleepTimer: null, sleepAtEnd: false,
  saved: new Set(), downloads: new Map(),
  objectUrl: null, seeking: false,
};

const audio = $('#audio');
const inSection = (id) => S.recordings.filter((r) => r.section === id);
const surahOf = (r) => (r.surahId ? S.surahs.get(r.surahId) : null);
const recById = (id) => S.recordings.find((r) => r.id === id) || null;

/* ---------- boot ---------- */

async function boot() {
  applyTheme();
  const [cat, surahs] = await Promise.all([
    fetch('catalog.json').then((r) => r.json()),
    fetch('surahs.json').then((r) => r.json()),
  ]);

  S.reciter = cat.reciter;
  S.sections = cat.sections.map((s) => ({ id: s.id, ar: s.ar, note: s.note || '' }));
  S.recordings = cat.recordings.map((j) => ({
    id: j.id, section: j.section, title: j.title, surahId: j.surah ?? null,
    url: j.url, bytes: j.bytes, secs: j.secs,
  }));
  (Array.isArray(surahs) ? surahs : surahs.surahs).forEach((s) => S.surahs.set(s.id, s));

  if (!S.sections.some((s) => s.id === S.section)) S.section = S.sections[0].id;

  const keys = await DB.keys();
  if (keys) keys.forEach((k) => S.saved.add(k));

  $('#reciter').textContent = `${S.reciter.ar} — ${S.reciter.riwaya}`;
  $('#player-reciter').textContent = S.reciter.ar;
  const hours = (S.recordings.reduce((a, r) => a + r.secs, 0) / 3600).toFixed(1);
  $('#about-counts').textContent =
    `${arabicDigits(S.recordings.length)} تلاوة · نحو ${arabicDigits(hours).replace('.', '\u066B')} ساعة`;

  renderChips();
  renderList();
  updateDownloadsSummary();

  const last = Prefs.last && recById(Prefs.last);
  if (last) { S.queue = visible(); load(last, { autoplay: false }); }

  wire();
  registerSW();
  setTimeout(maybeOfferInstall, 2500);
}

/* ---------- list ---------- */

function visible() {
  const list = inSection(S.section);
  const q = S.query.trim();
  if (!q) return list;
  const n = normalise(q), lower = q.toLowerCase();
  return list.filter((r) => {
    if (normalise(r.title).includes(n)) return true;
    const s = surahOf(r);
    if (s) {
      if (normalise(s.ar).includes(n)) return true;
      if (s.en && s.en.toLowerCase().includes(lower)) return true;
      if (String(r.surahId) === q || arabicDigits(r.surahId) === q) return true;
    }
    return false;
  });
}

function starPath(r, c) {
  let d = '';
  for (let k = 0; k < 2; k++) {
    const off = (k * Math.PI) / 4;
    for (let i = 0; i < 4; i++) {
      const a = off + (i * Math.PI) / 2;
      d += (i === 0 ? 'M' : 'L') + (c + r * Math.cos(a)).toFixed(2) + ' ' + (c + r * Math.sin(a)).toFixed(2);
    }
    d += 'Z';
  }
  return d;
}
const STAR_46 = starPath(21.5, 23);

function medallion(rec) {
  return `<div class="medallion"><svg viewBox="0 0 46 46" aria-hidden="true"><path d="${STAR_46}"
    fill="none" stroke="var(--gold)" stroke-width="1.1" stroke-linejoin="round" opacity=".55"/></svg>
    <span>${rec.surahId ? arabicDigits(rec.surahId) : '۞'}</span></div>`;
}

function metaFor(rec) {
  const dur = ltr(fmt(rec.secs));
  if (rec.section === 'surahs') {
    const s = surahOf(rec);
    if (s) return `${s.place} · ${arabicDigits(s.ayahs)} آية · ${dur}`;
  }
  return `${dur} · ${ltr(mb(rec.bytes))} م.ب`;
}

function dlMarkup(rec) {
  const d = S.downloads.get(rec.id);
  if (d && d.state === 'running') {
    const pct = Math.max(0.03, d.progress);
    const C = 2 * Math.PI * 9;
    return `<span class="dl" data-state="running" data-id="${rec.id}" role="button" aria-label="إلغاء التنزيل">
      <svg class="ring" viewBox="0 0 24 24"><circle class="bg" cx="12" cy="12" r="9"/>
      <circle class="fg" cx="12" cy="12" r="9" stroke-dasharray="${C.toFixed(1)}"
        stroke-dashoffset="${(C * (1 - pct)).toFixed(1)}"/></svg></span>`;
  }
  const done = S.saved.has(rec.id);
  return `<span class="dl" data-state="${done ? 'done' : 'idle'}" data-id="${rec.id}" role="button"
    aria-label="${done ? 'محفوظة — اضغط للحذف' : 'تنزيل'}">
    <svg class="icon"><use href="#${done ? 'i-done' : 'i-download'}"></use></svg></span>`;
}

function renderList() {
  const items = visible();
  const list = $('#list');
  const cur = S.current;

  let html = '';
  const last = Prefs.last && recById(Prefs.last);
  if (last && !S.query) {
    const pos = Prefs.posFor(last.id);
    html += `<button class="continue" data-play="${last.id}">
      <span class="play"><svg class="icon"><use href="#i-play"></use></svg></span>
      <span class="ctext">
        <span class="lbl">متابعة الاستماع</span>
        <span class="t">${last.title}</span>
        <span class="m">${pos > 5 ? 'توقّفت عند ' + ltr(fmt(pos)) : 'من البداية'}</span>
      </span></button>`;
  }

  if (!items.length) {
    html += `<div class="empty">لا توجد نتائج لهذا البحث.</div>`;
  } else {
    html += items.map((r) => `<div class="row" data-id="${r.id}"
      aria-current="${cur && cur.id === r.id ? 'true' : 'false'}">
      <button class="rowbtn" data-play="${r.id}">
        ${medallion(r)}
        <span class="rowtext"><span class="t">${r.title}</span><span class="m">${metaFor(r)}</span></span>
      </button>
      ${dlMarkup(r)}
    </div>`).join('');
  }

  list.innerHTML = html;
  S.queue = items;
}

function renderChips() {
  $('#chips').innerHTML = S.sections.map((s) => `<button class="chip" role="tab" data-section="${s.id}"
    aria-selected="${s.id === S.section}">
    <svg class="icon tick"><use href="#i-check"></use></svg>
    <span>${s.ar}</span><span class="n">${arabicDigits(inSection(s.id).length)}</span></button>`).join('');
}

/* ---------- playback ---------- */

async function srcFor(rec) {
  const blob = await DB.get(rec.id);
  if (blob) {
    if (S.objectUrl) URL.revokeObjectURL(S.objectUrl);
    S.objectUrl = URL.createObjectURL(blob);
    return S.objectUrl;
  }
  return rec.url;
}

async function load(rec, { autoplay = true } = {}) {
  if (!rec) return;
  S.current = rec;
  Prefs.last = rec.id;

  audio.src = await srcFor(rec);
  audio.playbackRate = S.speed;
  const resume = Prefs.posFor(rec.id);
  if (resume > 2 && resume < rec.secs - 4) {
    const seek = () => { try { audio.currentTime = resume; } catch {} };
    audio.addEventListener('loadedmetadata', seek, { once: true });
  }

  renderPlayer();
  renderList();
  updateMini();
  setMediaMetadata(rec);

  // Not awaited: play() only settles once playback actually starts, and on a
  // slow connection that would hold up everything queued behind it.
  if (autoplay) audio.play().catch(() => {});
}

async function playRecording(id) {
  const rec = recById(id);
  if (!rec) return;
  if (S.current && S.current.id === id) { toggle(); openPlayer(); return; }
  S.queue = visible();
  openPlayer();
  await load(rec, { autoplay: true });
}

function toggle() {
  if (!S.current) return;
  if (audio.paused) audio.play().catch(() => {}); else audio.pause();
}

function step(delta) {
  if (!S.queue.length || !S.current) return;
  const i = S.queue.findIndex((r) => r.id === S.current.id);
  const list = i === -1 ? inSection(S.current.section) : S.queue;
  const at = i === -1 ? list.findIndex((r) => r.id === S.current.id) : i;
  const next = list[at + delta];
  if (next) load(next, { autoplay: true });
}

function onEnded() {
  if (S.current) Prefs.clearPos(S.current.id);
  if (S.sleepAtEnd) { stopSleep(); return; }
  if (S.repeat === 1) { audio.currentTime = 0; audio.play().catch(() => {}); return; }
  const i = S.queue.findIndex((r) => r.id === (S.current && S.current.id));
  const next = S.queue[i + 1];
  if (next) { load(next, { autoplay: true }); return; }
  if (S.repeat === 2 && S.queue.length) { load(S.queue[0], { autoplay: true }); }
}

/* ---------- lock screen ---------- */

function setMediaMetadata(rec) {
  if (!('mediaSession' in navigator)) return;
  const s = surahOf(rec);
  navigator.mediaSession.metadata = new MediaMetadata({
    title: rec.title,
    artist: S.reciter.ar,
    album: s ? `${s.ar} · ${S.reciter.riwaya}` : S.reciter.riwaya,
    artwork: [
      { src: 'art.png', sizes: '512x512', type: 'image/png' },
      { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' },
      { src: 'icons/icon-192.png', sizes: '192x192', type: 'image/png' },
    ],
  });
}

function setupMediaSession() {
  if (!('mediaSession' in navigator)) return;
  const ms = navigator.mediaSession;
  const on = (action, fn) => { try { ms.setActionHandler(action, fn); } catch {} };
  on('play', () => audio.play().catch(() => {}));
  on('pause', () => audio.pause());
  on('previoustrack', () => step(-1));
  on('nexttrack', () => step(1));
  on('seekbackward', (d) => { audio.currentTime = Math.max(0, audio.currentTime - (d.seekOffset || 10)); });
  on('seekforward', (d) => { audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + (d.seekOffset || 10)); });
  on('seekto', (d) => { if (d.fastSeek && audio.fastSeek) audio.fastSeek(d.seekTime); else audio.currentTime = d.seekTime; });
}

function updatePositionState() {
  if (!('mediaSession' in navigator) || !navigator.mediaSession.setPositionState) return;
  const dur = audio.duration;
  if (!isFinite(dur) || dur <= 0) return;
  try {
    navigator.mediaSession.setPositionState({
      duration: dur,
      position: Math.min(audio.currentTime, dur),
      playbackRate: audio.playbackRate || 1,
    });
  } catch {}
}

/* ---------- player UI ---------- */

function renderPlayer() {
  const rec = S.current;
  if (!rec) return;
  const s = surahOf(rec);

  $('#disc').innerHTML = `<svg viewBox="0 0 46 46" aria-hidden="true"><path d="${STAR_46}"
    fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>
    <span>${rec.surahId ? arabicDigits(rec.surahId) : '۞'}</span>`;
  $('#now-title').textContent = rec.title;
  $('#now-meta').innerHTML = s && rec.section === 'surahs'
    ? `${s.place} · ${arabicDigits(s.ayahs)} آية`
    : (s ? `من ${s.ar}` : S.reciter.riwaya);

  $('#btn-bookmark').firstElementChild.firstElementChild
    .setAttribute('href', Prefs.bookmarks.includes(rec.id) ? '#i-bookmark-on' : '#i-bookmark');
  $('#btn-bookmark').style.color = Prefs.bookmarks.includes(rec.id) ? 'var(--primary)' : '';
  $('#btn-dl').style.color = S.saved.has(rec.id) ? 'var(--primary)' : '';
  $('#btn-dl').firstElementChild.firstElementChild
    .setAttribute('href', S.saved.has(rec.id) ? '#i-done' : '#i-download');

  $('#t-dur').textContent = fmt(audio.duration || rec.secs);
  updateRepeatUI();
  updateSpeedUI();
  updatePlayIcons();
}

function updatePlayIcons() {
  const href = S.playing ? '#i-pause' : '#i-play';
  $('#b-play').firstElementChild.firstElementChild.setAttribute('href', href);
  $('#b-play').setAttribute('aria-label', S.playing ? 'إيقاف مؤقّت' : 'تشغيل');
  $('#mini-toggle').firstElementChild.firstElementChild.setAttribute('href', href);
}

function updateMini() {
  const mini = $('#mini');
  if (!S.current) { mini.classList.remove('on'); document.body.classList.remove('mini-on'); return; }
  mini.classList.toggle('on', !$('#player').classList.contains('on'));
  document.body.classList.toggle('mini-on', mini.classList.contains('on'));
  $('#mini-title').textContent = S.current.title;
  const d = audio.duration || S.current.secs;
  $('#minibar').style.width = d ? `${Math.min(100, (audio.currentTime / d) * 100)}%` : '0%';
}

function onTime() {
  const rec = S.current;
  if (!rec) return;
  const dur = audio.duration || rec.secs;
  if (!S.seeking) {
    $('#seek').value = dur ? Math.round((audio.currentTime / dur) * 1000) : 0;
    $('#seek').style.setProperty('--pct', `${dur ? (audio.currentTime / dur) * 100 : 0}%`);
  }
  $('#t-pos').textContent = fmt(audio.currentTime);
  $('#t-dur').textContent = fmt(dur);
  updateMini();

  if (!onTime._n || Date.now() - onTime._n > 4000) {
    onTime._n = Date.now();
    if (audio.currentTime > 3) Prefs.savePos(rec.id, Math.floor(audio.currentTime));
    updatePositionState();
  }
}

const openPlayer = () => { $('#player').classList.add('on'); $('#player').setAttribute('aria-hidden', 'false'); updateMini(); };
const closePlayer = () => { $('#player').classList.remove('on'); $('#player').setAttribute('aria-hidden', 'true'); updateMini(); };

/* ---------- repeat / speed / sleep ---------- */

const REPEAT_LBL = ['تكرار', 'تكرار التلاوة', 'تكرار الكل'];
function updateRepeatUI() {
  $('#b-repeat').dataset.on = S.repeat > 0;
  $('#repeat-lbl').textContent = REPEAT_LBL[S.repeat];
  $('#b-repeat').firstElementChild.firstElementChild
    .setAttribute('href', S.repeat === 1 ? '#i-repeat1' : '#i-repeat');
}

const SPEEDS = [0.75, 1, 1.25, 1.5];
const fmtSpeed = (v) => '×' + (Number.isInteger(v) ? v.toFixed(1) : String(v));
function updateSpeedUI() {
  $('#speed-lbl').textContent = fmtSpeed(S.speed);
  $('#b-speed').dataset.on = S.speed !== 1;
}

const SLEEPS = [
  { m: 10, lbl: '١٠ دقائق' }, { m: 20, lbl: '٢٠ دقيقة' }, { m: 30, lbl: '٣٠ دقيقة' },
  { m: 60, lbl: 'ساعة' }, { end: true, lbl: 'نهاية التلاوة' },
];
let sleepIndex = -1;

function stopSleep() {
  clearTimeout(S.sleepTimer);
  S.sleepTimer = null; S.sleepAt = null; S.sleepAtEnd = false; sleepIndex = -1;
  $('#b-sleep').dataset.on = 'false';
  $('#sleep-lbl').textContent = 'مؤقّت';
  audio.pause();
}

function cycleSleep() {
  sleepIndex += 1;
  clearTimeout(S.sleepTimer);
  if (sleepIndex >= SLEEPS.length) {
    sleepIndex = -1; S.sleepAt = null; S.sleepAtEnd = false; S.sleepTimer = null;
    $('#b-sleep').dataset.on = 'false'; $('#sleep-lbl').textContent = 'مؤقّت';
    toast('أُلغي المؤقّت');
    return;
  }
  const opt = SLEEPS[sleepIndex];
  $('#b-sleep').dataset.on = 'true';
  if (opt.end) {
    S.sleepAtEnd = true; S.sleepAt = null;
    $('#sleep-lbl').textContent = 'حتى النهاية';
  } else {
    S.sleepAtEnd = false;
    S.sleepAt = Date.now() + opt.m * 60000;
    $('#sleep-lbl').textContent = opt.lbl;
    S.sleepTimer = setTimeout(stopSleep, opt.m * 60000);
  }
  toast('مؤقّت النوم: ' + opt.lbl);
}

/* ---------- downloads ---------- */

async function startDownload(rec) {
  if (S.downloads.get(rec.id)) return;
  const ctrl = new AbortController();
  S.downloads.set(rec.id, { state: 'running', progress: 0, ctrl });
  renderList();

  try {
    const res = await fetch(rec.url, { signal: ctrl.signal });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const total = +res.headers.get('content-length') || rec.bytes;
    const chunks = [];
    let got = 0;

    if (res.body && res.body.getReader) {
      const reader = res.body.getReader();
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
        got += value.length;
        const d = S.downloads.get(rec.id);
        if (d) { d.progress = Math.min(1, got / total); renderList(); }
      }
    } else {
      chunks.push(new Uint8Array(await res.arrayBuffer()));
    }

    const blob = new Blob(chunks, { type: 'audio/mpeg' });
    await DB.put(rec.id, blob);
    S.saved.add(rec.id);
    toast('حُفظت ' + rec.title);
  } catch (e) {
    if (e.name !== 'AbortError') toast('تعذّر التنزيل — تحقّق من الاتصال');
  } finally {
    S.downloads.delete(rec.id);
    renderList();
    renderPlayer();
    updateDownloadsSummary();
  }
}

async function removeDownload(rec) {
  await DB.del(rec.id);
  S.saved.delete(rec.id);
  if (S.current && S.current.id === rec.id && S.objectUrl) {
    const t = audio.currentTime, wasPlaying = !audio.paused;
    audio.src = rec.url;
    audio.addEventListener('loadedmetadata', () => {
      try { audio.currentTime = t; } catch {}
      if (wasPlaying) audio.play().catch(() => {});
    }, { once: true });
    URL.revokeObjectURL(S.objectUrl);
    S.objectUrl = null;
  }
  renderList(); renderPlayer(); updateDownloadsSummary();
  toast('حُذفت من الجهاز');
}

async function updateDownloadsSummary() {
  const n = S.saved.size;
  let txt = n ? `${arabicDigits(n)} تلاوة محفوظة` : 'لا شيء محفوظ بعد';
  if (n && navigator.storage && navigator.storage.estimate) {
    try {
      const { usage } = await navigator.storage.estimate();
      if (usage) txt += ` · ${mb(usage)} م.ب`;
    } catch {}
  }
  $('#dl-sub').textContent = txt;
}

/* ---------- install ---------- */

const isStandalone = () =>
  window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
const isIOS = () => {
  const ua = navigator.userAgent;
  if (/Android/i.test(ua)) return false;
  return /iPad|iPhone|iPod/.test(ua) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
};

let deferredPrompt = null;
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;
});

function installText() {
  if (isIOS()) {
    return 'في متصفّح Safari: اضغط زر المشاركة ' +
      '<svg class="shareicon icon" style="display:inline-block"><use href="#i-share"></use></svg>' +
      ' ثم اختر «إضافة إلى الشاشة الرئيسية». سيعمل التطبيق بعدها من أيقونته مباشرة، ' +
      'مع التشغيل في الخلفية وأزرار التحكّم على شاشة القفل.';
  }
  return 'أضف التطبيق إلى شاشتك الرئيسية ليفتح كتطبيق كامل، ويعمل دون إنترنت بعد تنزيل التلاوات.';
}

function maybeOfferInstall() {
  if (isStandalone() || Store.get('install_dismissed', false)) return;
  if (!isIOS() && !deferredPrompt) return;
  $('#install-text').innerHTML = installText();
  $('#install-go').hidden = !deferredPrompt;
  $('#install').classList.add('on');
}

/* ---------- theme ---------- */

function applyTheme() {
  const t = Prefs.theme;
  const root = document.documentElement;
  if (t === 'system') root.removeAttribute('data-theme');
  else root.setAttribute('data-theme', t);
  $$('#theme-seg button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.theme === t)));
  const dark = t === 'dark' || (t === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
  $$('meta[name="theme-color"]').forEach((m) => m.remove());
  const m = document.createElement('meta');
  m.name = 'theme-color';
  m.content = dark ? '#0E1412' : '#FBF8F3';
  document.head.appendChild(m);
}

/* ---------- toast ---------- */

let toastTimer;
function toast(msg) {
  const el = $('#toast');
  el.firstElementChild.textContent = msg;
  el.classList.add('on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('on'), 2200);
}

/* ---------- events ---------- */

function wire() {
  $('#chips').addEventListener('click', (e) => {
    const b = e.target.closest('[data-section]');
    if (!b) return;
    S.section = b.dataset.section;
    Prefs.section = S.section;
    renderChips();
    renderList();
  });

  const q = $('#q');
  q.addEventListener('input', () => {
    S.query = q.value;
    $('#searchbox').classList.toggle('has', !!q.value);
    renderList();
  });
  $('#clearq').addEventListener('click', () => {
    q.value = ''; S.query = ''; $('#searchbox').classList.remove('has'); renderList(); q.focus();
  });

  $('#list').addEventListener('click', (e) => {
    const dl = e.target.closest('.dl');
    if (dl) {
      const rec = recById(dl.dataset.id);
      if (!rec) return;
      const state = dl.dataset.state;
      if (state === 'running') { const d = S.downloads.get(rec.id); if (d) d.ctrl.abort(); }
      else if (state === 'done') removeDownload(rec);
      else startDownload(rec);
      return;
    }
    const play = e.target.closest('[data-play]');
    if (play) playRecording(play.dataset.play);
  });

  $('#mini-open').addEventListener('click', openPlayer);
  $('#mini-title').addEventListener('click', openPlayer);
  $('#mini-toggle').addEventListener('click', toggle);
  $('#player-close').addEventListener('click', closePlayer);

  $('#b-play').addEventListener('click', toggle);
  $('#b-next').addEventListener('click', () => step(1));
  $('#b-prev').addEventListener('click', () => {
    if (audio.currentTime > 4) { audio.currentTime = 0; return; }
    step(-1);
  });
  $('#b-back').addEventListener('click', () => { audio.currentTime = Math.max(0, audio.currentTime - 10); });
  $('#b-fwd').addEventListener('click', () => {
    audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + 10);
  });

  $('#b-repeat').addEventListener('click', () => {
    S.repeat = (S.repeat + 1) % 3; Prefs.repeat = S.repeat; updateRepeatUI();
    toast(REPEAT_LBL[S.repeat] === 'تكرار' ? 'بدون تكرار' : REPEAT_LBL[S.repeat]);
  });
  $('#b-speed').addEventListener('click', () => {
    S.speed = SPEEDS[(SPEEDS.indexOf(S.speed) + 1) % SPEEDS.length] || 1;
    Prefs.speed = S.speed; audio.playbackRate = S.speed; updateSpeedUI(); updatePositionState();
  });
  $('#b-sleep').addEventListener('click', cycleSleep);

  $('#btn-bookmark').addEventListener('click', () => {
    if (!S.current) return;
    const b = Prefs.bookmarks.slice();
    const i = b.indexOf(S.current.id);
    if (i === -1) b.push(S.current.id); else b.splice(i, 1);
    Prefs.bookmarks = b;
    renderPlayer();
    toast(i === -1 ? 'أُضيفت علامة' : 'حُذفت العلامة');
  });
  $('#btn-dl').addEventListener('click', () => {
    if (!S.current) return;
    S.saved.has(S.current.id) ? removeDownload(S.current) : startDownload(S.current);
  });

  const seek = $('#seek');
  const seekTo = () => {
    const dur = audio.duration || (S.current && S.current.secs) || 0;
    audio.currentTime = (seek.value / 1000) * dur;
  };
  seek.addEventListener('input', () => {
    S.seeking = true;
    seek.style.setProperty('--pct', `${seek.value / 10}%`);
    const dur = audio.duration || (S.current && S.current.secs) || 0;
    $('#t-pos').textContent = fmt((seek.value / 1000) * dur);
  });
  seek.addEventListener('change', () => { seekTo(); S.seeking = false; });

  $('#btn-settings').addEventListener('click', () => {
    $('#settings').classList.add('on'); $('#settings').setAttribute('aria-hidden', 'false');
    updateDownloadsSummary();
  });
  $('#settings-close').addEventListener('click', () => {
    $('#settings').classList.remove('on'); $('#settings').setAttribute('aria-hidden', 'true');
  });
  $('#theme-seg').addEventListener('click', (e) => {
    const b = e.target.closest('[data-theme]');
    if (!b) return;
    Prefs.theme = b.dataset.theme;
    applyTheme();
  });
  $('#btn-clear-dl').addEventListener('click', async () => {
    if (!S.saved.size) { toast('لا شيء محفوظ'); return; }
    await DB.clear();
    S.saved.clear();
    renderList(); renderPlayer(); updateDownloadsSummary();
    toast('حُذفت كل التنزيلات');
  });
  $('#btn-install-help').addEventListener('click', () => {
    Store.del('install_dismissed');
    $('#install-text').innerHTML = installText();
    $('#install-go').hidden = !deferredPrompt;
    $('#install').classList.add('on');
  });
  $('#install-x').addEventListener('click', () => {
    $('#install').classList.remove('on');
    Store.set('install_dismissed', true);
  });
  $('#install-go').addEventListener('click', async () => {
    if (!deferredPrompt) return;
    $('#install').classList.remove('on');
    deferredPrompt.prompt();
    deferredPrompt = null;
  });

  audio.addEventListener('play', () => { S.playing = true; updatePlayIcons(); updatePositionState(); });
  audio.addEventListener('pause', () => {
    S.playing = false; updatePlayIcons();
    if (S.current && audio.currentTime > 3) Prefs.savePos(S.current.id, Math.floor(audio.currentTime));
  });
  audio.addEventListener('timeupdate', onTime);
  audio.addEventListener('loadedmetadata', () => {
    audio.playbackRate = S.speed;
    $('#t-dur').textContent = fmt(audio.duration || 0);
    updatePositionState();
  });
  audio.addEventListener('ended', onEnded);
  audio.addEventListener('error', () => {
    if (S.current && !navigator.onLine) toast('لا يوجد اتصال — نزّل التلاوة للاستماع دون إنترنت');
  });

  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (Prefs.theme === 'system') applyTheme();
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && S.current && audio.currentTime > 3) {
      Prefs.savePos(S.current.id, Math.floor(audio.currentTime));
    }
  });

  setupMediaSession();
}

/* ---------- service worker ---------- */

function registerSW() {
  if (!('serviceWorker' in navigator)) return;
  // boot() is async, so 'load' has usually fired by the time we get here.
  const go = () => navigator.serviceWorker.register('sw.js').catch(() => {});
  if (document.readyState === 'complete') go();
  else window.addEventListener('load', go, { once: true });
}

boot();

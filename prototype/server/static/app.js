'use strict';

// One HTTP request returns BOTH autocomplete and paginated results.
// This avoids duplicate API calls for the same query.
const DEBOUNCE_MS = 400;
const CACHE_TTL_MS = 15_000;
const PAGE_SIZE = 5;
const inFlight = new Map();
const cache = new Map();

const els = {
  input: document.getElementById('search'),
  find: document.getElementById('search-button'),
  clear: document.getElementById('clear'),
  results: document.getElementById('results'),
  suggestions: document.getElementById('suggestions'),
  summary: document.getElementById('summary'),
  prev: document.getElementById('prev'),
  next: document.getElementById('next'),
  page: document.getElementById('page-status'),
  typing: document.getElementById('typing'),
  network: document.getElementById('network'),
};

let debounceTimer;
let generation = 0;
let apiRequests = 0;
let state = { query: '', page: 1, pages: 1, total: 0, loading: false };

function canonical(text) {
  return text.trim().replace(/\s+/g, ' ').toLowerCase();
}

function keyFor(query, page) {
  const params = new URLSearchParams({ q: canonical(query), page: String(page), page_size: String(PAGE_SIZE) });
  return `/api/search?${params.toString()}`;
}

function cancelObsolete(activeKey) {
  for (const [key, request] of inFlight.entries()) {
    if (key !== activeKey) {
      request.controller.abort();
      inFlight.delete(key);
    }
  }
}

function getOnce(key) {
  const cached = cache.get(key);
  if (cached && cached.expiry > Date.now()) return Promise.resolve(cached.value);
  if (cached) cache.delete(key);
  const existing = inFlight.get(key);
  if (existing) return existing.promise;

  const controller = new AbortController();
  apiRequests += 1;
  els.network.textContent = `Запросы API: ${apiRequests}`;
  const promise = fetch(key, { signal: controller.signal, headers: { Accept: 'application/json' } })
    .then(async response => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      cache.set(key, { expiry: Date.now() + CACHE_TTL_MS, value: data });
      return data;
    })
    .finally(() => {
      if (inFlight.get(key)?.promise === promise) inFlight.delete(key);
    });
  inFlight.set(key, { promise, controller });
  return promise;
}

function el(tag, cls, content) {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (content !== undefined) node.textContent = content; // no API content in innerHTML
  return node;
}

function skeleton() {
  const card = el('div', 'skeleton');
  const square = el('span', 'sk-square');
  const lines = el('div', 'sk-lines');
  for (let i = 0; i < 3; i += 1) lines.append(el('span'));
  card.append(square, lines);
  return card;
}

function showSkeletons() {
  state.loading = true;
  els.results.setAttribute('aria-busy', 'true');
  els.summary.textContent = 'Загружаем результаты…';
  els.results.replaceChildren(...Array.from({ length: PAGE_SIZE }, skeleton));
  els.prev.disabled = true;
  els.next.disabled = true;
  hideSuggestions();
}

function hideSuggestions() {
  els.suggestions.hidden = true;
  els.suggestions.replaceChildren();
  els.input.setAttribute('aria-expanded', 'false');
}

function renderSuggestions(items) {
  hideSuggestions();
  if (!state.query || state.page !== 1 || !items?.length) return;
  for (const s of items) {
    const b = el('button', '', `⌕   ${s}`);
    b.type = 'button';
    b.setAttribute('role', 'option');
    b.addEventListener('click', () => {
      els.input.value = s;
      scheduleSearch(true);
    });
    els.suggestions.append(b);
  }
  els.suggestions.hidden = false;
  els.input.setAttribute('aria-expanded', 'true');
}

function renderResults(data) {
  state.loading = false;
  state.page = data.page;
  state.pages = data.total_pages;
  state.total = data.total;
  els.results.setAttribute('aria-busy', 'false');
  els.results.replaceChildren();
  els.summary.textContent = `Найдено: ${data.total.toLocaleString('ru-RU')} · на странице: ${data.items.length}`;

  if (!data.items.length) {
    els.results.append(el('div', 'empty-state', 'По вашему запросу ничего не найдено. Попробуйте другое название.'));
  }
  for (const item of data.items) {
    const card = el('article', 'result');
    const icon = el('div', 'result-icon', item.type === 'Вещество' ? '⚗' : '◇');
    icon.setAttribute('aria-hidden', 'true');
    const info = el('div', 'result-info');
    info.append(el('h3', '', item.name), el('p', '', `${item.type} · ${item.description}`));
    card.append(icon, info, el('span', 'result-id', item.id));
    els.results.append(card);
  }
  els.page.textContent = `Страница ${data.page} из ${data.total_pages}`;
  els.prev.disabled = data.page <= 1;
  els.next.disabled = data.page >= data.total_pages;
  renderSuggestions(data.suggestions);
}

async function search(query, page = 1) {
  state.query = canonical(query);
  state.page = page;
  const current = ++generation;
  const key = keyFor(state.query, page);
  cancelObsolete(key);
  els.typing.hidden = true;
  showSkeletons();
  try {
    const data = await getOnce(key);
    if (current !== generation) return; // stale responses cannot repaint UI
    renderResults(data);
  } catch (err) {
    if (current !== generation || err?.name === 'AbortError') return;
    state.loading = false;
    els.results.setAttribute('aria-busy', 'false');
    els.results.replaceChildren(el('div', 'error-state', `Не удалось получить результаты: ${err.message}`));
    els.summary.textContent = 'Ошибка запроса';
    els.prev.disabled = true;
    els.next.disabled = true;
  }
}

function scheduleSearch(immediate = false) {
  clearTimeout(debounceTimer);
  const query = canonical(els.input.value);
  els.clear.hidden = query.length === 0;
  // Invalidate results immediately; a previous response will never paint over this query.
  ++generation;
  // Preserve an identical in-flight search; only cancel truly obsolete requests.
  cancelObsolete(keyFor(query, 1));
  hideSuggestions();
  if (query.length === 1) {
    els.typing.hidden = true;
    els.summary.textContent = 'Введите хотя бы два символа';
    els.results.setAttribute('aria-busy', 'false');
    els.results.replaceChildren(el('div', 'empty-state', 'Продолжите ввод для поиска.'));
    els.prev.disabled = true;
    els.next.disabled = true;
    return;
  }
  els.typing.hidden = immediate;
  if (immediate) search(query, 1);
  else debounceTimer = setTimeout(() => search(query, 1), DEBOUNCE_MS);
}

els.input.addEventListener('input', () => scheduleSearch());
els.input.addEventListener('keydown', e => {
  if (e.key === 'Enter') {
    e.preventDefault();
    scheduleSearch(true);
  }
  if (e.key === 'Escape') hideSuggestions();
});
els.find.addEventListener('click', () => scheduleSearch(true));
els.clear.addEventListener('click', () => {
  els.input.value = '';
  scheduleSearch(true);
  els.input.focus();
});
els.prev.addEventListener('click', () => { if (!state.loading && state.page > 1) search(state.query, state.page - 1); });
els.next.addEventListener('click', () => { if (!state.loading && state.page < state.pages) search(state.query, state.page + 1); });
document.addEventListener('pointerdown', e => {
  if (!els.suggestions.contains(e.target) && e.target !== els.input) hideSuggestions();
});

search('', 1);

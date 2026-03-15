// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only

function insertBeforeLast(node, elem) {
  node.insertBefore(elem, node.childNodes[node.childNodes.length - 2]);
}

function getLoadMore(doc) {
  return doc.querySelector(".show-more:not(.timeline-item)");
}

function getHrefs(selector) {
  return new Set([...document.querySelectorAll(selector)].map(el => el.getAttribute("href")));
}

function getTweetId(item) {
  const m = item.querySelector(".tweet-link")?.getAttribute("href")?.match(/\/status\/(\d+)/);
  return m ? m[1] : "";
}

function isDuplicate(item, hrefs) {
  return hrefs.has(item.querySelector(".tweet-link")?.getAttribute("href"));
}

const GAP = 10;

class Masonry {
  constructor(container) {
    this.container = container;
    this.colHeights = [];
    this.colCounts = [];
    this.colCount = 0;
    this._lastWidth = 0;
    this._colWidthCache = 0;
    this._items = [];
    this._revealTimer = null;
    this.container.classList.add("masonry-active");

    let resizeTimer;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => this._rebuild(), 50);
    });

    // Re-sync positions whenever images finish loading and items grow taller.
    // Must be set up before _rebuild() so initial items get observed on first pass.
    let syncTimer;
    this._observer = window.ResizeObserver ? new ResizeObserver(() => {
      clearTimeout(syncTimer);
      syncTimer = setTimeout(() => this.syncHeights(), 100);
    }) : null;

    this._rebuild();
  }

  // Reveal all items and gallery siblings (show-more, top-ref). Idempotent.
  _revealAll() {
    clearTimeout(this._revealTimer);
    for (const item of this._items) item.classList.add("masonry-visible");
    for (const el of this.container.parentElement.querySelectorAll(":scope > .show-more, :scope > .top-ref, :scope > .timeline-footer"))
      el.classList.add("masonry-visible");
  }

  // Height-primary, count-as-tiebreaker: handles both tall tweets and unloaded images.
  _pickCol() {
    return this.colHeights.reduce((min, h, i) => {
      const m = this.colHeights[min];
      return (h < m || (h === m && this.colCounts[i] < this.colCounts[min])) ? i : min;
    }, 0);
  }

  // Position items using current column state. Updates colHeights, colCounts, container height.
  _position(items, heights, colWidth) {
    for (let i = 0; i < items.length; i++) {
      const col = this._pickCol();
      items[i].style.left = `${col * (colWidth + GAP)}px`;
      items[i].style.top = `${this.colHeights[col]}px`;
      this.colHeights[col] += heights[i] + GAP;
      this.colCounts[col]++;
    }
    this.container.style.height = `${Math.max(0, ...this.colHeights)}px`;
  }

  // Full reset and re-place all items.
  _place(items, heights, n, colWidth) {
    this.colHeights = new Array(n).fill(0);
    this.colCounts = new Array(n).fill(0);
    this.colCount = n;
    this._position(items, heights, colWidth);
  }

  _rebuild() {
    const n = Math.max(1, Math.floor(this.container.clientWidth / 350));
    const w = this.container.clientWidth;
    if (n === this.colCount && w === this._lastWidth) return;

    const isFirst = this.colCount === 0;

    if (isFirst) {
      this._items = [...this.container.querySelectorAll(".timeline-item")];
    }

    // Sort newest-first by tweet ID (snowflake IDs exceed Number precision, compare as strings).
    this._items.sort((a, b) => {
      const idA = getTweetId(a), idB = getTweetId(b);
      if (idA.length !== idB.length) return idB.length - idA.length;
      return idB < idA ? -1 : idB > idA ? 1 : 0;
    });

    // Pre-set widths BEFORE reading heights so measurements reflect the new column width.
    const colWidth = this._colWidthCache = Math.floor((w - GAP * (n - 1)) / n);
    for (const item of this._items) item.style.width = `${colWidth}px`;

    this._place(this._items, this._items.map(item => item.offsetHeight), n, colWidth);
    this._lastWidth = w;

    if (isFirst) {
      if (this._observer) this._items.forEach(item => this._observer.observe(item));
      // Reveal immediately if all images are cached, else wait for syncHeights.
      const hasUnloaded = this._items.some(item =>
        [...item.querySelectorAll("img")].some(img => !img.complete));
      if (hasUnloaded) {
        this._revealTimer = setTimeout(() => this._revealAll(), 1000);
      } else {
        this._revealAll();
      }
    }
  }

  // Re-read actual heights and re-place all items. Fixes drift after images load.
  syncHeights() {
    this._place(this._items, this._items.map(item => item.offsetHeight), this.colCount, this._colWidthCache);
    this._revealAll();
  }

  // Batch-add items in three phases to avoid O(N) reflows:
  //   1. writes: set widths, append all — no reads, no reflows
  //   2. one read: batch offsetHeight
  //   3. writes: assign columns, set left/top
  addAll(newItems) {
    if (!newItems.length) return;
    const colWidth = this._colWidthCache;

    for (const item of newItems) {
      item.style.width = `${colWidth}px`;
      this.container.appendChild(item);
    }

    this._position(newItems, newItems.map(item => item.offsetHeight), colWidth);
    this._items.push(...newItems);

    if (this._observer) newItems.forEach(item => this._observer.observe(item));
  }
}

document.addEventListener("DOMContentLoaded", function () {
  const isTweet = location.pathname.includes("/status/");
  const containerClass = isTweet ? ".replies" : ".timeline";
  const itemClass = containerClass + " > div:not(.top-ref)";
  const html = document.documentElement;
  const container = document.querySelector(containerClass);
  const masonryEl = container?.querySelector(".gallery-masonry");
  const masonry = masonryEl ? new Masonry(masonryEl) : null;
  let loading = false;

  function handleScroll(failed) {
    if (loading || html.scrollTop + html.clientHeight < html.scrollHeight - 3000) return;

    const loadMore = getLoadMore(document);
    if (!loadMore) return;
    loading = true;
    loadMore.children[0].text = "Loading...";

    const url = new URL(loadMore.children[0].href);
    url.searchParams.append("scroll", "true");

    fetch(url)
      .then(r => {
        if (r.status > 299) throw new Error("error");
        return r.text();
      })
      .then(responseText => {
        const doc = new DOMParser().parseFromString(responseText, "text/html");
        loadMore.remove();

        if (masonry) {
          masonry.syncHeights();
          const newMasonry = doc.querySelector(".gallery-masonry");
          if (newMasonry) {
            const knownHrefs = getHrefs(".gallery-masonry .tweet-link");
            masonry.addAll([...newMasonry.querySelectorAll(".timeline-item")].filter(item => !isDuplicate(item, knownHrefs)));
          }
        } else {
          const knownHrefs = getHrefs(`${itemClass} .tweet-link`);
          for (const item of doc.querySelectorAll(itemClass)) {
            if (item.className === "timeline-item show-more" || isDuplicate(item, knownHrefs)) continue;
            isTweet ? container.appendChild(item) : insertBeforeLast(container, item);
          }
        }

        loading = false;
        const newLoadMore = getLoadMore(doc);
        if (newLoadMore) {
          isTweet ? container.appendChild(newLoadMore) : insertBeforeLast(container, newLoadMore);
          if (masonry) newLoadMore.classList.add("masonry-visible");
        }
      })
      .catch(err => {
        console.warn("Something went wrong.", err);
        if (failed > 3) { loadMore.children[0].text = "Error"; return; }
        loading = false;
        handleScroll((failed || 0) + 1);
      });
  }

  window.addEventListener("scroll", () => handleScroll());
});
// @license-end

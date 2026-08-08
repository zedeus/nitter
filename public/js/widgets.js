/**
 * Drop-in replacement for Twitter's widgets.js
 * Converts twitter-tweet/twitter-video blockquotes to Nitter embeds
 *
 * Usage: LibRedirect can redirect platform.twitter.com/widgets.js to nitter.net/widgets.js
 */
(function () {
  "use strict";

  // Idempotent - only run once
  if (window.__nitterWidgets) return;
  window.__nitterWidgets = true;

  // Determine Nitter instance URL from script src, or fall back to current origin
  var scripts = document.querySelectorAll('script[src*="widgets.js"]');
  var NITTER = scripts.length
    ? new URL(scripts[scripts.length - 1].src).origin
    : location.origin;

  var TWEET_PATTERN = /(?:twitter\.com|x\.com)\/([^\/]+)\/status\/(\d+)/i;
  var SELECTOR = "blockquote.twitter-tweet, blockquote.twitter-video";

  // Ready callback queue
  var readyCallbacks = [];
  var isReady = false;

  function parseTweetUrl(url) {
    if (!url) return null;
    var match = TWEET_PATTERN.exec(url);
    if (match) return { username: match[1], id: match[2] };
    // Fallback: extract any large number (tweet ID)
    var idMatch = url.match(/(\d{15,})/);
    return idMatch ? { username: null, id: idMatch[1] } : null;
  }

  function createIframe(tweet, options) {
    var embedUrl = tweet.username
      ? NITTER + "/" + tweet.username + "/status/" + tweet.id + "/embed"
      : NITTER + "/i/status/" + tweet.id + "/embed";

    var iframe = document.createElement("iframe");
    iframe.src = embedUrl;
    iframe.className = "nitter-embed-frame";
    iframe.setAttribute("allowtransparency", "true");
    iframe.setAttribute("frameborder", "0");
    iframe.setAttribute("scrolling", "no");
    iframe.loading = "lazy";

    // Styling with data attribute support
    var width = options.width || "550";
    var align = options.align || "center";
    var margin = align === "center" ? "10px auto" :
                 align === "right" ? "10px 0 10px auto" : "10px auto 10px 0";

    iframe.style.cssText = "width:100%;max-width:" + width + "px;height:250px;border:none;display:block;margin:" + margin;

    return iframe;
  }

  function processBlockquote(bq) {
    if (bq.dataset.nitterProcessed) return false;
    bq.dataset.nitterProcessed = "true";

    // Find tweet URL in links
    var tweet = null;
    var links = bq.querySelectorAll("a[href]");
    for (var i = 0; i < links.length; i++) {
      tweet = parseTweetUrl(links[i].href);
      if (tweet) break;
    }

    if (!tweet) {
      console.warn("[Nitter widgets.js] No tweet URL found in blockquote");
      return false;
    }

    // Read Twitter's data attributes
    var options = {
      width: bq.dataset.width,
      align: bq.dataset.align,
      theme: bq.dataset.theme
    };

    var iframe = createIframe(tweet, options);

    // Hide original (keep as fallback), insert iframe after
    bq.style.display = "none";
    bq.parentNode.insertBefore(iframe, bq.nextSibling);
    return true;
  }

  function processEmbeds(container) {
    var root = container || document;
    var blockquotes = root.querySelectorAll(SELECTOR + ":not([data-nitter-processed])");
    var count = 0;

    for (var i = 0; i < blockquotes.length; i++) {
      if (processBlockquote(blockquotes[i])) count++;
    }

    if (count > 0) {
      console.log("[Nitter widgets.js] Processed " + count + " embed(s)");
    }
  }

  function handleResize(event) {
    if (!Array.isArray(event.data) || event.data[0] !== "resizeIframe") return;
    var h = event.data[1] && event.data[1].h;
    if (!h || h <= 0) return;

    // Find iframe by matching contentWindow
    var iframes = document.querySelectorAll("iframe.nitter-embed-frame");
    for (var i = 0; i < iframes.length; i++) {
      if (iframes[i].contentWindow === event.source) {
        iframes[i].style.height = h + "px";
        break;
      }
    }
  }

  function observeDOM() {
    if (!window.MutationObserver || !document.body) return;

    new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var nodes = mutations[i].addedNodes;
        for (var j = 0; j < nodes.length; j++) {
          var node = nodes[j];
          if (node.nodeType !== 1) continue;
          if ((node.matches && node.matches(SELECTOR)) ||
              (node.querySelector && node.querySelector(SELECTOR))) {
            processEmbeds();
            return;
          }
        }
      }
    }).observe(document.body, { childList: true, subtree: true });
  }

  function fireReady() {
    isReady = true;
    for (var i = 0; i < readyCallbacks.length; i++) {
      try { readyCallbacks[i](window.twttr); } catch (e) {}
    }
    readyCallbacks = [];
  }

  // Expose twttr API for compatibility
  var prevTwttr = window.twttr;
  window.twttr = {
    widgets: {
      load: function (el) { processEmbeds(el); },
      createTweet: function (id, container, opts) {
        if (!container) return Promise.reject("No container");
        var iframe = createIframe({ id: id, username: null }, opts || {});
        container.appendChild(iframe);
        return Promise.resolve(iframe);
      },
      loaded: true
    },
    ready: function (cb) {
      if (typeof cb !== "function") return;
      if (isReady) cb(window.twttr);
      else readyCallbacks.push(cb);
    },
    _e: []
  };

  // Process any callbacks queued before we loaded (twttr._e pattern)
  if (prevTwttr && prevTwttr._e) {
    for (var i = 0; i < prevTwttr._e.length; i++) {
      try { prevTwttr._e[i](); } catch (e) {}
    }
  }

  // Remove Twitter scripts that might have snuck in
  var twitterScripts = document.querySelectorAll(
    'script[src*="platform.twitter.com"], script[src*="platform.x.com"]'
  );
  for (var i = 0; i < twitterScripts.length; i++) {
    twitterScripts[i].remove();
  }

  // Initialize
  function init() {
    window.addEventListener("message", handleResize);
    processEmbeds();
    observeDOM();
    fireReady();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

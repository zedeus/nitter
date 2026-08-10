/**
 * Drop-in replacement for Twitter's widgets.js
 * Redirects twitter-tweet blockquotes to Nitter embeds
 */
(function () {
  "use strict";

  if (window.__nitterWidgets) return;
  window.__nitterWidgets = true;

  var scripts = document.querySelectorAll('script[src*="widgets.js"]');
  var NITTER = scripts.length
    ? new URL(scripts[scripts.length - 1].src).origin
    : location.origin;

  var TWEET_RE = /(?:twitter\.com|x\.com)\/([^\/]+)\/status\/(\d+)/i;
  var SELECTOR = "blockquote.twitter-tweet, blockquote.twitter-video";

  var readyCallbacks = [];
  var eventCallbacks = {};
  var isReady = false;

  function safeCall(fn, arg) {
    try { fn(arg); } catch (e) {}
  }

  function fireEvent(name, data) {
    (eventCallbacks[name] || []).forEach(function (cb) { safeCall(cb, data); });
  }

  function parseTweetUrl(url) {
    if (!url) return null;
    var m = TWEET_RE.exec(url);
    if (m) return { user: m[1], id: m[2] };
    m = url.match(/(\d{15,})/);
    return m ? { user: null, id: m[1] } : null;
  }

  function createIframe(tweet, opts) {
    var url;
    if (opts.videoOnly) {
      url = NITTER + "/i/videos/tweet/" + tweet.id;
    } else {
      var path = tweet.user ? "/" + tweet.user : "/i";
      url = NITTER + path + "/status/" + tweet.id + "/embed";
      if (opts.theme) {
        var theme = opts.theme === "dark" ? "nitter" :
                    opts.theme === "light" ? "twitter" : opts.theme;
        url += "?theme=" + encodeURIComponent(theme);
      }
    }

    var iframe = document.createElement("iframe");
    iframe.src = url;
    iframe.className = "nitter-embed-frame";
    iframe.loading = "lazy";
    iframe.setAttribute("allowtransparency", "true");
    iframe.setAttribute("frameborder", "0");
    iframe.setAttribute("scrolling", "no");
    if (opts.videoOnly) iframe.setAttribute("allowfullscreen", "true");

    var width = opts.width || 550;
    var margin = opts.align === "center" ? "10px auto" :
                 opts.align === "right" ? "10px 0 10px auto" : "10px 0";
    iframe.style.cssText =
      "width:100%;max-width:" + width + "px;height:250px;" +
      "border:none;display:block;margin:" + margin;

    iframe.addEventListener("load", function () {
      fireEvent("rendered", { target: iframe });
    });

    return iframe;
  }

  function processBlockquote(bq) {
    if (bq.dataset.nitterProcessed) return false;
    bq.dataset.nitterProcessed = "true";

    var tweet = null;
    var links = bq.querySelectorAll("a[href]");
    for (var i = 0; i < links.length && !tweet; i++) {
      tweet = parseTweetUrl(links[i].href);
    }
    if (!tweet) return false;

    var d = bq.dataset;
    var iframe = createIframe(tweet, {
      width: d.mediaMaxWidth || d.width,
      align: d.align,
      theme: d.theme,
      videoOnly: d.mediaMaxWidth !== undefined
    });

    bq.style.display = "none";
    bq.parentNode.insertBefore(iframe, bq.nextSibling);
    return true;
  }

  function processEmbeds(root) {
    var bqs = (root || document).querySelectorAll(SELECTOR + ":not([data-nitter-processed])");
    for (var i = 0; i < bqs.length; i++) processBlockquote(bqs[i]);
  }

  function handleResize(e) {
    if (!Array.isArray(e.data) || e.data[0] !== "resizeIframe") return;
    var h = e.data[1] && e.data[1].h;
    if (!h || h <= 0 || h > 10000) return; // Cap at 10000px for sanity

    var frames = document.querySelectorAll("iframe.nitter-embed-frame");
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].contentWindow === e.source) {
        frames[i].style.height = h + "px";
        return;
      }
    }
  }

  function observeDOM() {
    if (!window.MutationObserver || !document.body) return;

    function matches(el) {
      return el.matches(SELECTOR) || el.querySelector(SELECTOR);
    }

    new MutationObserver(function (muts) {
      var found = muts.some(function (mut) {
        return Array.prototype.some.call(mut.addedNodes, function (n) {
          return n.nodeType === 1 && matches(n);
        });
      });
      if (found) processEmbeds();
    }).observe(document.body, { childList: true, subtree: true });
  }

  function embedTweet(id, container, opts) {
    if (!container) return Promise.reject("No container");
    var iframe = createIframe({ id: id, user: null }, opts || {});
    container.appendChild(iframe);
    return Promise.resolve(iframe);
  }

  var prevTwttr = window.twttr;
  window.twttr = {
    widgets: {
      load: processEmbeds,
      createTweet: embedTweet,
      createTweetEmbed: embedTweet,
      createVideo: embedTweet,
      loaded: true
    },
    events: {
      bind: function (name, cb) {
        if (typeof cb !== "function") return;
        if (!eventCallbacks[name]) eventCallbacks[name] = [];
        eventCallbacks[name].push(cb);
      },
      unbind: function (name, cb) {
        if (!eventCallbacks[name]) return;
        eventCallbacks[name] = cb
          ? eventCallbacks[name].filter(function (f) { return f !== cb; })
          : [];
      }
    },
    ready: function (cb) {
      if (typeof cb !== "function") return;
      if (isReady) cb(window.twttr);
      else readyCallbacks.push(cb);
    },
    _e: []
  };

  // Process callbacks queued before load (twttr._e pattern)
  if (prevTwttr && prevTwttr._e) {
    prevTwttr._e.forEach(function (cb) { safeCall(cb); });
  }

  // Remove any Twitter scripts that snuck through
  document.querySelectorAll('script[src*="platform.twitter.com"], script[src*="platform.x.com"]')
    .forEach(function (s) { s.remove(); });

  function init() {
    window.addEventListener("message", handleResize);
    processEmbeds();
    observeDOM();
    isReady = true;
    readyCallbacks.forEach(function (cb) { safeCall(cb, window.twttr); });
    readyCallbacks = [];
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

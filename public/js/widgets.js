/**
 * Drop-in replacement for Twitter's widgets.js
 * Include this script to automatically convert twitter-tweet blockquotes to Nitter embeds
 */
(function () {
  "use strict";

  // Determine the Nitter instance URL from the script src, or fall back to current origin
  var widgetScripts = document.querySelectorAll('script[src*="widgets.js"]');
  var NITTER_URL = widgetScripts.length
    ? new URL(widgetScripts[widgetScripts.length - 1].src).origin
    : location.origin;

  var TWEET_URL_PATTERN =
    /^https?:\/\/(?:twitter\.com|x\.com)\/([^\/]+)\/status\/(\d+)/i;

  // Track iframes by URL for resize messages
  var iframesByUrl = {};

  /**
   * Extract tweet info (username and ID) from a blockquote's links
   */
  function findTweetInfo(blockquote) {
    var links = blockquote.querySelectorAll("a");
    for (var i = 0; i < links.length; i++) {
      var match = TWEET_URL_PATTERN.exec(links[i].href);
      if (match) {
        return { username: match[1], tweetId: match[2] };
      }
    }
    return null;
  }

  /**
   * Transform all twitter-tweet blockquotes into Nitter embed iframes
   */
  function transformBlockquotes() {
    var blockquotes = document.querySelectorAll("blockquote.twitter-tweet");

    for (var i = 0; i < blockquotes.length; i++) {
      var blockquote = blockquotes[i];
      var tweetInfo = findTweetInfo(blockquote);
      if (!tweetInfo) continue;

      var embedUrl =
        NITTER_URL +
        "/" +
        tweetInfo.username +
        "/status/" +
        tweetInfo.tweetId +
        "/embed";

      var iframe = document.createElement("iframe");
      iframe.src = embedUrl;
      iframe.style.cssText =
        "width: 100%; max-width: 550px; height: 250px; border: none; display: block;";
      iframe.loading = "lazy";

      // Track iframe for resize messages
      if (!iframesByUrl[embedUrl]) {
        iframesByUrl[embedUrl] = [];
      }
      iframesByUrl[embedUrl].push(iframe);

      blockquote.parentNode.replaceChild(iframe, blockquote);
    }
  }

  /**
   * Handle resize messages from Nitter embeds
   */
  function handleResizeMessage(event) {
    if (!Array.isArray(event.data) || event.data[0] !== "resizeIframe") return;

    var data = event.data[1];
    if (!data.h || data.h <= 0) return;

    var iframes = iframesByUrl[data.url];
    if (iframes) {
      for (var i = 0; i < iframes.length; i++) {
        iframes[i].style.height = data.h + "px";
      }
    }
  }

  // Remove any Twitter widget scripts that might have been loaded
  var twitterScripts = document.querySelectorAll(
    'script[src*="platform.twitter.com/widgets.js"], script[src*="platform.x.com/widgets.js"]',
  );
  for (var i = 0; i < twitterScripts.length; i++) {
    twitterScripts[i].remove();
  }

  // Listen for resize messages from embeds
  window.addEventListener("message", handleResizeMessage);

  // Transform existing blockquotes
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", transformBlockquotes);
  } else {
    transformBlockquotes();
  }

  // Watch for dynamically added blockquotes
  var observer = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var addedNodes = mutations[i].addedNodes;
      for (var j = 0; j < addedNodes.length; j++) {
        var node = addedNodes[j];
        if (node.nodeType !== 1) continue;

        var isTwitterBlockquote =
          node.matches && node.matches("blockquote.twitter-tweet");
        var containsTwitterBlockquote =
          node.querySelector && node.querySelector("blockquote.twitter-tweet");

        if (isTwitterBlockquote || containsTwitterBlockquote) {
          transformBlockquotes();
          return;
        }
      }
    }
  });

  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true });
  }

  // Provide a fake twttr object for compatibility with sites that check for it
  window.twttr = window.twttr || {};
  window.twttr.widgets = {
    load: transformBlockquotes,
    loaded: true,
  };
})();

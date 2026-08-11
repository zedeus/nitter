(function () {
  var embedElement = document.querySelector(
    ".embed-wrapper, .tweet-embed, .embed-video",
  );
  if (!embedElement) return;

  // Video play state for overlay (hidden while playing, visible on hover/pause)
  var video = embedElement.querySelector("video");
  if (video) {
    video.onplay = function () {
      embedElement.classList.add("video-playing");
    };
    video.onpause = video.onended = function () {
      embedElement.classList.remove("video-playing");
    };
  }

  var lastHeight = 0;

  function sendHeight() {
    var currentHeight = embedElement.offsetHeight;
    if (currentHeight !== lastHeight && currentHeight > 0) {
      lastHeight = currentHeight;
      window.parent.postMessage(
        ["resizeIframe", { h: currentHeight, url: location.href }],
        "*",
      );
    }
  }

  // Respond to height requests from parent via MessageChannel
  window.addEventListener("message", function (event) {
    if (event.source === window.parent && event.ports && event.ports[0]) {
      event.ports[0].postMessage(embedElement.offsetHeight);
    }
  });

  window.addEventListener("load", sendHeight);
  new ResizeObserver(sendHeight).observe(embedElement);

  // Expose for embedTweet.js
  window._nitterSendHeight = sendHeight;
})();

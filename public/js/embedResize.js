(function () {
  var embed = document.querySelector(".embed-wrapper, .embed-video");
  if (!embed) return;

  var video = embed.querySelector("video");
  if (video) {
    video.onplay = function () {
      embed.classList.add("video-playing");
    };
    video.onpause = video.onended = function () {
      embed.classList.remove("video-playing");
    };
  }

  var lastHeight = 0;

  function sendHeight() {
    var h = embed.offsetHeight;
    if (h !== lastHeight && h > 0) {
      lastHeight = h;
      window.parent.postMessage(["resizeIframe", { h: h }], "*");
    }
  }

  // MessageChannel height request (used by oEmbed)
  window.addEventListener("message", function (e) {
    if (e.source === window.parent && e.ports && e.ports[0]) {
      e.ports[0].postMessage(embed.offsetHeight);
    }
  });

  window.addEventListener("load", sendHeight);
  new ResizeObserver(sendHeight).observe(embed);
})();

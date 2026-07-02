// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
function playMedia(overlay, tagName) {
    const media = overlay.parentElement.querySelector(tagName);
    const url = media.getAttribute("data-url");
    const startTime = parseFloat(media.getAttribute("data-start") || "0");
    media.setAttribute("controls", "");
    overlay.style.display = "none";

    if (Hls.isSupported()) {
        var hls = new Hls({autoStartLoad: false});
        hls.loadSource(url);
        hls.attachMedia(media);
        hls.on(Hls.Events.MANIFEST_PARSED, function () {
            hls.loadLevel = hls.levels.length - 1;
            hls.startLoad(startTime);
            media.play();
        });
    } else if (media.canPlayType('application/vnd.apple.mpegurl')) {
        media.src = url;
        media.addEventListener('canplay', function() {
            if (startTime > 0) media.currentTime = startTime;
            media.play();
        });
    }
}

function playVideo(overlay) { playMedia(overlay, 'video'); }
function playAudio(overlay) { playMedia(overlay, 'audio'); }
// @license-end

// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
function playVideo(overlay) {
    const video = overlay.parentElement.querySelector('video');
    const url = video.getAttribute("data-url");
    const startTime = parseFloat(video.getAttribute("data-start") || "0");
    video.setAttribute("controls", "");
    overlay.style.display = "none";

    if (Hls.isSupported()) {
        var hls = new Hls({autoStartLoad: false});
        hls.loadSource(url);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function () {
            hls.loadLevel = hls.levels.length - 1;
            hls.startLoad(startTime);
            video.play();
        });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
        video.addEventListener('canplay', function() {
            if (startTime > 0) video.currentTime = startTime;
            video.play();
        });
    }
}
// @license-end

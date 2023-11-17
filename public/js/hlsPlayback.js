// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
const video_overlay = document.getElementsByClassName("video-overlay");

for (var i = 0 ; i < video_overlay.length; i++) {
   video_overlay[i].addEventListener('click', function () {

        const video = this.parentElement.querySelector('video');
        const url = video.getAttribute("data-url");
        video.setAttribute("controls", "");
        this.style.display = "none";

        if (Hls.isSupported()) {
            var hls = new Hls({autoStartLoad: false});
            hls.loadSource(url);
            hls.attachMedia(video);
            hls.on(Hls.Events.MANIFEST_PARSED, function () {
                hls.loadLevel = hls.levels.length - 1;
                hls.startLoad();
                video.play();
            });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = url;
            video.addEventListener('canplay', function() {
                video.play();
            });
        }
    });
}
// @license-end

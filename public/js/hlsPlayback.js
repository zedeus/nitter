function playVideo(overlay) {
    const video = overlay.parentElement.querySelector('video');
    const url = video.getAttribute("data-url");
    video.setAttribute("controls", "");
    overlay.style.display = "none";

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
        video.addEventListened('canplay', function() {
            video.play();
        });
    }
}

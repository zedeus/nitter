function playVideo(overlay) {
    const video = overlay.parentElement.querySelector('video');
    video.setAttribute("controls", "");
    overlay.style.display = "none";

    const url = video.getAttribute("data-url");
    var hls = new Hls({autoStartLoad: false});
    hls.loadSource(url);
    hls.attachMedia(video);
    hls.on(Hls.Events.MANIFEST_PARSED, function () {
        hls.loadLevel = hls.levels.length - 1;
        hls.startLoad();
        video.play();
    });
}

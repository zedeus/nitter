// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
(function() {
  'use strict';

  const m3u8 = 'application/vnd.apple.mpegurl';
  const thresholds = [ 0.1, 0.9 ]; // check viewport at 10% and 90%
  const videoConfig = { controls: true, oldRatio: 0, testViewport: true };

  const observer = new IntersectionObserver(observeEntries, { threshold: thresholds });

  function isLeavingView(currRatio, oldRatio) {
    return (oldRatio > currRatio);
  }

  function isMostlyInView(currRatio) {
    return (currRatio > thresholds[1]);
  }

  // is paused -> https://stackoverflow.com/questions/36803176
  function isVideoPaused(video) {
    return (video.paused || video.ended || video.readyState < video.HAVE_CURRENT_DATA);
  }

  function loadVideo(video) {
    Object.assign(video, videoConfig);
    return video.play();
  }

  function observeEntries(entries) {
    entries.forEach((entry) => {
      const video = entry.target;

      const inView = isMostlyInView(entry.intersectionRatio)
      const isPaused = isVideoPaused(video)

      if (inView && isPaused) video.play();
      else if (!inView && !isPaused && isLeavingView(entry.intersectionRatio, video.oldRatio)) {
        video.testViewport = false;
        video.pause();
      }

      video.oldRatio = entry.intersectionRatio;
    });
  }

  // we set the oldRatio to 0 on manual pauses, as we don't know where the viewport will end up
  function observeVideo(video) {
    observer.observe(video);
    video.addEventListener('play', (evt) => observer.observe(video));
    video.addEventListener('pause', (evt) => {
      video.testViewport ? (observer.unobserve(video), video.oldRatio = 0) : (observer.observe(video), video.testViewport = true)
    });
  }

  function useHLS(video, url) {
    const hls = new Hls();
    hls.on(Hls.Events.MEDIA_ATTACHED, () => hls.loadSource(url));
    hls.on(Hls.Events.MANIFEST_PARSED, () => loadVideo(video).then(() => observeVideo(video)));
    hls.attachMedia(video);
  }

  function useM3U8(video, url) {
    video.src = url;
    video.addEventListener('canplay', () => loadVideo(video));
  }

  // export playVideo
  window.playVideo = function(overlay) {
    const video = overlay.parentElement.querySelector('video');
    const url = video.getAttribute('data-url');

    if ('Hls' in window && Hls.isSupported()) useHLS(video, url);
    else if (video.canPlayType(m3u8)) useM3U8(video, url);

    overlay.style.display = 'none';
  }

})()
// @license-end

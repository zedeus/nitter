// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
(function() {
  'use strict'

  const thresholdLower = 0.8
  const thresholdUpper = 0.9
  const videoConfig = {
    controls: true,
    oldRatio: 0.0,
    viewportChange: false
  }
  const videoObserver = new IntersectionObserver(onViewportChange, {
    threshold: [thresholdLower, thresholdUpper]
  })

  function isMostlyInView(entry) {
    return entry.intersectionRatio > thresholdUpper
  }

  function isLeavingView(entry, video) {
    return entry.intersectionRatio >= thresholdLower && video.oldRatio > entry.intersectionRatio
  }

  // https://stackoverflow.com/questions/36803176
  function isPlaying(video) {
    return video.currentTime > 0 && !video.paused && !video.ended && video.readyState > video.HAVE_CURRENT_DATA
  }

  function observeVideo(video) {
    videoObserver.observe(video)
    video.addEventListener('pause', (evt) => {
      video.viewportChange
        ? (videoObserver.observe(video), video.viewportChange = false)
        : videoObserver.unobserve(video)
    })
    video.addEventListener('play', (evt) => {
      videoObserver.observe(video)
    })
  }

  function displayVideo(overlay, video) {
    overlay.style.display = 'none'
    Object.assign(video, videoConfig)
    video.play().then(() => observeVideo(video))
  }

  function onViewportChange(entries) {
    entries.forEach((entry) => {
      const video = entry.target
      if (isMostlyInView(entry) && !isPlaying(video)) {
        video.play()
      } else if (
        !isMostlyInView(entry) &&
        isLeavingView(entry, video) &&
        isPlaying(video)
      ) {
        video.viewportChange = true
        video.pause()
      }
      video.oldRatio = entry.intersectionRatio
    })
  }

  window.playVideo = function(overlay) {
    if (!('Hls' in window)) {
      console.error('ERROR: Hls not found, unable to play video!')
      return
    }

    const video = overlay.parentElement.querySelector('video')
    const url = video.getAttribute('data-url')

    if (Hls.isSupported()) {
      const hls = new Hls()
      hls.attachMedia(video)
      hls.on(Hls.Events.MEDIA_ATTACHED, () => {
        hls.loadSource(url)
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          displayVideo(overlay, video)
        })
      })
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = url
      video.addEventListener('canplay', () => video.play())
    }
  }
})()
// @license-end

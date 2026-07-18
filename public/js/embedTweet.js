// This runs after embedResize.js sets up the sendHeight function
(function(sendHeight) {
  // Make images load eagerly so height updates correctly
  var lazyImages = document.querySelectorAll('img[loading="lazy"]');
  for (var i = 0; i < lazyImages.length; i++) {
    lazyImages[i].loading = 'eager';
  }

  // Update height when images finish loading
  var allImages = document.querySelectorAll('img');
  for (var i = 0; i < allImages.length; i++) {
    var img = allImages[i];
    if (!img.complete) {
      img.addEventListener('load', sendHeight);
    }
  }

  // Open all links in new tab (we're in an iframe)
  var allLinks = document.querySelectorAll('a');
  for (var i = 0; i < allLinks.length; i++) {
    allLinks[i].target = '_blank';
  }
})(arguments[0]);

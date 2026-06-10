// Detects the visitor's UTC offset and stores it in a cookie so the server
// can render timestamps in the visitor's local time when the "Auto" timezone
// preference is selected.
(function() {
  function pad(n) {
    return (n < 10 ? "0" : "") + n;
  }

  var offsetMin = -new Date().getTimezoneOffset();
  var sign = offsetMin < 0 ? "-" : "+";
  var abs = Math.abs(offsetMin);
  var offset = sign + pad(Math.floor(abs / 60)) + ":" + pad(abs % 60);

  var match = document.cookie.match(/(?:^|; )tz-offset=([^;]*)/);
  var current = match ? decodeURIComponent(match[1]) : null;

  if (current !== offset) {
    if (window.sessionStorage.getItem("tz-offset-set") === offset) {
      return;
    }

    var expires = new Date();
    expires.setFullYear(expires.getFullYear() + 1);
    document.cookie = "tz-offset=" + offset + "; path=/; expires=" +
      expires.toUTCString() + "; SameSite=Lax";

    window.sessionStorage.setItem("tz-offset-set", offset);
    location.reload();
  }
})();

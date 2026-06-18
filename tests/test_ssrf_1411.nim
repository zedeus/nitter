# SPDX-License-Identifier: AGPL-3.0-only
# Reproduction + regression test for issue #1411:
# SSRF via /video proxy with default HMAC key and missing host validation.
import std/[unittest, uri]
import ".."/src/utils

suite "issue #1411 SSRF via /video proxy":
  setup:
    # The default key shipped in nitter.example.conf / config.nim.
    setHmacKey("secretkey")

  test "HMAC for arbitrary SSRF URLs is forgeable with the default key":
    # These signatures were independently computed (Python hmac-sha256, uppercase
    # hex, first 13 chars) and observed live in the issue report.
    check getHmac("http://172.17.0.1:19999/secret_data.m3u8") == "BBD19ACC6C012"
    check getHmac("http://172.17.0.1:19999/secret_data.mp4")  == "0780F00DDF3E7"

  test "isTwitterUrl rejects SSRF targets (the guard /video is missing)":
    # Internal / metadata hosts an attacker would target.
    check isTwitterUrl(parseUri("http://172.17.0.1:19999/secret_data.m3u8")) == false
    check isTwitterUrl(parseUri("http://169.254.169.254/latest/meta-data/x.m3u8")) == false
    check isTwitterUrl(parseUri("http://localhost/x.mp4")) == false
    check isTwitterUrl(parseUri("http://[::1]/x.mp4")) == false

  test "isTwitterUrl rejects userinfo / look-alike host bypass attempts":
    check isTwitterUrl(parseUri("http://video.twimg.com@169.254.169.254/x.mp4")) == false
    check isTwitterUrl(parseUri("http://video.twimg.com.evil.com/x.mp4")) == false
    check isTwitterUrl(parseUri("http://evilvideo.twimg.com.attacker/x.mp4")) == false

  test "isTwitterUrl rejects non-http schemes even on a Twitter host":
    check isTwitterUrl(parseUri("gopher://video.twimg.com/x.mp4")) == false
    check isTwitterUrl(parseUri("file:///etc/passwd")) == false
    check isTwitterUrl(parseUri("ftp://video.twimg.com/x.mp4")) == false

  test "isTwitterUrl still allows legitimate Twitter video hosts":
    check isTwitterUrl(parseUri("https://video.twimg.com/ext_tw_video/1/pu/pl/x.m3u8")) == true
    check isTwitterUrl(parseUri("https://video.twimg.com/amplify_video/1/vid/x.mp4")) == true
    check isTwitterUrl(parseUri("https://prod-fastly-us-east-1.video.pscp.tv/x.m3u8")) == true

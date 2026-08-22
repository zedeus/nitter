import os
import unittest
import requests
from base import BaseTestCase, Media
from parameterized import parameterized


class Embed:
    container = '.tweet-embed'
    footer = '.embed-footer'
    tweet_content = '.tweet-content'
    tweet_header = '.tweet-header'
    fullname = '.fullname'
    username = '.username'
    avatar = '.avatar'
    stats = '.tweet-stats'
    quote = '.quote'
    error_panel = '.error-panel'


class TweetEmbedTest(BaseTestCase):
    """Test tweet embed rendering."""
    tweet = 'elonmusk/status/1141367104702038016'

    def test_embed_container_visible(self):
        self.open_nitter(self.tweet + '/embed')
        self.assert_element_visible(Embed.container)

    def test_embed_has_footer(self):
        self.open_nitter(self.tweet + '/embed')
        self.assert_element_visible(Embed.footer)
        self.assert_text_visible('Read more on', Embed.footer)

    def test_embed_has_tweet_content(self):
        self.open_nitter(self.tweet + '/embed')
        self.assert_element_visible(Embed.tweet_content)

    def test_embed_has_avatar(self):
        self.open_nitter(self.tweet + '/embed')
        self.assert_element_visible(Embed.avatar)

    def test_embed_has_username(self):
        self.open_nitter(self.tweet + '/embed')
        self.assert_element_visible(Embed.username)

    def test_embed_has_stats(self):
        self.open_nitter(self.tweet + '/embed')
        self.assert_element_visible(Embed.stats)

    def test_embed_footer_links_to_tweet(self):
        self.open_nitter(self.tweet + '/embed')
        href = self.get_attribute(Embed.footer, 'href')
        self.assertIn('/elonmusk/status/1141367104702038016', href)


class TweetEmbedMediaTest(BaseTestCase):
    """Test embed rendering with various media types."""

    def test_embed_with_image(self):
        self.open_nitter('mobile_test/status/519364660823207936/embed')
        self.assert_element_visible(Embed.container)
        self.scroll_to(Media.container)
        self.assert_element_visible(Media.image)

    def test_embed_with_gif(self):
        self.open_nitter('elonmusk/status/1141367104702038016/embed')
        self.assert_element_visible(Embed.container)
        self.scroll_to(Media.container)
        self.assert_element_visible(Media.gif)

    @unittest.skipIf(os.environ.get('GITHUB_ACTIONS') == 'true',
                     'TweetResultByRestId is Cloudflare-blocked from GitHub datacenter IPs')
    def test_embed_with_video(self):
        self.open_nitter('d0m96/status/1078373829917974528/embed')
        self.assert_element_visible(Embed.container)
        self.scroll_to(Media.container)
        self.assert_element_visible(Media.video)

    def test_embed_with_gallery(self):
        self.open_nitter('mobile_test/status/451108446603980803/embed')
        self.assert_element_visible(Embed.container)
        self.scroll_to(Media.container)
        self.assert_element_visible(Media.row)


class TweetEmbedQuoteTest(BaseTestCase):
    """Test embed rendering with quoted tweets."""

    def test_embed_with_quote_shows_quote(self):
        self.open_nitter('elonmusk/status/1138827760107790336/embed')
        self.assert_element_visible(Embed.container)
        self.assert_element_visible(Embed.quote)

    def test_embed_quote_has_content(self):
        self.open_nitter('elonmusk/status/1138827760107790336/embed')
        quote = self.find_element(Embed.quote)
        self.assertIsNotNone(quote.text)


class EmbedErrorTest(BaseTestCase):
    """Test embed error handling."""

    def test_nonexistent_tweet_shows_error(self):
        self.open_nitter('nobody/status/1/embed')
        self.assert_element_visible('.tweet-embed.error-embed')
        self.assert_text_visible('not found', Embed.error_panel)

    def test_protected_account_embed_shows_error(self):
        self.open_nitter('mobile_test_7/status/1/embed')
        self.assert_element_visible('.tweet-embed.error-embed')

    def test_invalid_tweet_id_shows_error(self):
        self.open_nitter('jack/status/notanumber/embed')
        self.assert_element_visible('.tweet-embed.error-embed')


class OEmbedApiTest(BaseTestCase):
    """Test oEmbed API endpoint."""
    base_url = 'http://localhost:8080'
    tweet_url = 'https://twitter.com/elonmusk/status/1141367104702038016'

    def test_oembed_returns_json(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.headers['Content-Type'], 'application/json')

    def test_oembed_has_required_fields(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        data = resp.json()
        self.assertEqual(data['type'], 'rich')
        self.assertEqual(data['version'], '1.0')
        self.assertIn('html', data)
        self.assertIn('author_name', data)
        self.assertIn('provider_name', data)

    def test_oembed_html_contains_iframe(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        data = resp.json()
        self.assertIn('<iframe', data['html'])
        self.assertIn('/embed', data['html'])

    def test_oembed_has_cors_header(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        self.assertEqual(resp.headers.get('Access-Control-Allow-Origin'), '*')

    def test_oembed_missing_url_returns_400(self):
        resp = requests.get(f'{self.base_url}/api/oembed')
        self.assertEqual(resp.status_code, 400)

    def test_oembed_invalid_url_returns_400(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url=https://example.com')
        self.assertEqual(resp.status_code, 400)

    def test_oembed_supports_x_com_url(self):
        x_url = 'https://x.com/elonmusk/status/1141367104702038016'
        resp = requests.get(f'{self.base_url}/api/oembed?url={x_url}')
        self.assertEqual(resp.status_code, 200)

    def test_oembed_strips_query_params(self):
        url_with_params = 'https://twitter.com/elonmusk/status/1141367104702038016?s=20&t=abc'
        resp = requests.get(f'{self.base_url}/api/oembed?url={url_with_params}')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('html', data)

    def test_oembed_handles_trailing_slash(self):
        url_with_slash = 'https://twitter.com/elonmusk/status/1141367104702038016/'
        resp = requests.get(f'{self.base_url}/api/oembed?url={url_with_slash}')
        self.assertEqual(resp.status_code, 200)

    def test_oembed_handles_mobile_url(self):
        mobile_url = 'https://mobile.twitter.com/elonmusk/status/1141367104702038016'
        resp = requests.get(f'{self.base_url}/api/oembed?url={mobile_url}')
        self.assertEqual(resp.status_code, 200)

    def test_oembed_rejects_malformed_tweet_id(self):
        bad_url = 'https://twitter.com/elonmusk/status/notanumber'
        resp = requests.get(f'{self.base_url}/api/oembed?url={bad_url}')
        self.assertEqual(resp.status_code, 400)

    def test_oembed_maxwidth_param_accepted(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}&maxwidth=400')
        self.assertEqual(resp.status_code, 200)

    def test_oembed_maxwidth_clamps_to_range(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}&maxwidth=100')
        data = resp.json()
        self.assertEqual(data['width'], 220)
        self.assertIn('max-width:220px', data['html'])

    def test_oembed_maxwidth_caps_at_550(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}&maxwidth=9999')
        data = resp.json()
        self.assertEqual(data['width'], 550)

    def test_oembed_maxwidth_invalid_uses_default(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}&maxwidth=abc')
        data = resp.json()
        self.assertEqual(data['width'], 550)

    def test_oembed_author_url_present(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        data = resp.json()
        self.assertIn('author_url', data)
        self.assertIn('elonmusk', data['author_url'])

    def test_oembed_accepts_nitter_url(self):
        nitter_url = f'{self.base_url}/elonmusk/status/1141367104702038016'
        resp = requests.get(f'{self.base_url}/api/oembed?url={nitter_url}')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('html', data)

    def test_oembed_format_json_accepted(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}&format=json')
        self.assertEqual(resp.status_code, 200)

    def test_oembed_format_xml_returns_501(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}&format=xml')
        self.assertEqual(resp.status_code, 501)

    def test_oembed_has_title(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        data = resp.json()
        self.assertIn('title', data)
        self.assertIsInstance(data['title'], str)
        self.assertGreater(len(data['title']), 0)

    def test_oembed_has_null_height(self):
        resp = requests.get(f'{self.base_url}/api/oembed?url={self.tweet_url}')
        data = resp.json()
        self.assertIsNone(data['height'])


class OEmbedDiscoveryTest(BaseTestCase):
    """Test oEmbed discovery link tags on tweet pages."""
    base_url = 'http://localhost:8080'

    def test_tweet_page_has_oembed_link_tag(self):
        self.open_nitter('elonmusk/status/1141367104702038016')
        self.assert_element_present('link[type="application/json+oembed"]')

    def test_oembed_link_tag_points_to_api(self):
        resp = requests.get(f'{self.base_url}/elonmusk/status/1141367104702038016')
        self.assertIn('application/json+oembed', resp.text)
        self.assertIn('/api/oembed?url=', resp.text)
        self.assertIn('1141367104702038016', resp.text)

    def test_oembed_discovery_roundtrip(self):
        """Fetch a tweet page, extract oEmbed URL, call it, verify response."""
        import re
        resp = requests.get(f'{self.base_url}/elonmusk/status/1141367104702038016')
        match = re.search(
            r'type="application/json\+oembed"\s+href="([^"]*)"', resp.text)
        self.assertIsNotNone(match, "No oEmbed discovery link found in page")
        oembed_url = match.group(1).replace('&amp;', '&')
        oembed_resp = requests.get(oembed_url)
        self.assertEqual(oembed_resp.status_code, 200)
        data = oembed_resp.json()
        self.assertEqual(data['type'], 'rich')
        self.assertIn('html', data)


@unittest.skipIf(os.environ.get('GITHUB_ACTIONS') == 'true',
                 'TweetResultByRestId is Cloudflare-blocked from GitHub datacenter IPs')
class VideoEmbedTest(BaseTestCase):
    """Test video embed route (/i/videos/tweet/{id})."""
    video_tweet_id = '1078373829917974528'

    def test_video_embed_has_video_element(self):
        self.open_nitter(f'i/videos/tweet/{self.video_tweet_id}')
        self.assert_element_visible('video')

    def test_video_embed_has_poster(self):
        self.open_nitter(f'i/videos/tweet/{self.video_tweet_id}')
        poster = self.get_attribute('video', 'poster')
        self.assertIsNotNone(poster)
        self.assertIn('pic/', poster)

    def test_video_embed_nonexistent_returns_error(self):
        self.open_nitter('i/videos/tweet/1')
        self.assert_element_visible('.error-embed')

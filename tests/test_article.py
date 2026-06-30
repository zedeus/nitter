from base import BaseTestCase
from parameterized import parameterized


class ArticleSelectors:
    page = '.article-page'
    cover = '.article-cover'
    body = '.article-body'
    title = '.article-title'
    author = '.article-author'
    fullname = '.article-author .fullname'
    username = '.article-author .username'
    date = '.article-author .article-date'
    avatar = '.article-author img.avatar'
    verified = '.article-author .verified-icon'
    media = '.article-media'
    caption = '.article-media-caption'
    divider = '.article-divider'


articles = [
    ['2064166507438059759',
     '1s，秒杀一切，开源一个 X 文章发布 Skill【重磅升级】',
     'punk2898', 'Punk'],

    ['2064689664213041529',
     'SpaceX Thesis & Valuation Memorandum',
     'Dialectic_Group', 'Dialectic'],

    ['2064691088636424322',
     'Consciousness and AI: The Problem of Inner Experience',
     'CosmicOrFun', 'Cosmic Orphan'],

    ['2064755789391110154',
     'DeFi Markets Update 2026-06-10',
     'SteakhouseFi', 'Steakhouse Financial'],

    ['2064755231901319527',
     'The machine economy has a killswitch and somebody just pulled it.',
     '1914ad', 'Justin Bechler HMP-028'],

    ['2062858677149675788',
     'Yakshinis',
     'CosmicOrFun', 'Cosmic Orphan'],
]

articles_with_media = [
    ['2064166507438059759', 6],
    ['2064689664213041529', 11],
    ['2064755789391110154', 5],
]

articles_with_dividers = [
    ['2064166507438059759', 1],
    ['2064689664213041529', 6],
]


class ArticleBasicTest(BaseTestCase):
    @parameterized.expand(articles)
    def test_article_loads(self, tweet_id, title, username, fullname):
        self.open_nitter(f'i/article/{tweet_id}')
        self.assert_element_visible(ArticleSelectors.page)
        self.assert_element_visible(ArticleSelectors.body)
        self.assert_text(title, ArticleSelectors.title)

    @parameterized.expand(articles)
    def test_article_author(self, tweet_id, title, username, fullname):
        self.open_nitter(f'i/article/{tweet_id}')
        self.assert_element_visible(ArticleSelectors.author)
        self.assert_text(f'@{username}', ArticleSelectors.username)

    @parameterized.expand(articles)
    def test_article_has_cover(self, tweet_id, title, username, fullname):
        self.open_nitter(f'i/article/{tweet_id}')
        self.assert_element_visible(ArticleSelectors.cover)
        src = self.get_attribute(ArticleSelectors.cover, 'src')
        self.assertIn('/pic/', src)

    @parameterized.expand(articles)
    def test_article_has_date(self, tweet_id, title, username, fullname):
        self.open_nitter(f'i/article/{tweet_id}')
        date_text = self.get_text(ArticleSelectors.date)
        self.assertTrue(len(date_text) > 3)

    @parameterized.expand(articles)
    def test_article_author_avatar(self, tweet_id, title, username, fullname):
        self.open_nitter(f'i/article/{tweet_id}')
        self.assert_element_visible(ArticleSelectors.avatar)
        src = self.get_attribute(ArticleSelectors.avatar, 'src')
        self.assertIn('/pic/', src)
        self.assertGreater(len(src), len('/pic/'))

    @parameterized.expand(articles)
    def test_article_author_verified(self, tweet_id, title, username, fullname):
        self.open_nitter(f'i/article/{tweet_id}')
        self.assert_element_visible(ArticleSelectors.verified)

    def test_article_author_verified_business(self):
        self.open_nitter('i/article/2064755789391110154')
        self.assert_element_visible('.article-author .verified-icon.business')


class ArticleContentTest(BaseTestCase):
    def test_article_has_paragraphs(self):
        self.open_nitter('i/article/2064689664213041529')
        paragraphs = self.find_elements('.article-body p')
        self.assertGreater(len(paragraphs), 10)

    def test_article_has_headers(self):
        self.open_nitter('i/article/2064689664213041529')
        headers = self.find_elements('.article-body h1, .article-body h2')
        self.assertGreater(len(headers), 5)

    def test_article_has_bold_text(self):
        self.open_nitter('i/article/2064166507438059759')
        bold = self.find_elements('.article-body strong')
        self.assertGreater(len(bold), 0)

    def test_article_has_italic_text(self):
        self.open_nitter('i/article/2064166507438059759')
        italic = self.find_elements('.article-body em')
        self.assertGreater(len(italic), 0)

    def test_article_has_blockquotes(self):
        self.open_nitter('i/article/2064166507438059759')
        self.assert_element_visible('.article-body blockquote')

    def test_article_has_lists(self):
        self.open_nitter('i/article/2064166507438059759')
        self.assert_element_visible('.article-body ul')

    def test_article_has_emoji_text(self):
        self.open_nitter('i/article/2064166507438059759')
        body = self.get_text(ArticleSelectors.body)
        self.assertTrue(any(ord(c) > 0x1F000 for c in body))

    def test_article_has_links(self):
        self.open_nitter('i/article/2064691088636424322')
        links = self.find_elements('.article-body a[href]')
        self.assertGreater(len(links), 0)

    def test_article_twitter_links_localized(self):
        self.open_nitter('i/article/2064755789391110154')
        links = self.find_elements('.article-body a[href^="https://x.com"]')
        self.assertEqual(len(links), 0, 'x.com links should be converted to local paths')

    @parameterized.expand(articles_with_media)
    def test_article_media_count(self, tweet_id, expected_count):
        self.open_nitter(f'i/article/{tweet_id}')
        media = self.find_elements(ArticleSelectors.media)
        self.assertEqual(len(media), expected_count)

    @parameterized.expand(articles_with_dividers)
    def test_article_divider_count(self, tweet_id, expected_count):
        self.open_nitter(f'i/article/{tweet_id}')
        dividers = self.find_elements(ArticleSelectors.divider)
        self.assertEqual(len(dividers), expected_count)


class ArticleMediaTest(BaseTestCase):
    def test_media_images_proxied(self):
        self.open_nitter('i/article/2064689664213041529')
        self.assert_element_visible(ArticleSelectors.media)
        img = self.find_element(f'{ArticleSelectors.media} img')
        src = img.get_attribute('src')
        self.assertIn('/pic/', src)
        self.assertFalse(src.startswith('https://pbs.twimg.com'))

    def test_cover_image_proxied(self):
        self.open_nitter('i/article/2064689664213041529')
        self.assert_element_visible(ArticleSelectors.cover)
        src = self.get_attribute(ArticleSelectors.cover, 'src')
        self.assertIn('/pic/', src)
        self.assertFalse(src.startswith('https://pbs.twimg.com'))

    def test_embedded_tweet(self):
        self.open_nitter('i/article/2064755789391110154')
        self.assert_element_visible('.article-body .timeline-item')

    def test_multiple_embedded_tweets(self):
        self.open_nitter('i/article/2064755231901319527')
        tweets = self.find_elements('.article-body .timeline-item')
        self.assertGreaterEqual(len(tweets), 3)

    def test_media_caption_displayed(self):
        self.open_nitter('i/article/2064689664213041529')
        self.assert_element_visible(ArticleSelectors.caption)
        captions = self.find_elements(ArticleSelectors.caption)
        self.assertGreaterEqual(len(captions), 5)

    def test_media_caption_text(self):
        self.open_nitter('i/article/2064689664213041529')
        self.assert_text_visible('FIGURE 1', ArticleSelectors.caption)

    def test_media_caption_alt_attribute(self):
        self.open_nitter('i/article/2064689664213041529')
        img = self.find_element(f'{ArticleSelectors.media} img')
        alt = img.get_attribute('alt')
        self.assertGreater(len(alt), 0)

    def test_no_caption_when_absent(self):
        self.open_nitter('i/article/2062858677149675788')
        captions = self.find_elements(ArticleSelectors.caption)
        self.assertEqual(len(captions), 0)


class ArticleMentionTest(BaseTestCase):
    def test_mention_linkified(self):
        self.open_nitter('i/article/2064755231901319527')
        link = self.find_element('.article-body a[href="/ZachXBT"]')
        self.assertEqual(link.text, '@ZachXBT')

    def test_multiple_mentions_linkified(self):
        self.open_nitter('i/article/2064755231901319527')
        links = self.find_elements('.article-body a[href^="/"]')
        mention_hrefs = [l.get_attribute('href') for l in links
                         if l.text.startswith('@')]
        usernames = [h.split('/')[-1] for h in mention_hrefs]
        self.assertIn('ZachXBT', usernames)
        self.assertIn('River', usernames)

    def test_mention_in_different_article(self):
        self.open_nitter('i/article/2064689664213041529')
        link = self.find_element('.article-body a[href="/FutureJurvetson"]')
        self.assertEqual(link.text, '@FutureJurvetson')

    def test_no_spurious_whitespace_in_styled_paragraph(self):
        """Styled paragraphs should not have extra whitespace from VNode serialization."""
        self.open_nitter('i/article/2064166507438059759')
        source = self.get_page_source()
        self.assertNotIn('white-space: pre-wrap', source)
        self.assertNotIn('white-space:pre-wrap', source)


class ArticleCardTest(BaseTestCase):
    @parameterized.expand(articles)
    def test_status_page_shows_article_card(self, tweet_id, title, username, fullname):
        self.open_nitter(f'{username}/status/{tweet_id}')
        self.assert_element_visible('.article-card')
        self.assert_text(title, '.article-card .card-title')

    def test_article_card_has_cover_image(self):
        self.open_nitter('Dialectic_Group/status/2064689664213041529')
        self.assert_element_visible('.article-card .card-image img')
        src = self.get_attribute('.article-card .card-image img', 'src')
        self.assertIn('/pic/', src)

    def test_article_card_has_badge(self):
        self.open_nitter('Dialectic_Group/status/2064689664213041529')
        self.assert_element_visible('.article-card-badge')
        self.assert_text('Article', '.article-card-badge')

    def test_article_card_has_preview_text(self):
        self.open_nitter('CosmicOrFun/status/2064691088636424322')
        self.assert_element_visible('.article-card .card-description')

    def test_article_card_links_to_article(self):
        self.open_nitter('punk2898/status/2064166507438059759')
        href = self.get_attribute('.article-card .card-container', 'href')
        self.assertIn('/article/', href)

    def test_article_url_stripped_from_tweet_text(self):
        self.open_nitter('punk2898/status/2064166507438059759')
        self.assert_element_visible('.article-card')
        source = self.get_page_source()
        # Main tweet text should not contain article URL
        import re
        main = re.search(r'id="m".*?tweet-content[^>]*>(.*?)</div>', source, re.DOTALL)
        self.assertIsNotNone(main)
        self.assertNotIn('/article/', main.group(1))


class ArticleQuotedCardTest(BaseTestCase):
    """Article cards inside quoted tweets (1914ad quoting own article)."""
    quoted_tweet = '1914ad/status/2064789532071891085'
    quoted_article_id = '2063677483548102688'

    def test_quoted_card_visible(self):
        self.open_nitter(self.quoted_tweet)
        self.assert_element_visible('.quote .article-card')

    def test_quoted_card_has_title(self):
        self.open_nitter(self.quoted_tweet)
        self.assert_text('David Bailey Already Won', '.quote .article-card .card-title')

    def test_quoted_card_has_badge(self):
        self.open_nitter(self.quoted_tweet)
        self.assert_element_visible('.quote .article-card-badge')
        self.assert_text('Article', '.quote .article-card-badge')

    def test_quoted_card_has_cover_image(self):
        self.open_nitter(self.quoted_tweet)
        self.assert_element_visible('.quote .article-card .card-image img')
        src = self.get_attribute('.quote .article-card .card-image img', 'src')
        self.assertIn('/pic/', src)

    def test_quoted_card_has_description(self):
        self.open_nitter(self.quoted_tweet)
        self.assert_element_visible('.quote .article-card .card-description')

    def test_quoted_card_links_to_article(self):
        self.open_nitter(self.quoted_tweet)
        href = self.get_attribute('.quote .article-card .card-container', 'href')
        self.assertIn(f'/article/{self.quoted_article_id}', href)


class ArticleRoutingTest(BaseTestCase):
    def test_username_article_route_redirects(self):
        self.open_nitter('punk2898/article/2064166507438059759')
        self.assert_element_visible(ArticleSelectors.page)
        self.assert_text('1s', ArticleSelectors.title)

    def test_status_article_route_redirects(self):
        self.open_nitter('punk2898/status/2064166507438059759/article')
        self.assert_element_visible(ArticleSelectors.page)
        self.assert_text('1s', ArticleSelectors.title)

    def test_invalid_id_returns_404(self):
        self.open_nitter('i/article/notanumber')
        self.assert_element_not_visible(ArticleSelectors.page)

    def test_nonexistent_article(self):
        self.open_nitter('i/article/1')
        self.assert_element_visible('.error-panel')

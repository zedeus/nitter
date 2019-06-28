from base import BaseTestCase, Tweet, get_timeline_tweet

# image = tweet + 'div.attachments.media-body > div > div > a > div > img'
# self.assert_true(self.get_image_url(image).split('/')[0] == 'http')
class TweetInfo():
    def __init__(self, index, fullname, username, date, text):
        self.index = index
        self.fullname = fullname
        self.username = username
        self.date = date
        self.text = text

timeline_tweets = [
    TweetInfo(1, 'Test account', 'mobile_test', '10 Aug 2016',
              '.'),

    TweetInfo(3, 'Test account', 'mobile_test', '3 Mar 2016',
              'LIVE on #Periscope pscp.tv/w/aadiTzF6dkVOTXZSbX…'),

    TweetInfo(6, 'mobile test 2', 'mobile_test_2', '1 Oct 2014',
              'Testing. One two three four. Test.')
]

status_tweets = [
    TweetInfo(20, 'jack 🌍🌏🌎', 'jack', '21 Mar 2006',
              'just setting up my twttr'),

    TweetInfo(134849778302464000, 'The Twoffice', 'TheTwoffice', '10 Nov 2011',
              'test'),

    TweetInfo(105685475985080322, 'The Twoffice', 'TheTwoffice', '22 Aug 2011',
              'regular tweet'),

    TweetInfo(572593440719912960, 'Test account', 'mobile_test', '2 Mar 2015',
              'testing test')
]

invalid_tweets = [
    'mobile_test/status/120938109238',
    'TheTwoffice/status/8931928312'
]

multiline_tweets = [
    TweetInfo(1142904127594401797, '', 'hot_pengu', '',
              """
New tileset, dust effects, background. The 'sea' has per-line parallax and wavey fx which we think is really cool even tho u didn't notice 🐶.  code: 
@exelotl
  #pixelart #gbadev #gba #indiedev"""),

    TweetInfo(400897186990284800, '', 'mobile_test_3', '',
              """
♔
  KEEP
 CALM
   AND
CLICHÉ
    ON""")
]

class TestTweet(BaseTestCase):
    def test_timeline(self):
        for info in timeline_tweets:
            self.open_nitter(f'{info.username}')
            tweet = get_timeline_tweet(info.index)
            self.assert_exact_text(info.fullname, tweet.fullname)
            self.assert_exact_text('@' + info.username, tweet.username)
            self.assert_exact_text(info.date, tweet.date)
            self.assert_text(info.text, tweet.text)

    def test_status(self):
        tweet = Tweet()
        for info in status_tweets:
            self.open_nitter(f'{info.username}/status/{info.index}')
            self.assert_exact_text(info.fullname, tweet.fullname)
            self.assert_exact_text('@' + info.username, tweet.username)
            self.assert_exact_text(info.date, tweet.date)
            self.assert_text(info.text, tweet.text)

    def test_multiline_formatting(self):
        for info in multiline_tweets:
            self.open_nitter(f'{info.username}/status/{info.index}')
            self.assert_text(info.text.strip('\n'), '.main-tweet')

    def test_emojis(self):
        self.open_nitter('Tesla/status/1134850442511257600')
        self.assert_text('🌈❤️🧡💛💚💙💜', '.main-tweet')

    def test_links(self):
        self.open_nitter('nim_lang/status/1110499584852353024')
        self.assert_text('nim-lang.org/araq/ownedrefs.…', '.main-tweet')
        self.assert_text('news.ycombinator.com/item?id…', '.main-tweet')
        self.assert_text('old.reddit.com/r/programming…', '.main-tweet')

        self.open_nitter('nim_lang/status/1125887775151140864')
        self.assert_text('en.wikipedia.org/wiki/Nim_(p…)', '.main-tweet')

        self.open_nitter('hiankun_taioan/status/1086916335215341570')
        self.assert_text('(hackernoon.com/interview-wit…)', '.main-tweet')

    def test_invalid_id(self):
        for tweet in invalid_tweets:
            self.open_nitter(tweet)
            self.assert_text('Tweet not found', '.error-panel')

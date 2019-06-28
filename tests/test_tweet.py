from base import BaseTestCase, Tweet, get_timeline_tweet
from parameterized import parameterized

# image = tweet + 'div.attachments.media-body > div > div > a > div > img'
# self.assert_true(self.get_image_url(image).split('/')[0] == 'http')

timeline_tweets = [
    [1, 'Test account', 'mobile_test', '10 Aug 2016',
     '.'],

    [3, 'Test account', 'mobile_test', '3 Mar 2016',
     'LIVE on #Periscope pscp.tv/w/aadiTzF6dkVOTXZSbX…'],

    [6, 'mobile test 2', 'mobile_test_2', '1 Oct 2014',
     'Testing. One two three four. Test.']
]

status_tweets = [
    [20, 'jack 🌍🌏🌎', 'jack', '21 Mar 2006',
              'just setting up my twttr'],

    [134849778302464000, 'The Twoffice', 'TheTwoffice', '10 Nov 2011',
              'test'],

    [105685475985080322, 'The Twoffice', 'TheTwoffice', '22 Aug 2011',
              'regular tweet'],

    [572593440719912960, 'Test account', 'mobile_test', '2 Mar 2015',
              'testing test']
]

invalid_tweets = [
    ['mobile_test/status/120938109238'],
    ['TheTwoffice/status/8931928312']
]

multiline_tweets = [
    [1142904127594401797, 'hot_pengu',
     """
New tileset, dust effects, background. The 'sea' has per-line parallax and wavey fx which we think is really cool even tho u didn't notice 🐶.  code: 
@exelotl
  #pixelart #gbadev #gba #indiedev"""],

    [400897186990284800, 'mobile_test_3',
     """
♔
  KEEP
 CALM
   AND
CLICHÉ
    ON"""]
]

link_tweets = [
    ['nim_lang/status/1110499584852353024', [
        'nim-lang.org/araq/ownedrefs.…',
        'news.ycombinator.com/item?id…',
        'old.reddit.com/r/programming…'
    ]],

    ['nim_lang/status/1125887775151140864', [
        'en.wikipedia.org/wiki/Nim_(p…)'
    ]],

    ['hiankun_taioan/status/1086916335215341570', [
        '(hackernoon.com/interview-wit…)'
    ]]
]

emoji_tweets = [
    ['Tesla/status/1134850442511257600', '🌈❤️🧡💛💚💙💜']
]

class TestTweet(BaseTestCase):
    @parameterized.expand(timeline_tweets)
    def test_timeline(self, index, fullname, username, date, text):
        self.open_nitter(username)
        tweet = get_timeline_tweet(index)
        self.assert_exact_text(fullname, tweet.fullname)
        self.assert_exact_text('@' + username, tweet.username)
        self.assert_exact_text(date, tweet.date)
        self.assert_text(text, tweet.text)

    @parameterized.expand(status_tweets)
    def test_status(self, tid, fullname, username, date, text):
        tweet = Tweet()
        self.open_nitter(f'{username}/status/{tid}')
        self.assert_exact_text(fullname, tweet.fullname)
        self.assert_exact_text('@' + username, tweet.username)
        self.assert_exact_text(date, tweet.date)
        self.assert_text(text, tweet.text)

    @parameterized.expand(multiline_tweets)
    def test_multiline_formatting(self, tid, username, text):
        self.open_nitter(f'{username}/status/{tid}')
        self.assert_text(text.strip('\n'), '.main-tweet')

    @parameterized.expand(emoji_tweets)
    def test_emojis(self, tweet, text):
        self.open_nitter(tweet)
        self.assert_text(text, '.main-tweet')

    @parameterized.expand(link_tweets)
    def test_links(self, tweet, links):
        self.open_nitter(tweet)
        for link in links:
            self.assert_text(link, '.main-tweet')

    @parameterized.expand(invalid_tweets)
    def test_invalid_id(self, tweet):
        self.open_nitter(tweet)
        self.assert_text('Tweet not found', '.error-panel')

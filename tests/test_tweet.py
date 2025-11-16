from base import BaseTestCase, Tweet, Conversation, get_timeline_tweet
from parameterized import parameterized

# image = tweet + 'div.attachments.media-body > div > div > a > div > img'
# self.assert_true(self.get_image_url(image).split('/')[0] == 'http')

timeline = [
    [1, 'Test account', 'mobile_test', '10 Aug 2016', '763483571793174528',
     '.'],

    [3, 'Test account', 'mobile_test', '3 Mar 2016', '705522133443571712',
     'LIVE on #Periscope pscp.tv/w/aadiTzF6dkVOTXZSbX…'],

    [6, 'mobile test 2', 'mobile_test_2', '1 Oct 2014', '517449200045277184',
     'Testing. One two three four. Test.']
]

status = [
    [20, 'jack', 'jack', '21 Mar 2006', 'just setting up my twttr'],
    [134849778302464000, 'The Twoffice', 'TheTwoffice', '11 Nov 2011', 'test'],
    [105685475985080322, 'The Twoffice', 'TheTwoffice', '22 Aug 2011', 'regular tweet'],
    [572593440719912960, 'Test account', 'mobile_test', '3 Mar 2015', 'testing test']
]

invalid = [
    ['mobile_test/status/120938109238'],
    ['TheTwoffice/status/8931928312']
]

multiline = [
    [1718660434457239868, 'WebDesignMuseum',
     """
Happy 32nd Birthday HTML tags! 

On October 29, 1991, the internet pioneer, Tim Berners-Lee, published a document entitled HTML Tags. 

The document contained a description of the first 18 HTML tags: <title>, <nextid>, <a>, <isindex>, <plaintext>, <listing>, <p>, <h1>…<h6>, <address>, <hp1>, <hp2>…, <dl>, <dt>, <dd>, <ul>, <li>,<menu> and <dir>. The design of the first version of HTML language was influenced by the SGML universal markup language.

#WebDesignHistory"""]
]

link = [
    ['nim_lang/status/1110499584852353024', [
        'nim-lang.org/araq/ownedrefs.…',
        'news.ycombinator.com/item?id…',
        'teddit.net/r/programming…'
    ]],
    ['nim_lang/status/1125887775151140864', [
        'en.wikipedia.org/wiki/Nim_(p…'
    ]],
    ['hiankun_taioan/status/1086916335215341570', [
        '(hackernoon.com/interview-wit…)'
    ]],
    ['archillinks/status/1146302618223951873', [
        'flickr.com/photos/87101284@N…',
        'hisafoto.tumblr.com/post/176…'
    ]],
    ['archillinks/status/1146292551936335873', [
        'flickr.com/photos/michaelrye…',
        'furtho.tumblr.com/post/16618…'
    ]]
]

username = [
    ['Bountysource/status/1094803522053320705', ['nim_lang']],
    ['leereilly/status/1058464250098704385', ['godotengine', 'unity3d', 'nim_lang']]
]

emoji = [
    ['Tesla/status/1134850442511257600', '🌈❤️🧡💛💚💙💜']
]

retweet = [
    [7, 'mobile_test_2', 'mobile test 2', 'Test account', '@mobile_test', '1234'],
    [3, 'mobile_test_8', 'mobile test 8', 'jack', '@jack', 'twttr']
]


class TweetTest(BaseTestCase):
    @parameterized.expand(timeline)
    def test_timeline(self, index, fullname, username, date, tid, text):
        self.open_nitter(username)
        tweet = get_timeline_tweet(index)
        self.assert_exact_text(fullname, tweet.fullname)
        self.assert_exact_text('@' + username, tweet.username)
        self.assert_exact_text(date, tweet.date)
        self.assert_text(text, tweet.text)
        permalink = self.find_element(tweet.date + ' a')
        self.assertIn(tid, permalink.get_attribute('href'))

    @parameterized.expand(status)
    def test_status(self, tid, fullname, username, date, text):
        tweet = Tweet()
        self.open_nitter(f'{username}/status/{tid}')
        self.assert_exact_text(fullname, tweet.fullname)
        self.assert_exact_text('@' + username, tweet.username)
        self.assert_exact_text(date, tweet.date)
        self.assert_text(text, tweet.text)

    @parameterized.expand(multiline)
    def test_multiline_formatting(self, tid, username, text):
        self.open_nitter(f'{username}/status/{tid}')
        self.assert_text(text.strip('\n'), Conversation.main)

    @parameterized.expand(emoji)
    def test_emoji(self, tweet, text):
        self.open_nitter(tweet)
        self.assert_text(text, Conversation.main)

    @parameterized.expand(link)
    def test_link(self, tweet, links):
        self.open_nitter(tweet)
        for link in links:
            self.assert_text(link, Conversation.main)

    @parameterized.expand(username)
    def test_username(self, tweet, usernames):
        self.open_nitter(tweet)
        for un in usernames:
            link = self.find_link_text(f'@{un}')
            self.assertIn(f'/{un}', link.get_property('href'))

    @parameterized.expand(retweet)
    def test_retweet(self, index, url, retweet_by, fullname, username, text):
        self.open_nitter(url)
        tweet = get_timeline_tweet(index)
        self.assert_text(f'{retweet_by} retweeted', tweet.retweet)
        self.assert_text(text, tweet.text)
        self.assert_exact_text(fullname, tweet.fullname)
        self.assert_exact_text(username, tweet.username)

    @parameterized.expand(invalid)
    def test_invalid_id(self, tweet):
        self.open_nitter(tweet)
        self.assert_text('Tweet not found', '.error-panel')

    #@parameterized.expand(reply)
    #def test_thread(self, tweet, num):
        #self.open_nitter(tweet)
        #thread = self.find_element(f'.timeline > div:nth-child({num})')
        #self.assertIn(thread.get_attribute('class'), 'thread-line')

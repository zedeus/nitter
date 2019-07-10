from seleniumbase import BaseCase


class Tweet(object):
    def __init__(self, tweet=''):
        namerow = tweet + '.tweet-header '
        self.fullname = namerow + '.fullname'
        self.username = namerow + '.username'
        self.date = namerow + '.tweet-date'
        self.text = tweet + '.status-content.media-body'
        self.retweet = tweet = '.retweet'


class Profile(object):
    fullname = '.profile-card-fullname'
    username = '.profile-card-username'
    protected = '.protected-icon'
    verified = '.verified-icon'
    banner = '.profile-banner'
    bio = '.profile-bio'


class Timeline(object):
    newest = 'div[class="status-el show-more"]'
    older = 'div[class="show-more"]'
    end = '.timeline-end'
    none = '.timeline-none'
    protected = '.timeline-protected'


class Conversation(object):
    main = '.main-tweet'
    before = '.before-tweet'
    after = '.after-tweet'
    replies = '.replies'
    thread = '.reply'
    tweet = '.status-el'
    tweet_text = '.status-content'


class Poll(object):
    votes = '.poll-info'
    choice = '.poll-meter'
    value = 'poll-choice-value'
    option = 'poll-choice-option'
    leader = 'leader'


class Media(object):
    container = '.attachments'
    row = '.gallery-row'
    image = '.still-image'
    video = '.gallery-video'
    gif = '.gallery-gif'


class BaseTestCase(BaseCase):
    def setUp(self):
        super(BaseTestCase, self).setUp()

    def tearDown(self):
        super(BaseTestCase, self).tearDown()

    def open_nitter(self, page=''):
        self.open(f'http://localhost:5000/{page}')

    def search_username(self, username):
        self.open_nitter()
        self.update_text('input', username)
        self.submit('form')


def get_timeline_tweet(num=1):
    return Tweet(f'#tweets > div:nth-child({num}) ')

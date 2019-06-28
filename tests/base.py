from seleniumbase import BaseCase


class Tweet(object):
    def __init__(self, tweet=''):
        namerow = tweet + 'div.media-heading > div > .fullname-and-username > '
        self.fullname = namerow + '.fullname'
        self.username = namerow + '.username'
        self.date = tweet + 'div.media-heading > div > .heading-right'
        self.text = tweet + '.status-content-wrapper > .status-content.media-body'


class Profile(object):
    fullname = '.profile-card-fullname'
    username = '.profile-card-username'
    bio = '.profile-bio'
    protected = '.protected-icon'
    verified = '.verified-icon'


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
    return Tweet(f'#tweets > div:nth-child({num}) > div > div ')

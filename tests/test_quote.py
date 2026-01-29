from base import BaseTestCase, Quote, Conversation
from parameterized import parameterized

text = [
    ['nim_lang/status/1491461266849808397#m',
     'Nim', '@nim_lang',
     """What's better than Nim 1.6.0?

Nim 1.6.2 :)

nim-lang.org/blog/2021/12/17…"""]
]

image = [
    ['elonmusk/status/1138827760107790336', 'D83h6Y8UIAE2Wlz'],
    ['SpaceX/status/1067155053461426176', 'Ds9EYfxXoAAPNmx']
]

gif = [
    ['SpaceX/status/747497521593737216', 'Cl-R5yFWkAA_-3X'],
    ['nim_lang/status/1068099315074248704', 'DtJSqP9WoAAKdRC']
]

video = [
    ['bkuensting/status/1067316003200217088', 'IyCaQlzF0q8u9vBd']
]


class QuoteTest(BaseTestCase):
    @parameterized.expand(text)
    def test_text(self, tweet, fullname, username, text):
        self.open_nitter(tweet)
        quote = Quote(Conversation.main + " ")
        self.assert_text(fullname, quote.fullname)
        self.assert_text(username, quote.username)
        self.assert_text(text, quote.text)

    @parameterized.expand(image)
    def test_image(self, tweet, url):
        self.open_nitter(tweet)
        quote = Quote(Conversation.main + " ")
        self.assert_element_visible(quote.media)
        self.assertIn(url, self.get_image_url(quote.media + ' img'))

    @parameterized.expand(gif)
    def test_gif(self, tweet, url):
        self.open_nitter(tweet)
        quote = Quote(Conversation.main + " ")
        self.assert_element_visible(quote.media)
        self.assertIn(url, self.get_attribute(quote.media + ' source', 'src'))

    @parameterized.expand(video)
    def test_video(self, tweet, url):
        self.open_nitter(tweet)
        quote = Quote(Conversation.main + " ")
        self.assert_element_visible(quote.media)
        self.assertIn(url, self.get_image_url(quote.media + ' img'))

from base import BaseTestCase, Card, Conversation
from parameterized import parameterized


card = [
    ['Thom_Wolf/status/1122466524860702729',
     'facebookresearch/fairseq',
     'Facebook AI Research Sequence-to-Sequence Toolkit written in Python. - GitHub - facebookresearch/fairseq: Facebook AI Research Sequence-to-Sequence Toolkit written in Python.',
     'github.com', True],

    ['nim_lang/status/1136652293510717440',
     'Version 0.20.0 released',
     'We are very proud to announce Nim version 0.20. This is a massive release, both literally and figuratively. It contains more than 1,000 commits and it marks our release candidate for version 1.0!',
     'nim-lang.org', True],

    ['voidtarget/status/1094632512926605312',
     'Basic OBS Studio plugin, written in nim, supporting C++ (C fine too)',
     'Basic OBS Studio plugin, written in nim, supporting C++ (C fine too) - obsplugin.nim',
     'gist.github.com', True],

    ['FluentAI/status/1116417904831029248',
     'Amazon’s Alexa isn’t just AI — thousands of humans are listening',
     'One of the only ways to improve Alexa is to have human beings check it for errors',
     'theverge.com', True]
]

no_thumb = [
    ['brent_p/status/1088857328680488961',
     'Hts Nim Sugar',
     'hts-nim is a library that allows one to use htslib via the nim programming language. Nim is a garbage-collected language that compiles to C and often has similar performance. I have become very...',
     'brentp.github.io'],

    ['voidtarget/status/1133028231672582145',
     'sinkingsugar/nimqt-example',
     'A sample of a Qt app written using mostly nim. Contribute to sinkingsugar/nimqt-example development by creating an account on GitHub.',
     'github.com'],

    ['mobile_test/status/490378953744318464',
     'Nantasket Beach',
     'Explore this photo titled Nantasket Beach by Ben Sandofsky (@sandofsky) on 500px',
     '500px.com'],

    ['nim_lang/status/1082989146040340480',
     'Nim in 2018: A short recap',
     'Posted by u/miran1 - 36 votes and 46 comments',
     'reddit.com']
]

playable = [
    ['nim_lang/status/1118234460904919042',
     'Nim development blog 2019-03',
     'Arne (aka Krux02)* debugging: * improved nim-gdb, $ works, framefilter * alias for --debugger:native: -g* bugs: * forwarding of .pure. * sizeof union* fe...',
     'youtube.com'],

    ['nim_lang/status/1121090879823986688',
     'Nim - First natively compiled language w/ hot code-reloading at...',
     '#nim #c++ #ACCUConfNim is a statically typed systems and applications programming language which offers perhaps some of the most powerful metaprogramming cap...',
     'youtube.com']
]

# promo = [
    # ['BangOlufsen/status/1145698701517754368',
    #  'Upgrade your journey', '',
    #  'www.bang-olufsen.com'],

    # ['BangOlufsen/status/1154934429900406784',
    #  'Learn more about Beosound Shape', '',
    #  'www.bang-olufsen.com']
# ]


class CardTest(BaseTestCase):
    @parameterized.expand(card)
    def test_card(self, tweet, title, description, destination, large):
        self.open_nitter(tweet)
        c = Card(Conversation.main + " ")
        self.assert_text(title, c.title)
        self.assert_text(destination, c.destination)
        self.assertIn('_img', self.get_image_url(c.image + ' img'))
        if len(description) > 0:
            self.assert_text(description, c.description)
        if large:
            self.assert_element_visible('.card.large')
        else:
            self.assert_element_not_visible('.card.large')

    @parameterized.expand(no_thumb)
    def test_card_no_thumb(self, tweet, title, description, destination):
        self.open_nitter(tweet)
        c = Card(Conversation.main + " ")
        self.assert_text(title, c.title)
        self.assert_text(destination, c.destination)
        if len(description) > 0:
            self.assert_text(description, c.description)

    @parameterized.expand(playable)
    def test_card_playable(self, tweet, title, description, destination):
        self.open_nitter(tweet)
        c = Card(Conversation.main + " ")
        self.assert_text(title, c.title)
        self.assert_text(destination, c.destination)
        self.assertIn('_img', self.get_image_url(c.image + ' img'))
        self.assert_element_visible('.card-overlay')
        if len(description) > 0:
            self.assert_text(description, c.description)

    # @parameterized.expand(promo)
    # def test_card_promo(self, tweet, title, description, destination):
    #     self.open_nitter(tweet)
    #     c = Card(Conversation.main + " ")
    #     self.assert_text(title, c.title)
    #     self.assert_text(destination, c.destination)
    #     self.assert_element_visible('.video-overlay')
    #     if len(description) > 0:
    #         self.assert_text(description, c.description)

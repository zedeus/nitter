from base import BaseTestCase, Card, Conversation
from parameterized import parameterized


card = [
    ['lorenlugosch/status/1115440394148487168',
     'lorenlugosch/end-to-end-SLU',
     'PyTorch code for end-to-end spoken language understanding (SLU) with ASR-based transfer learning - lorenlugosch/end-to-end-SLU',
     'github.com', False],

    ['PyTorch/status/1123379369672450051',
     'PyTorch',
     'An open source deep learning platform that provides a seamless path from research prototyping to production deployment.',
     'pytorch.org', False],

    ['Thom_Wolf/status/1122466524860702729',
     'pytorch/fairseq',
     'Facebook AI Research Sequence-to-Sequence Toolkit written in Python. - pytorch/fairseq',
     'github.com', False],

    ['TheTwoffice/status/558685306090946561',
     'Eternity: a moment standing still forever…',
     '- James Montgomery. | facebook | 500px | ferpectshotz | I dusted off this one from my old archives, it was taken while I was living in mighty new York city working at Wall St. I think this was the 11...',
     'flickr.com', True],

    ['nim_lang/status/1136652293510717440',
     'Version 0.20.0 released',
     'We are very proud to announce Nim version 0.20. This is a massive release, both literally and figuratively. It contains more than 1,000 commits and it marks our release candidate for version 1.0!',
     'nim-lang.org', True],

    ['nim_lang/status/1082989146040340480',
     'Nim in 2018: A short recap',
     'Posted in r/programming by u/miran1',
     'reddit.com', False],

    ['Tesla/status/1141041022035623936',
     'Experience the Tesla Arcade',
     '',
     'www.tesla.com', True],

    ['voidtarget/status/1094632512926605312',
     'Basic OBS Studio plugin, written in nim, supporting C++ (C fine too)',
     'Basic OBS Studio plugin, written in nim, supporting C++ (C fine too) - obsplugin.nim',
     'gist.github.com', True],

    ['AdsAPI/status/1110272721005367296',
     'Conversation Targeting',
     '',
     'view.highspot.com', True],

    ['FluentAI/status/1116417904831029248',
     'Amazon’s Alexa isn’t just AI — thousands of humans are listening',
     'One of the only ways to improve Alexa is to have human beings check it for errors',
     'theverge.com', True]
]

no_thumb = [
    ['Bountysource/status/1141879700639215617',
     'Post a bounty on kivy/plyer!',
     'Automation and Screen Reader Support',
     'bountysource.com'],

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
     'Rocks on the beach.',
     '500px.com']
]

playable = [
    ['nim_lang/status/1118234460904919042',
     'Nim development blog 2019-03',
     'Arne (aka Krux02) * debugging: * improved nim-gdb, $ works, framefilter * alias for --debugger:native: -g * bugs: * forwarding of .pure. * sizeof union * fea...',
     'youtube.com'],

    ['nim_lang/status/1121090879823986688',
     'Nim - First natively compiled language w/ hot code-reloading at...',
     '#nim #c++ #ACCUConf Nim is a statically typed systems and applications programming language which offers perhaps some of the most powerful metaprogramming ca...',
     'youtube.com']
]

promo = [
    ['BangOlufsen/status/1145698701517754368',
     'Upgrade your journey', '',
     'www.bang-olufsen.com'],

    ['BangOlufsen/status/1154934429900406784',
     'Learn more about Beosound Shape', '',
     'www.bang-olufsen.com']
]


class CardTest(BaseTestCase):
    @parameterized.expand(card)
    def test_card(self, tweet, title, description, destination, large):
        self.open_nitter(tweet)
        card = Card(Conversation.main + " ")
        self.assert_text(title, card.title)
        self.assert_text(destination, card.destination)
        self.assertIn('_img', self.get_image_url(card.image + ' img'))
        if len(description) > 0:
            self.assert_text(description, card.description)
        if large:
            self.assert_element_visible('.card.large')
        else:
            self.assert_element_not_visible('.card.large')

    @parameterized.expand(no_thumb)
    def test_card_no_thumb(self, tweet, title, description, destination):
        self.open_nitter(tweet)
        card = Card(Conversation.main + " ")
        self.assert_text(title, card.title)
        self.assert_text(destination, card.destination)
        if len(description) > 0:
            self.assert_text(description, card.description)

    @parameterized.expand(playable)
    def test_card_playable(self, tweet, title, description, destination):
        self.open_nitter(tweet)
        card = Card(Conversation.main + " ")
        self.assert_text(title, card.title)
        self.assert_text(destination, card.destination)
        self.assertIn('_img', self.get_image_url(card.image + ' img'))
        self.assert_element_visible('.card-overlay')
        if len(description) > 0:
            self.assert_text(description, card.description)

    @parameterized.expand(promo)
    def test_card_promo(self, tweet, title, description, destination):
        self.open_nitter(tweet)
        card = Card(Conversation.main + " ")
        self.assert_text(title, card.title)
        self.assert_text(destination, card.destination)
        self.assert_element_visible('.video-overlay')
        if len(description) > 0:
            self.assert_text(description, card.description)

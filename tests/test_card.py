from base import BaseTestCase, Card, Conversation
from parameterized import parameterized


card = [
    ['nim_lang/status/1136652293510717440',
     'Version 0.20.0 released',
     'We are very proud to announce Nim version 0.20. This is a massive release, both literally and figuratively. It contains more than 1,000 commits and it marks our release candidate for version 1.0!',
     'nim-lang.org', True],

    ['voidtarget/status/1094632512926605312',
     'Basic OBS Studio plugin, written in nim, supporting C++ (C fine too)',
     'Basic OBS Studio plugin, written in nim, supporting C++ (C fine too) - obsplugin.nim',
     'gist.github.com', True],

    ['NASA/status/2061872347477418301',
     'Nancy Grace Roman Space Telescope Mission - NASA Science',
     'The Nancy Grace Roman Space Telescope will settle essential questions in the areas of dark energy, exoplanets, and astrophysics.',
     'science.nasa.gov', True]
]

no_thumb = [
    ['Thom_Wolf/status/1122466524860702729',
     'GitHub - facebookresearch/XLM: PyTorch original implementation of Cross-lingual Language Model',
     'PyTorch original implementation of Cross-lingual Language Model Pretraining.',
     'github.com'],

    ['brent_p/status/1088857328680488961',
     'GitHub - brentp/hts-nim: nim wrapper for htslib for parsing genomics data files',
     '',
     'github.com'],

    ['voidtarget/status/1133028231672582145',
     'sinkingsugar/nimqt-example',
     'A sample of a Qt app written using mostly nim. Contribute to sinkingsugar/nimqt-example development by creating an account on GitHub.',
     'github.com']
]

playable = [
    ['NASA/status/2047048645845897398',
     'NASA\'s Artemis II News Conference with Moon Astronauts',
     'Live from NASA\'s Johnson Space Center in Houston',
     'youtube.com']
]

class CardTest(BaseTestCase):
    @parameterized.expand(card)
    def test_card(self, tweet, title, description, destination, large):
        self.open_nitter(tweet)
        c = Card(Conversation.main + " ")
        self.assert_text(title, c.title)
        self.assert_text(destination, c.destination)
        self.assertIn('/pic/', self.get_image_url(c.image + ' img'))
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

    @parameterized.expand(playable, skip_on_empty=True)
    def test_card_playable(self, tweet, title, description, destination):
        self.open_nitter(tweet)
        c = Card(Conversation.main + " ")
        self.assert_text(title, c.title)
        self.assert_text(destination, c.destination)
        self.assertIn('/pic/', self.get_image_url(c.image + ' img'))
        self.assert_element_visible('.card-overlay')
        if len(description) > 0:
            self.assert_text(description, c.description)

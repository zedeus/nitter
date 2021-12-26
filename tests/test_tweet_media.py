from base import BaseTestCase, Poll, Media
from parameterized import parameterized
from selenium.webdriver.common.by import By

poll = [
    ['nim_lang/status/1064219801499955200', 'Style insensitivity', '91', 1, [
        ('47%', 'Yay'), ('53%', 'Nay')
    ]],

    ['polls/status/1031986180622049281', 'What Tree Is Coolest?', '3,322', 1, [
        ('30%', 'Oak'), ('42%', 'Bonsai'), ('5%', 'Hemlock'), ('23%', 'Apple')
    ]]
]

image = [
    ['mobile_test/status/519364660823207936', 'BzUnaDFCUAAmrjs'],
    ['mobile_test_2/status/324619691039543297', 'BIFH45vCUAAQecj']
]

gif = [
    ['elonmusk/status/1141367104702038016', 'D9bzUqoUcAAfUgf'],
    ['Proj_Borealis/status/1136595194621677568', 'D8X_PJAXUAAavPT']
]

video_m3u8 = [
    ['d0m96/status/1078373829917974528', '9q1-v9w8-ft3awgD.jpg'],
    ['SpaceX/status/1138474014152712192', 'ocJJj2uu4n1kyD2Y.jpg']
]

gallery = [
    ['mobile_test/status/451108446603980803', [
        ['BkKovdrCUAAEz79', 'BkKovdcCEAAfoBO']
    ]],

    ['mobile_test/status/471539824713691137', [
        ['Bos--KNIQAAA7Li', 'Bos--FAIAAAWpah'],
        ['Bos--IqIQAAav23']
    ]],

    ['mobile_test/status/469530783384743936', [
        ['BoQbwJAIUAA0QCY', 'BoQbwN1IMAAuTiP'],
        ['BoQbwarIAAAlaE-', 'BoQbwh_IEAA27ef']
    ]]
]


class MediaTest(BaseTestCase):
    @parameterized.expand(poll)
    def test_poll(self, tweet, text, votes, leader, choices):
        self.open_nitter(tweet)
        self.assert_text(text, '.main-tweet')
        self.assert_text(votes, Poll.votes)

        poll_choices = self.find_elements(Poll.choice)
        for i, (v, o) in enumerate(choices):
            choice = poll_choices[i]
            value = choice.find_element(By.CLASS_NAME, Poll.value)
            option = choice.find_element(By.CLASS_NAME, Poll.option)
            choice_class = choice.get_attribute('class')

            self.assert_equal(v, value.text)
            self.assert_equal(o, option.text)

            if i == leader:
                self.assertIn(Poll.leader, choice_class)
            else:
                self.assertNotIn(Poll.leader, choice_class)

    @parameterized.expand(image)
    def test_image(self, tweet, url):
        self.open_nitter(tweet)
        self.assert_element_visible(Media.container)
        self.assert_element_visible(Media.image)

        image_url = self.get_image_url(Media.image + ' img')
        self.assertIn(url, image_url)

    @parameterized.expand(gif)
    def test_gif(self, tweet, gif_id):
        self.open_nitter(tweet)
        self.assert_element_visible(Media.container)
        self.assert_element_visible(Media.gif)

        url = self.get_attribute('source', 'src')
        thumb = self.get_attribute('video', 'poster')
        self.assertIn(gif_id + '.mp4', url)
        self.assertIn(gif_id + '.jpg', thumb)

    @parameterized.expand(video_m3u8)
    def test_video_m3u8(self, tweet, thumb):
        # no url because video playback isn't supported yet
        self.open_nitter(tweet)
        self.assert_element_visible(Media.container)
        self.assert_element_visible(Media.video)

        video_thumb = self.get_attribute(Media.video + ' img', 'src')
        self.assertIn(thumb, video_thumb)

    @parameterized.expand(gallery)
    def test_gallery(self, tweet, rows):
        self.open_nitter(tweet)
        self.assert_element_visible(Media.container)
        self.assert_element_visible(Media.row)
        self.assert_element_visible(Media.image)

        gallery_rows = self.find_elements(Media.row)
        self.assert_equal(len(rows), len(gallery_rows))

        for i, row in enumerate(gallery_rows):
            images = row.find_elements(By.CSS_SELECTOR, 'img')
            self.assert_equal(len(rows[i]), len(images))
            for j, image in enumerate(images):
                self.assertIn(rows[i][j], image.get_attribute('src'))

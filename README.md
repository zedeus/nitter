
<br>

<div align = center>

[![Badge Status]][Actions]   
[![Badge Matrix]][Matrix]   
[![Badge License]][License]

<br>
<br>

<img
    src = 'public/logo.png'
    width = 200
/>


# Nitter

*A free and open source alternative Twitter* <br>
*front-end focused on privacy and performance.*

Inspired by the **[Invidious]** project.

<br>
<br>

[![Button Instances]][Instances]   
[![Button Extensions]][Extensions]

<br>
<br>

## Features

<kbd>  <br>  <b>Prevents</b><br><br><br>  Ｆｉｎｇｅｒｐｒｉｎｔｉｎｇ  <br><br><br>  ＩＰ　Ｔｒａｃｋｉｎｇ  <br><br>  </kbd>   
<kbd>  <br>  <b>Lightweight</b><br><br><br>  For [@nim_lang], `60KB` vs  <br><br><br>  `784KB` from Twitter.com  <br><br>  </kbd>   
<kbd>  <br>  <b>Provides</b><br><br><br>  ＲＳＳ　Ｆｅｅｄｓ  <br><br><br>  Ｔｈｅｍｅｓ  <br><br>  </kbd>

<kbd>  <br>  <b>No</b><br><br><br>                 Ａｃｃｏｕｎｔ　Ｒｅｑｕｉｒｅｄ         Ａｄｖｅｒｔｉｓｅｍｅｎｔｓ                      <br><br><br>  Ｒａｔｅ　Ｌｉｍｉｔｉｎｇ                    ＪａｖａＳｃｒｉｐｔ       <br><br>  </kbd>

<kbd>  <br>         <b>Mobile Support</b>         <br><br><br>  *Responsive*  <br>  *Design*  <br><br>  </kbd>   
<kbd>  <br>         <b>AGPLv3 Licensed</b>         <br><br><br>  *Forbids Proprietary*  <br>  *Instances*  <br><br>  </kbd>   
<kbd>  <br>        <b>Decoupled        <br><br>  From  <br><br>  Twitter</b>  <br><br>  </kbd>


<br>
<br>

## Roadmap

<br>

<kbd>  <br>  Embeds  <br>  </kbd>    ❯    
<kbd>  <br>  Account System  <br>  +  <br>  Timeline Support  <br>  </kbd>    ❯    
<kbd>  <br>  Archiving  <br><br>  Tweets / Profiles  <br>  </kbd>    ❯    
<kbd>  <br>  Developer API  <br>  </kbd>

<br>
<br>

![Showcase]

</div>

<br>
<br>

## Why?

It's impossible to use Twitter without JavaScript enabled. For privacy-minded
folks, preventing JavaScript analytics and IP-based tracking is important, but
apart from using a VPN and uBlock/uMatrix, it's impossible. Despite being behind
a VPN and using heavy-duty adblockers, you can get accurately tracked with your
[browser's fingerprint][Fingerprint],
[no JavaScript required][JavaScript]. This all became
particularly important after Twitter [removed the
ability][Advertisers]
for users to control whether their data gets sent to advertisers.

Using an instance of Nitter (hosted on a VPS for example), you can browse
Twitter without JavaScript while retaining your privacy. In addition to
respecting your privacy, Nitter is on average around 15 times lighter than
Twitter, and in most cases serves pages faster (eg. timelines load 2-4x faster).

In the future a simple account system will be added that lets you follow Twitter
users, allowing you to have a clean chronological timeline without needing a
Twitter account.

<br>
<br>

## Contact

You can email me at zedeus@pm.me <br>
if you wish to speak to me personally.

<br>


<!----------------------------------------------------------------------------->

[nim-lang.org]: https://nim-lang.org/install.html
[Advertisers]: https://www.eff.org/deeplinks/2020/04/twitter-removes-privacy-option-and-shows-why-we-need-strong-privacy-laws
[Fingerprint]: https://restoreprivacy.com/browser-fingerprinting/
[JavaScript]: https://noscriptfingerprint.com/
[Invidious]: https://github.com/iv-org/invidious
[@nim_lang]: https://nitter.net/nim_lang
[ARM Info]: https://github.com/zedeus/nitter/issues/399#issuecomment-997263495
[Unixfox]: https://quay.io/repository/unixfox/nitter?tab=tags
[Actions]: https://github.com/zedeus/nitter/actions
[Matrix]: https://matrix.to/#/#nitter:matrix.org

[Extensions]: https://github.com/zedeus/nitter/wiki/Extensions
[Instances]: https://github.com/zedeus/nitter/wiki/Instances
[Apache]: https://github.com/zedeus/nitter/wiki/Apache
[Nginx]: https://github.com/zedeus/nitter/wiki/Nginx

[Showcase]: screenshot.png
[License]: LICENSE

<!---------------------------------[ Badges ]---------------------------------->

[Badge License]: https://img.shields.io/badge/License-AGPL3-015d93.svg?style=for-the-badge&labelColor=blue
[Badge Matrix]: https://img.shields.io/badge/Matrix-0b9e72.svg?style=for-the-badge&labelColor=0DBD8B&logoColor=white&logo=Matrix
[Badge Status]: https://img.shields.io/github/workflow/status/zedeus/nitter/CI-CD?style=for-the-badge&labelColor=86238f&color=641a6b


<!---------------------------------[ Buttons ]--------------------------------->

[Button Extensions]: https://img.shields.io/badge/Extensions-009CAB.svg?style=for-the-badge&logoColor=white&logo=GitExtensions
[Button Instances]: https://img.shields.io/badge/Instances-DE4F4F.svg?style=for-the-badge&logoColor=white&logo=ROS

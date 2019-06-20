#? stdtmpl(subsChar = '$', metaChar = '#')
#import xmltree, strutils, uri, htmlgen
#import ../types, ../formatters, ../utils
#import ./tweet
#
#proc renderProfileCard*(profile: Profile): string =
#let pic = profile.getUserpic().getSigUrl("pic")
#let smallPic = profile.getUserpic("_200x200").getSigUrl("pic")
<div class="profile-card">
  <a class="profile-card-avatar" href="${pic}">
    <img src="${smallPic}">
  </a>
  <div class="profile-card-tabs">
    <div class="profile-card-tabs-name">
      ${linkUser(profile, "h1", class="profile-card-name", username=false)}
      ${linkUser(profile, "h2", class="profile-card-username")}
    </div>
  </div>
  <div class="profile-card-extra">
    <div class="profile-bio">
      #if profile.description.len > 0:
      <div class="profile-description">
        <p>${linkifyText(xmltree.escape(profile.description))}</p>
      </div>
      #end if
    </div>

    <div class="profile-card-extra-links">
      <ul class="profile-statlist">
        <li class="tweets">
          <span class="profile-stat-header">Tweets</span>
          <span>${$profile.tweets}</span>
        </li>
        <li class="followers">
          <span class="profile-stat-header">Followers</span>
          <span>${$profile.followers}</span>
        </li>
        <li class="following">
          <span class="profile-stat-header">Following</span>
          <span>${$profile.following}</span>
        </li>
      </ul>
    </div>
  </div>
</div>
#end proc
#
#proc renderBanner(profile: Profile): string =
#if "#" in profile.banner:
<div style="${profile.banner}" class="profile-banner-color"></div>
#else:
#let url = getSigUrl(profile.banner, "pic")
<a href="${url}">
  <img src="${url}">
</a>
#end if
#end proc
#
#proc renderTimeline*(tweets: Tweets; profile: Profile; beginning: bool): string =
<div id="tweets">
  #if profile.protected:
  <div class="timeline-protected">
    <h2 class="timeline-protected-header">This account's Tweets are protected.</h2>
    <p class="timeline-protected-explanation">Only confirmed followers have access to @${profile.username}'s Tweets.
  </div>
  #end if
  #if not beginning:
  <div class="show-more status-el">
    <a href="/${profile.username}">Load newest tweets</a>
  </div>
  #end if
  #var retweets: Tweets
  #for tweet in tweets:
    #if tweet in retweets: continue
    #end if
    #if tweet.retweetBy.isSome: retweets.add tweet
    #end if
    ${renderTweet(tweet, "timeline-tweet")}
  #end for
  #if tweets.len > 0:
  <div class="show-more">
    <a href="/${profile.username}?after=${$tweets[^1].id}">Load older tweets</a>
  </div>
  #end if
</div>
#end proc
#
#proc renderProfile*(profile: Profile; tweets: Tweets; beginning: bool): string =
<div class="profile-tabs">
  <div class="profile-banner">
    ${renderBanner(profile)}
  </div>
  <div class="profile-tab">
    ${renderProfileCard(profile)}
  </div>
  <div class="timeline-tab">
    ${renderTimeline(tweets, profile, beginning)}
  </div>
</div>
#end proc

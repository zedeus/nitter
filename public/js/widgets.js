let iframeMap = {}

const instance = 'https://nitter.net'
const tweet_regex = /^https?:\/\/twitter\.com\/[^/]+\/status\/(\d+)\??/
const blockquotes = document.querySelectorAll('blockquote.twitter-tweet > a')
for (const blockquote of blockquotes) {
  const link = blockquote.href
  const id = tweet_regex.exec(link)[1]
  const embed = document.createElement('iframe')
  const url = `${instance}/i/status/${id}/embed`
  embed.src = url
  embed.style = 'width:100%;height:600px'
  embed.loading = 'lazy'
  blockquote.parentNode.replaceWith(embed)
  if (iframeMap[url]) {
    iframeMap[url].push(embed)
  } else {
    iframeMap[url] = [embed]
  }
}

window.addEventListener('message', function(e) {
  if (e.origin != instance || e.data[0] != 'resizeIframe')
    return
  
  const data = e.data[1];
  const height = data['h']
  if (height == 0)
    return
  for (const embed of iframeMap[data['url']]) {
    embed.style.height = `${height}px`
  }
}, false);

import 'dart:convert';
import 'package:onetouch/core/web_links.dart';

// 서비스가 제공하는 임베드만 실행해요. 게시글 본문이나 외부 페이지 HTML은 넣지 않아요.
String communitySocialEmbedHtml(Uri uri, {required String language}) {
  final kind = webLinkKind(uri);
  final canonical = socialPostUri(uri);
  final url = const HtmlEscape().convert(canonical.toString());
  final script = kind == WebLinkKind.x
      ? '''
<script src="https://platform.x.com/widgets.js" onerror="fail()"></script>
<script>
if (window.twttr) twttr.ready(function(twitter) {
  twitter.widgets.createTweet(${jsonEncode(canonical.pathSegments.last)}, host, {
    theme: 'light', dnt: true, lang: ${jsonEncode(language)},
    width: host.clientWidth
  }).then(function(element) {
    if (element) { ready = true; measure(); } else { fail(); }
  }).catch(fail);
});
</script>'''
      : '''
<script>
host.innerHTML = '<blockquote class="instagram-media" data-instgrm-captioned data-instgrm-permalink="$url" data-instgrm-version="14" style="margin:0;width:calc(100% - 2px)"><a href="$url">Instagram</a></blockquote>';
</script>
<script async src="https://www.instagram.com/embed.js" onerror="fail()"></script>''';
  return '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>
html, body { margin:0; padding:0; background:transparent; overflow:hidden; }
#embed { display:flow-root; width:100%; transform-origin:top left; }
.twitter-tweet, .instagram-media { margin:0 !important; }
</style></head><body><div id="embed"></div>
<script>
const host = document.getElementById('embed');
let ready = false;
// Instagram 공식 최소 너비 326px와 양쪽 테두리를 좁은 화면에서도 모두 보여요.
function fit() {
  const width = document.documentElement.clientWidth;
  const minimum = ${kind == WebLinkKind.instagram ? 328 : 250};
  host.style.width = Math.max(width, minimum) + 'px';
  host.style.transform = 'scale(' + Math.min(1, width / minimum) + ')';
}
fit();
window.addEventListener('resize', function() { fit(); measure(); });
function fail() { LinkEmbed.postMessage(JSON.stringify({error:true})); }
function measure() {
  if (!ready) return;
  const height = Math.ceil(host.getBoundingClientRect().height);
  if (height > 0) LinkEmbed.postMessage(JSON.stringify({height:height}));
}
new ResizeObserver(measure).observe(host);
new MutationObserver(function() {
  const frame = host.querySelector('iframe');
  if (frame && !frame.dataset.observed) {
    frame.dataset.observed = 'true';
    frame.addEventListener('load', function() { ready = true; measure(); });
    new ResizeObserver(measure).observe(frame);
  }
  measure();
}).observe(host, {childList:true, subtree:true});
</script>$script</body></html>''';
}

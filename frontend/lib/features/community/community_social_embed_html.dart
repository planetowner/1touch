import 'dart:convert';
import 'package:onetouch/core/web_links.dart';

// 서비스가 제공하는 임베드만 실행해요. 게시글 본문이나 외부 페이지 HTML은 넣지 않아요.
String communitySocialEmbedHtml(Uri uri,
    {required String language, required bool isDark, required double width}) {
  final kind = webLinkKind(uri);
  final canonical = socialPostUri(uri);
  final url = const HtmlEscape().convert(canonical.toString());
  final script = kind == WebLinkKind.x
      ? '''
<script src="https://platform.x.com/widgets.js" onerror="fail()"></script>
<script>
if (window.twttr) twttr.ready(function(twitter) {
  twitter.widgets.createTweet(${jsonEncode(canonical.pathSegments.last)}, host, {
    theme: '${isDark ? 'dark' : 'light'}', dnt: true, lang: ${jsonEncode(language)}
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
<html><head><meta name="viewport" content="width=$width, initial-scale=1">
<style>
html, body { margin:0; padding:0; background:transparent; overflow:hidden; }
#embed { display:flow-root; width:100%; transform-origin:top left; }
.twitter-tweet, .instagram-media { margin:0 !important; }
</style></head><body><div id="embed"></div>
<script>
const host = document.getElementById('embed');
let ready = false;
${kind == WebLinkKind.instagram ? '''
let instagramHeight;
window.addEventListener('message', function(event) {
  const frame = host.querySelector('iframe');
  if (event.origin !== 'https://www.instagram.com' || !frame || event.source !== frame.contentWindow) return;
  let data;
  try { data = JSON.parse(event.data); } catch (_) { return; }
  if (data.type === 'MEASURE' && Number.isFinite(data.details.height) && data.details.height > 0) {
    instagramHeight = data.details.height;
    measure();
  }
});
''' : ''}
// Instagram 공식 최소 너비 326px와 양쪽 테두리를 좁은 화면에서도 모두 보여요.
function fit() {
  // 화면에 붙이기 전에도 상세 본문 너비로 카드와 높이를 미리 계산해요.
  const width = $width;
  const minimum = ${kind == WebLinkKind.instagram ? 328 : 250};
  host.style.width = Math.max(width, minimum) + 'px';
  host.style.transform = 'scale(' + Math.min(1, width / minimum) + ')';
}
fit();
window.addEventListener('resize', function() { fit(); measure(); });
function fail() { LinkEmbed.postMessage(JSON.stringify({error:true})); }
function measure() {
  ${kind == WebLinkKind.instagram ? '''
  // iframe load는 높이 18px인 중간 상태에도 발생해요. 공식 측정값이 적용된 뒤 표시해요.
  const frame = host.querySelector('iframe');
  if (!frame || instagramHeight === undefined || Number(frame.getAttribute('height')) !== instagramHeight) return;
  ready = true;
  ''' : ''}
  if (!ready) return;
  const height = Math.ceil(host.getBoundingClientRect().height);
  if (height > 0) LinkEmbed.postMessage(JSON.stringify({height:height}));
}
new ResizeObserver(measure).observe(host);
new MutationObserver(function() {
  const frame = host.querySelector('iframe');
  if (frame && !frame.dataset.observed) {
    frame.dataset.observed = 'true';
    frame.addEventListener('load', measure);
    new ResizeObserver(measure).observe(frame);
  }
  measure();
}).observe(host, {childList:true, subtree:true});
</script>$script</body></html>''';
}

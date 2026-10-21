/* Offline support for the installed webtools apps.

   Network first so updates are picked up immediately when online; every
   successful GET (pages, icons, CDN assets) is cached as a fallback for when
   the network is unavailable. Integrity (SRI) is still enforced by the page
   on responses served from the cache.
*/
const CACHE = 'webtools-v1';

/* Usage stats: every app load is a navigation through this worker, and also
   when it checks for a new version (network first). Each one is counted on
   hitscounter.dev, keyed by the page URL so each app has its own counter.
   History: https://hitscounter.dev/history?url=<page URL>
   Only on the published site, so local testing doesn't create counters.
*/
const COUNTER = 'https://hitscounter.dev/api/hit?output=json&url=';
const SITE = 'dermoth.github.io';

function countLoad(request) {
	const url = new URL(request.url);
	// no-cors: the response isn't used, so the counter needn't allow CORS
	return fetch(COUNTER + encodeURIComponent(url.origin + url.pathname), { mode: 'no-cors' })
		.catch(() => {});  // Offline or counter down: not worth an error
}

self.addEventListener('fetch', (event) => {
	if (event.request.method !== 'GET')
		return;
	if (event.request.mode === 'navigate' && self.location.hostname === SITE)
		event.waitUntil(countLoad(event.request));

	event.respondWith(
		fetch(event.request)
			.then((response) => {
				if (response.ok) {
					const copy = response.clone();
					event.waitUntil(caches.open(CACHE)
						.then((cache) => cache.put(event.request, copy)));
				}
				return response;
			})
			.catch(() => caches.match(event.request)),
	);
});

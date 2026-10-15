/* Offline support for the installed webtools apps.

   Network first so updates are picked up immediately when online; every
   successful GET (pages, icons, CDN assets) is cached as a fallback for when
   the network is unavailable. Integrity (SRI) is still enforced by the page
   on responses served from the cache.
*/
const CACHE = 'webtools-v1';

self.addEventListener('fetch', (event) => {
	if (event.request.method !== 'GET')
		return;

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

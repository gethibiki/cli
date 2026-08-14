// Cloudflare Worker — serves install.sh at cli.gethibiki.com.
//
// Behaviour:
//   - GET /            → install.sh body (cached at the edge, 5 min TTL)
//   - GET /install.sh  → same
//   - GET anything else with a browser User-Agent → 302 to the docs page, so
//     a curious human visiting the URL lands on prose instead of a wall of
//     shell script
//   - HEAD             → headers only (some installers and curl invocations
//     probe with this first)
//
// Source of truth is install.sh on the main branch of this repository.

const SOURCE_URL = 'https://raw.githubusercontent.com/gethibiki/cli/main/install.sh';
const DOCS_URL = 'https://github.com/gethibiki/cli#readme';
// 5 minute edge cache. Short enough that a fix to install.sh propagates
// quickly; long enough that a busy day doesn't hammer the origin.
const EDGE_CACHE_TTL = 300;

export default {
  /**
   * @param {Request} request
   * @param {object}  env       (unused — no secrets or bindings)
   * @param {object}  ctx
   * @returns {Promise<Response>}
   */
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Browser-like UA on any path → docs. The test is deliberately loose:
    // anything that smells like a real browser gets redirected, everything
    // else (curl, wget, fetch libraries, CI runners) gets the script.
    if (request.method === 'GET' && looksLikeBrowser(request.headers.get('user-agent'))) {
      return Response.redirect(DOCS_URL, 302);
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('method not allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }

    // Only the root and /install.sh serve the script. Everything else 404s, so
    // this can never be turned into an open proxy for arbitrary GitHub paths.
    if (url.pathname !== '/' && url.pathname !== '/install.sh') {
      return new Response('not found', { status: 404 });
    }

    return await fetchInstallScript(request, ctx);
  },
};

/**
 * Fetch install.sh from GitHub raw, cache it at the edge, and return it with
 * shell-friendly headers.
 */
async function fetchInstallScript(request, ctx) {
  const upstream = await fetch(SOURCE_URL, {
    cf: {
      // cacheEverything forces caching of non-default content types;
      // cacheTtl pins the duration.
      cacheEverything: true,
      cacheTtl: EDGE_CACHE_TTL,
    },
    headers: {
      // Identify ourselves, so a GitHub abuse sweep has a contact path.
      'User-Agent': 'hibiki-cli-installer-worker (+https://github.com/gethibiki/cli)',
    },
  });

  if (!upstream.ok) {
    // Never pass GitHub's HTML 404 through verbatim: the response is being
    // piped into `sh`, and an HTML body parses as garbage shell. A commented
    // message and an explicit `exit 1` fail cleanly and say why.
    return new Response(
      `# install.sh upstream fetch failed: ${upstream.status} ${upstream.statusText}\n` +
        `# expected: ${SOURCE_URL}\n` +
        `exit 1\n`,
      {
        status: 502,
        headers: { 'Content-Type': 'text/x-shellscript; charset=utf-8' },
      }
    );
  }

  const headers = new Headers();
  headers.set('Content-Type', 'text/x-shellscript; charset=utf-8');
  // Honour the upstream ETag so a 304 round-trip works for CDN-aware clients.
  const etag = upstream.headers.get('etag');
  if (etag) headers.set('ETag', etag);
  headers.set('Cache-Control', `public, max-age=${EDGE_CACHE_TTL}`);
  headers.set('X-Content-Type-Options', 'nosniff');

  return new Response(upstream.body, { status: 200, headers });
}

/**
 * Loose browser detection. The question is "did a human paste this into an
 * address bar", not "prove it was a browser". Anything starting with
 * "Mozilla/" — essentially every real browser — is redirected; everything
 * else is treated as a programmatic client.
 *
 * @param {string | null} ua
 */
function looksLikeBrowser(ua) {
  if (!ua) return false;
  return /^Mozilla\//i.test(ua);
}

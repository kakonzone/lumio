/**
 * Cloudflare Worker for proxying HTTP IPTV streams through HTTPS.
 *
 * This worker acts as an HTTPS-to-HTTP proxy for legacy IPTV streams that
 * don't support HTTPS. It forwards requests to the HTTP backend and streams
 * the response back to the client over HTTPS.
 *
 * USAGE:
 * - Deploy this worker to Cloudflare Workers
 * - Use URL: https://your-worker.workers.dev/stream?url=http://backend.com/stream.m3u8
 * - Configure proxy URL in Flutter app via StreamUpgradeService
 *
 * SECURITY NOTES:
 * - Only proxies whitelisted domains to prevent abuse
 * - Adds CORS headers for cross-origin requests
 * - Streams responses to avoid buffering large files
 * - Rate limiting recommended for production use
 */

// Whitelist of allowed HTTP domains (prevent open proxy abuse)
const ALLOWED_DOMAINS = new Set([
  '103.180.212.191',
  '202.70.146.135',
  '103.175.73.12',
  '103.182.83.246',
  '115.187.41.216',
  '138.68.138.119',
  '145.239.5.177',
  '146.59.253.52',
  '15.235.185.236',
  '15.235.187.72',
  '151.80.18.177',
  '158.69.24.53',
  '179.60.224.196',
  '181.118.156.46',
  '181.205.205.173',
  '185.132.134.159',
  '185.193.19.32',
  '185.46.48.18',
  '185.57.68.33',
  '198.195.239.50',
  '200.10.30.241',
  '200.115.120.1',
  '202.80.222.20',
  '210.4.72.204',
  '212.102.60.80',
  '217.174.225.146',
  '31.148.48.15',
  '41.205.93.154',
  '45.5.119.43',
  '68.183.41.209',
  '82.212.74.98',
  '88.212.15.19',
  '94.136.188.21',
  '99.27.51.147',
]);

// CORS headers for cross-origin requests
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, User-Agent, Range',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Type, Content-Range',
};

/**
 * Main worker entry point
 */
export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // Only allow GET and HEAD requests
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', {
        status: 405,
        headers: CORS_HEADERS,
      });
    }

    try {
      const url = new URL(request.url);
      const targetUrl = url.searchParams.get('url');

      if (!targetUrl) {
        return new Response('Missing url parameter', {
          status: 400,
          headers: CORS_HEADERS,
        });
      }

      // Validate and parse target URL
      let target;
      try {
        target = new URL(targetUrl);
      } catch (e) {
        return new Response('Invalid target URL', {
          status: 400,
          headers: CORS_HEADERS,
        });
      }

      // Security: Only allow HTTP targets (no HTTPS proxying)
      if (target.protocol !== 'http:') {
        return new Response('Only HTTP URLs are allowed', {
          status: 403,
          headers: CORS_HEADERS,
        });
      }

      // Security: Check domain whitelist
      const domain = target.hostname;
      if (!ALLOWED_DOMAINS.has(domain)) {
        return new Response(`Domain ${domain} not allowed`, {
          status: 403,
          headers: CORS_HEADERS,
        });
      }

      // Copy relevant headers from original request
      const headers = new Headers();
      const allowedHeaders = ['user-agent', 'range', 'accept-encoding'];
      for (const header of allowedHeaders) {
        const value = request.headers.get(header);
        if (value) {
          headers.set(header, value);
        }
      }

      // Forward request to HTTP backend
      const proxyRequest = new Request(target.toString(), {
        method: request.method,
        headers: headers,
        redirect: 'follow',
      });

      const response = await fetch(proxyRequest);

      if (!response.ok) {
        return new Response(`Backend returned ${response.status}`, {
          status: response.status,
          headers: CORS_HEADERS,
        });
      }

      // Stream the response back to client
      const corsResponse = new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: {
          ...CORS_HEADERS,
          'Content-Type': response.headers.get('Content-Type') || 'application/octet-stream',
          'Content-Length': response.headers.get('Content-Length') || '',
          'Content-Range': response.headers.get('Content-Range') || '',
          'Accept-Ranges': response.headers.get('Accept-Ranges') || '',
          'Cache-Control': response.headers.get('Cache-Control') || 'no-cache',
        },
      });

      return corsResponse;
    } catch (error) {
      console.error('Proxy error:', error);
      return new Response('Proxy error: ' + error.message, {
        status: 500,
        headers: CORS_HEADERS,
      });
    }
  },
};

/**
 * Alternative implementation with caching for better performance
 * Uncomment if you want to use Cloudflare KV caching
 */
/*
export default {
  async fetch(request, env, ctx) {
    // ... (same CORS and validation as above)

    try {
      const cacheKey = `stream:${targetUrl}`;
      let response;

      // Try to get from cache
      if (env.CACHE) {
        const cached = await env.CACHE.get(cacheKey, { type: 'stream' });
        if (cached) {
          return new Response(cached, {
            headers: {
              ...CORS_HEADERS,
              'Content-Type': 'application/x-mpegURL',
              'X-Cache': 'HIT',
            },
          });
        }
      }

      // Forward request to HTTP backend
      const proxyRequest = new Request(target.toString(), {
        method: request.method,
        headers: headers,
        redirect: 'follow',
      });

      response = await fetch(proxyRequest);

      if (!response.ok) {
        return new Response(`Backend returned ${response.status}`, {
          status: response.status,
          headers: CORS_HEADERS,
        });
      }

      // Cache the response for small playlists (M3U files)
      const contentType = response.headers.get('Content-Type') || '';
      if (contentType.includes('mpegurl') || contentType.includes('m3u')) {
        const body = await response.text();
        
        if (env.CACHE) {
          ctx.wait(env.CACHE.put(cacheKey, body, {
            expirationTtl: 300, // 5 minutes
          }));
        }

        return new Response(body, {
          headers: {
            ...CORS_HEADERS,
            'Content-Type': contentType,
            'X-Cache': 'MISS',
          },
        });
      }

      // Stream large files (video chunks)
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: {
          ...CORS_HEADERS,
          'Content-Type': contentType,
        },
      });
    } catch (error) {
      console.error('Proxy error:', error);
      return new Response('Proxy error: ' + error.message, {
        status: 500,
        headers: CORS_HEADERS,
      });
    }
  },
};
*/

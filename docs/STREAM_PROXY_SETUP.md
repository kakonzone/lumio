# Stream Proxy Setup (Signed URL Service)

This app no longer ships credentialed stream URLs in source. Protected streams must be resolved via backend-issued signed URLs.

## Required dart-define

- `STREAM_TOKEN_BASE_URL=https://your-secure-api.example.com`

## Endpoint contract (minimum)

- Method: `POST`
- Path: `/v1/stream/token`
- Content-Type: `application/json`

Request:

```json
{
  "channel_id": "sky_sports_1",
  "source_url": "http://origin.example/live/stream.ts"
}
```

Response (success):

```json
{
  "url": "https://signed.example/cdn/stream.m3u8?token=...",
  "expires_at": 1719999999
}
```

Error:

```json
{
  "error": "forbidden"
}
```

Status code should be `401`/`403` for invalid auth/source.

## Cloudflare Worker sketch

```js
export default {
  async fetch(req, env) {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
    const { channel_id, source_url } = await req.json();
    if (!channel_id || !source_url) return Response.json({ error: "bad_request" }, { status: 400 });
    // TODO: validate channel + source allowlist, then sign
    const signed = await signSourceUrl(source_url, env.SIGNING_SECRET);
    return Response.json({ url: signed, expires_at: Math.floor(Date.now() / 1000) + 300 });
  }
};
```

Keep this endpoint HTTPS-only.

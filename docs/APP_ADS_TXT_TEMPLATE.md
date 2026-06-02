# app-ads.txt template (lumio.app)

Host this file at **`https://lumio.app/app-ads.txt`** (root domain, exact path).

Replace placeholders with your publisher IDs from each network dashboard.

```text
# Lumio TV — app-ads.txt
# https://iabtechlab.com/ads-txt/

# Google AdMob (if used later)
# google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0

# ironSource / LevelPlay (Unity mediation)
# Contact ironSource for your authorized seller line format.

# Unity Ads (via LevelPlay — list Unity seller if required by your account rep)
# unity.com, XXXXX, DIRECT

# Monetag / PropellerAds (verify exact domain + ID with Monetag support)
# propellerads.com, YOUR_PUBLISHER_ID, DIRECT

# Adsterra (verify with Adsterra — often partner-specific)
# adsterra.com, YOUR_ID, DIRECT
```

## Checklist

1. Publish `app-ads.txt` on the **same domain** as your marketing site (`lumio.app`).
2. Add each network only after the account is approved and IDs are confirmed.
3. Re-crawl in [IAB ads.txt validator](https://adstxt.guru/) after deploy.
4. Link the domain in **AdMob / ironSource / Monetag / Adsterra** dashboards if required.

## App package

- Android: `com.kakonzone.lumio`
- Store listing URL (when live): use Play Store or landing page that references this domain.

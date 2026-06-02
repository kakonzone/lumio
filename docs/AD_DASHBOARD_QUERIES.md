# Ad fill — Firebase Analytics queries

Events: `ad_waterfall_attempt`, `ad_impression` (see `lib/ads/analytics/ad_fill_analytics.dart`).

## BigQuery (example)

```sql
SELECT
  event_date,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'network') AS network,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'filled') AS filled,
  COUNT(*) AS attempts
FROM `project.analytics_XXX.events_*`
WHERE event_name = 'ad_waterfall_attempt'
  AND _TABLE_SUFFIX BETWEEN '20260101' AND '20261231'
GROUP BY 1, 2, 3
ORDER BY 1 DESC, attempts DESC;
```

## Fill rate

```sql
SELECT
  network,
  SAFE_DIVIDE(SUM(filled), COUNT(*)) AS fill_rate
FROM (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'network') AS network,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'filled') AS filled
  FROM `project.analytics_XXX.events_*`
  WHERE event_name = 'ad_waterfall_attempt'
)
GROUP BY network;
```

-- Supply 
WITH stake_unstake_events AS (
    SELECT
        DATE_TRUNC('day', evt_block_time) AS time,
        SUM(CASE
            WHEN tr."from" = 0x0000000000000000000000000000000000000000 THEN CAST(tr.value AS INT256)
            ELSE -CAST(tr.value AS INT256)
        END) AS amount_change
    FROM 
        erc20_ethereum.evt_Transfer tr
    WHERE 
        contract_address = 0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32 -- sFRAX
        AND (tr."from" = 0x0000000000000000000000000000000000000000 
             OR tr."to" = 0x0000000000000000000000000000000000000000)
    GROUP BY 1
)

-- Manual row
SELECT
    TIMESTAMP '2023-10-19 00:00:00' AS time,  -- Launch date
    1105253 AS cumulative_sFRAX -- staked pre-launch
UNION
-- Computed rows
SELECT
    time,
    ROUND(SUM(amount_change) OVER (ORDER BY time ASC) / 1e18,0) AS cumulative_sFRAX
FROM
    stake_unstake_events
WHERE time >= TIMESTAMP '2023-10-19 00:00:00'
ORDER BY
    time DESC;

-- price
WITH eth_price AS (
  SELECT
    DATE_TRUNC('day', minute) AS time,
    AVG(price) AS eth_price
  FROM prices.usd
  WHERE
    contract_address = 0x83F20F44975D03b1b09e64809B757c47f942BEeA -- sfrax
    AND minute > CAST('2022-04-01' AS TIMESTAMP)
  GROUP BY
    1
), cnc_price AS (
  SELECT
    DATE_TRUNC('day', evt_block_time) AS time,
    tokens_sold / CAST(tokens_bought AS DOUBLE) AS price,
    tokens_bought AS amount
  FROM curve_ethereum.sFRAX_crvUSD_CurveStableSwapNG_evt_TokenExchange
  WHERE
    sold_id = 0
  UNION
  SELECT
    DATE_TRUNC('day', evt_block_time) AS time,
    tokens_bought / CAST(tokens_sold AS DOUBLE) AS price,
    tokens_sold AS amount
  FROM curve_ethereum.sFRAX_crvUSD_CurveStableSwapNG_evt_TokenExchange
  WHERE
    sold_id = 1 AND tokens_bought > 0
), fin1 AS (
  SELECT
    time,
    SUM(price * amount) / CAST(SUM(amount) AS DOUBLE) AS price
  FROM cnc_price
  GROUP BY
    1
), fin2 AS (
  SELECT
    f1.time AS minute,
    f1.price,
    f.eth_price,
    f1.price  AS cnc_price --/ f.eth_price AS cnc_price
  FROM fin1 AS f1
  JOIN eth_price AS f
    ON f1.time = f.time
), price AS (
  SELECT
    *,
    cnc_price * 10000000 AS fdv,
    (
      (
        cnc_price - LAG(cnc_price, 1440) OVER (ORDER BY minute NULLS FIRST)
      ) / CAST(LAG(cnc_price, 1440) OVER (ORDER BY minute NULLS FIRST) AS DOUBLE)
    ) AS day_change,
    (
      (
        cnc_price - LAG(cnc_price, 10080) OVER (ORDER BY minute NULLS FIRST)
      ) / CAST(LAG(cnc_price, 10080) OVER (ORDER BY minute NULLS FIRST) AS DOUBLE)
    ) AS week_change
  FROM fin2
  ORDER BY
    1 DESC
), supply AS (
  SELECT
    DATE_TRUNC('day', evt_block_time) AS minute,
    SUM(CAST(value AS DOUBLE) / CAST(POWER(10, 18) AS DOUBLE)) AS deposits
  FROM erc20_ethereum.evt_Transfer
  WHERE
    contract_address = 0x9aE380F0272E2162340a5bB646c354271c0F5cFC
    AND "from" = 0x0000000000000000000000000000000000000000
  GROUP BY
    1
), 

base_data AS (
  WITH days AS (
      SELECT
        minute
      FROM UNNEST(SEQUENCE(
        CAST(CAST('2022-01-01' AS TIMESTAMP) AS DATE),
        DATE_TRUNC('day', cast(now() as timestamp)),
        INTERVAL '1' day
      ) /* WARNING: Check out the docs for example of time series generation: https://dune.com/docs/query/syntax-differences/ */) AS _u(minute)
    )
    SELECT
      minute,
      0 AS total
    FROM days
  ),
  
  over_time AS (
  SELECT
    t1.minute,
    t1.total AS total_base,
    t2.deposits
  FROM base_data AS t1
  LEFT JOIN supply AS t2
    ON t2.minute = t1.minute
), finish_supply AS (
  SELECT
    minute,
    SUM(total_base + deposits) OVER (ORDER BY minute NULLS FIRST) AS circ_supply
  FROM over_time
  WHERE
    minute > CAST('2022-04-1'AS timestamp)
)
SELECT
  a.minute, /* ,a.asset */
  a.cnc_price,
  a.fdv,
  a.day_change * 100 AS day_change,
  a.week_change,
  a.cnc_price * b.circ_supply AS mcap
FROM price AS a
LEFT JOIN finish_supply AS b
  ON a.minute = b.minute
ORDER BY
  a.minute DESC
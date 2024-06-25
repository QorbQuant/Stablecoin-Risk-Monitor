-- Dash: https://dune.com/degenerate_defi/crvusd-liquidity-and-risk-monitor

-- Stablecoin Liquidity:
WITH data AS (
SELECT 
    day
    ,token_symbol
    ,SUM(balance) AS balance
 FROM tokens_ethereum.balances_daily
WHERE  address IN (0x390f3595bca2df7d23783dfd126427cceb997bf4 -- Curve crvUSD/USDT
                    ,0x4dece678ceceb27446b35c672dc7d61f30bad69e -- Curve crvUSD/USDC
                    ,0xf55b0f6f2da5ffddb104b58a60f2862745960442 --  Curve cUSDe-crvUSD
                    ,0x94cc50e4521bd271c1a997a3a4dc815c2f920b41 -- Curve crvUSD/SUSD
                    ,0x3de254a0f838a844f727fee81040e0fa7884b935 -- Curve mkUSD/crvUSD
                    ,0x0cd6f267b2086bea681e922e19d40512511be538 -- Curve crvUSD/FRAX
                    ,0x635ef0056a597d13863b73825cca297236578595 -- Curve GHO/crvUSD
                    ,0x625e92624bc2d88619accc1788365a69767f6200 -- Curve crvUSD/USDP
                    ,0x34d655069f4cac1547e4c8ca284ffff5ad4a8db0 -- Curve crvUSD/TUSD
                    ,0x085780639cc2cacd35e474e71f4d000e2405d8f6 -- Curve crvUSDT/fxUSD
                    ,0x73a0cba58c19ed5f27c6590bd792ec38de4815ea -- Curve crvUSD/sFRAX
                    ,0x8272e1a3dbef607c04aa6e5bd3a1a134c8ac063b -- Curve LUSD/crvUSD
                    ,0x625e92624bc2d88619accc1788365a69767f6200 -- Curve pyUSD/crvUSD
                    ,0x8272e1a3dbef607c04aa6e5bd3a1a134c8ac063b -- Curve crvUSD/DOLA
                    ,0x8c24b3213fd851db80245fccc42c40b94ac9a745 -- Curve crvUSD/zunUSD
                    ,0x9e641187391b7a5fe9ee193359408ca3894f68a2 -- Curve thUSD/crvUSD
                    ,0xc55bcf5370e67fba281e2aac8937b4ea71e7785f -- Curve crvUSD/sDAI
                    ,0xecdd0ce505da71cd9de855cd6804ba1e8c7bdb07 -- Curve crvUSD/GUSD
                    ,0xca978a0528116dda3cba9acd3e68bc6191ca53d0 -- Curve crvUSD/USDP
                    )
AND day > CAST('2023-05-01' AS TIMESTAMP)
GROUP BY 1,2
)


SELECT
    day
    ,CASE 
            WHEN token_symbol = 'crvUSD' THEN 'crvUSD'
            ELSE 'Paired Stablecoins'
        END AS symbol
    ,SUM(balance) AS liquidity
FROM data
GROUP BY 1,2
ORDER BY 1 DESC;




-- Supply
 WITH supply_frax AS (
    SELECT 
        day
        ,SUM(som) AS som 
    FROM (
    SELECT 
        DATE_TRUNC('day', evt_block_time) AS day
        ,SUM(CAST(value AS DOUBLE)/1e18) AS som 
    FROM erc20_ethereum.evt_Transfer
    where contract_address = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E -- crvUSD
    AND "from" = 0x0000000000000000000000000000000000000000
    GROUP BY 1
    
    UNION ALL
    
    SELECT 
        DATE_TRUNC('day', evt_block_time) AS day
        ,SUM(CAST(value AS DOUBLE)/1e18)*-1  AS som 
        FROM erc20_ethereum.evt_Transfer
    WHERE contract_address = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E -- crvUSD
    AND to = 0x0000000000000000000000000000000000000000
    GROUP BY 1
    
    
    ) t 
    GROUP BY day
)

, balances_with_gap_days AS (
     SELECT 
        day
        ,SUM(som) OVER (ORDER BY day ASC) AS supply -- balance per day with a transaction
        ,LEAD(day, 1, now()) OVER (ORDER BY day asc) AS next_day
     FROM supply_frax
     )
     
, days AS 
(
    WITH days_seq AS (
        SELECT
        sequence(
            (SELECT cast(min(date_trunc('day', day)) as timestamp) day FROM supply_frax)
            , date_trunc('day', cast(now() as timestamp))
            , interval '1' day) as day
    )
    
    SELECT 
        days.day
    FROM days_seq
    CROSS JOIN unnest(day) as days(day) --this is just doing explode like in spark sql
)


 , balance_all_days AS (
     SELECT
        d.day
        ,SUM(supply) AS supply
     FROM balances_with_gap_days b
     INNER JOIN days d ON b.day <= d.day
     AND d.day < b.next_day -- Yields an observation for every day after the first transfer until the next day with transfer
     GROUP BY 1
     ORDER BY 1 DESC
     )

SELECT * FROM balance_all_days;

-- crvUSD On-Chain Liquidity Dynamics:
SELECT
    a.day
    ,a.supply
    ,b.liquidity
    ,b.liquidity / a.supply as ratio
FROM query_3849436 AS a -- supply query
LEFT join query_3851450 AS b ON a.day = b.day -- liquidity query
WHERE a.day > CAST('2023-01-20' AS DATE)
and b.symbol = 'Paired Stablecoins'
ORDER BY 1 DESC;

-- Price

*,
1 AS peg
FROM prices.usd WHERE contract_address = 0xf939e0a03fb07f59a73314e73794be0e57ac1b4e
AND minute > CAST('2024-01-17' AS timestamp);
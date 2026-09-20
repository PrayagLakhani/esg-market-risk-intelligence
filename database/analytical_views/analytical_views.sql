-- CONTROVERSY SUMMARY — overview KPI cards (Page 1)
CREATE MATERIALIZED VIEW mv_controversy_summary AS
SELECT
    ec.category,
    COUNT(*)                                   AS controversy_count,
    COUNT(DISTINCT fc.company_id)              AS companies_affected,
    COUNT(DISTINCT dc.sector_id)               AS sectors_affected,
    MIN(fc.controversy_date)                   AS earliest_event,
    MAX(fc.controversy_date)                   AS latest_event
FROM fact_controversy fc
JOIN dim_esg_category ec ON ec.esg_category_id = fc.esg_category_id
JOIN dim_company dc       ON dc.company_id = fc.company_id
GROUP BY ec.category;

-- COMPANY ESG EXPOSURE — Page 4 company profile header
CREATE VIEW vw_company_esg_exposure AS
SELECT
    dc.company_id, dc.ticker, ds.sector_name,
    COUNT(fc.controversy_id)                                          AS total_controversies,
    SUM(CASE WHEN ec.category = 'Environmental' THEN 1 ELSE 0 END)    AS environmental_count,
    SUM(CASE WHEN ec.category = 'Social' THEN 1 ELSE 0 END)           AS social_count,
    SUM(CASE WHEN ec.category = 'Governance' THEN 1 ELSE 0 END)       AS governance_count,
    MIN(fc.controversy_date)                                          AS first_event_date,
    MAX(fc.controversy_date)                                          AS most_recent_event_date
FROM dim_company dc
JOIN dim_sector ds        ON ds.sector_id = dc.sector_id
LEFT JOIN fact_controversy fc ON fc.company_id = dc.company_id
LEFT JOIN dim_esg_category ec ON ec.esg_category_id = fc.esg_category_id
GROUP BY dc.company_id, dc.ticker, ds.sector_name;

-- EVENT IMPACT — Investigator page (Page 2), one row per event
CREATE VIEW vw_event_impact AS
SELECT
    fc.controversy_id, dc.ticker, ds.sector_name, ec.category,
    fc.controversy_date, fc.description,
    few.car_1_1_marketadj, few.car_5_5_marketadj, few.car_10_10_marketadj,
    few.car_5_5_marketmodel,
    few.volume_change_pct, few.volatility_change, few.max_drawdown_pct,
    few.recovery_days, few.recovered_within_60d,
    RANK() OVER (ORDER BY few.car_5_5_marketadj ASC) AS severity_rank
FROM fact_controversy fc
JOIN dim_company dc       ON dc.company_id = fc.company_id
JOIN dim_sector ds        ON ds.sector_id = dc.sector_id
JOIN dim_esg_category ec  ON ec.esg_category_id = fc.esg_category_id
JOIN fact_event_window few ON few.controversy_id = fc.controversy_id;

-- SECTOR EXPOSURE / STRESS — Page 3, uses median via window function
CREATE VIEW vw_sector_exposure AS
WITH sector_events AS (
    SELECT ds.sector_id, ds.sector_name, fc.controversy_id, few.car_5_5_marketadj,
           few.volume_change_pct, dc.company_id
    FROM fact_controversy fc
    JOIN dim_company dc ON dc.company_id = fc.company_id
    JOIN dim_sector ds ON ds.sector_id = dc.sector_id
    JOIN fact_event_window few ON few.controversy_id = fc.controversy_id
)
SELECT
    sector_name,
    COUNT(*)                                            AS controversy_count,
    COUNT(DISTINCT company_id)                          AS affected_companies,
    ROUND(AVG(car_5_5_marketadj)::numeric, 2)           AS avg_car_5_5,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY car_5_5_marketadj) AS median_car_5_5,
    ROUND(AVG(volume_change_pct)::numeric, 1)           AS avg_volume_change
FROM sector_events
GROUP BY sector_name
ORDER BY median_car_5_5;

-- Daily abnormal-return detail is not persisted in the current model.
-- The event-study output stores aggregated CAR metrics.

-- COMPANY RISK PROFILE — Page 4 full profile, ranks companies by severity
CREATE VIEW vw_company_risk_profile AS
SELECT
    dc.ticker, ds.sector_name,
    COUNT(few.controversy_id)                                  AS n_events,
    ROUND(AVG(few.car_5_5_marketadj)::numeric, 2)              AS avg_car_5_5,
    MIN(few.car_5_5_marketadj)                                 AS worst_car_5_5,
    ROUND(AVG(few.max_drawdown_pct)::numeric, 2)               AS avg_max_drawdown,
    ROUND(AVG(few.volume_change_pct)::numeric, 1)              AS avg_volume_change,
    ROUND(100.0 * SUM(CASE WHEN few.recovered_within_60d THEN 1 ELSE 0 END)
          / NULLIF(COUNT(few.controversy_id),0), 1)            AS pct_recovered_60d,
    RANK() OVER (ORDER BY AVG(few.car_5_5_marketadj) ASC NULLS LAST) AS risk_rank
FROM dim_company dc
JOIN dim_sector ds ON ds.sector_id = dc.sector_id
LEFT JOIN fact_controversy fc ON fc.company_id = dc.company_id
LEFT JOIN fact_event_window few ON few.controversy_id = fc.controversy_id
GROUP BY dc.ticker, ds.sector_name;

-- VOLUME REACTION — flags events with the largest trading-activity spikes
CREATE VIEW vw_volume_reaction AS
SELECT
    dc.ticker, fc.controversy_date, fc.description, few.volume_change_pct,
    NTILE(4) OVER (ORDER BY few.volume_change_pct) AS volume_quartile
FROM fact_controversy fc
JOIN dim_company dc ON dc.company_id = fc.company_id
JOIN fact_event_window few ON few.controversy_id = fc.controversy_id
ORDER BY few.volume_change_pct DESC;

-- RECOVERY ANALYSIS — persistent vs. temporary impact
CREATE VIEW vw_recovery_analysis AS
SELECT
    dc.ticker, ds.sector_name, fc.controversy_date, fc.description,
    few.max_drawdown_pct, few.recovery_days, few.recovered_within_60d,
    CASE
        WHEN few.recovered_within_60d = 0 THEN 'Persistent (not recovered in 60d)'
        WHEN few.recovery_days <= 5       THEN 'Fast recovery (<=5d)'
        WHEN few.recovery_days <= 20      THEN 'Moderate recovery (6-20d)'
        ELSE 'Slow recovery (21-60d)'
    END AS recovery_bucket
FROM fact_controversy fc
JOIN dim_company dc ON dc.company_id = fc.company_id
JOIN dim_sector ds  ON ds.sector_id = dc.sector_id
JOIN fact_event_window few ON few.controversy_id = fc.controversy_id;


-- HIGH-IMPACT EVENTS / ALERTS
-- Flags severe CAR reactions, large volume spikes, or events not recovered within 60 trading days.
CREATE VIEW vw_high_impact_events AS
WITH stats AS (
    SELECT AVG(car_5_5_marketadj) AS mean_car, STDDEV(car_5_5_marketadj) AS sd_car
    FROM fact_event_window
)
SELECT
    dc.ticker, fc.controversy_date, fc.description, ec.category,
    few.car_5_5_marketadj, few.volume_change_pct, few.recovery_days, few.recovered_within_60d,
    CASE
        WHEN few.car_5_5_marketadj < (SELECT mean_car - 1.5*sd_car FROM stats)
            THEN 'Severe Market Reaction'
        WHEN few.volume_change_pct > 200
            THEN 'High Volume Spike'
        WHEN few.recovered_within_60d = 0
            THEN 'Persistent Drawdown'
        ELSE NULL
    END AS alert_type
FROM fact_controversy fc
JOIN dim_company dc ON dc.company_id = fc.company_id
JOIN dim_esg_category ec ON ec.esg_category_id = fc.esg_category_id
JOIN fact_event_window few ON few.controversy_id = fc.controversy_id
WHERE few.car_5_5_marketadj < (SELECT mean_car - 1.5*sd_car FROM stats)
   OR few.volume_change_pct > 200
   OR few.recovered_within_60d = 0;

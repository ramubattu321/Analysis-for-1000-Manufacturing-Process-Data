-- ============================================================
-- Manufacturing Anomaly Detection & SPC — SQL Queries (16)
-- Statistical Process Control analysis on sensor data
-- Run in: SQLite / MySQL / PostgreSQL
-- Author: Ramu Battu — MS Data Analytics, CSU Fresno
-- ============================================================


-- ── QUERY 1: SPC CONTROL LIMITS PER MACHINE & SENSOR ────────────────────────
-- Calculate μ, σ, UCL, LCL for each machine sensor (3-sigma method)
SELECT
    m.machine_name,
    'temperature'                                       AS sensor,
    ROUND(AVG(r.temperature), 2)                        AS mean,
    ROUND(AVG(r.temperature) + 3*AVG(r.temperature)/10, 2) AS ucl_approx,
    ROUND(AVG(r.temperature) - 3*AVG(r.temperature)/10, 2) AS lcl_approx,
    ROUND(MIN(r.temperature), 2)                        AS min_reading,
    ROUND(MAX(r.temperature), 2)                        AS max_reading
FROM sensor_readings r
JOIN machines m ON r.machine_id = m.machine_id
GROUP BY m.machine_name
UNION ALL
SELECT m.machine_name, 'pressure',
    ROUND(AVG(r.pressure), 2),
    ROUND(AVG(r.pressure) + 3*AVG(r.pressure)/10, 2),
    ROUND(AVG(r.pressure) - 3*AVG(r.pressure)/10, 2),
    ROUND(MIN(r.pressure), 2), ROUND(MAX(r.pressure), 2)
FROM sensor_readings r JOIN machines m ON r.machine_id=m.machine_id
GROUP BY m.machine_name
UNION ALL
SELECT m.machine_name, 'vibration',
    ROUND(AVG(r.vibration), 2),
    ROUND(AVG(r.vibration) + 3*AVG(r.vibration)/10, 2),
    ROUND(AVG(r.vibration) - 3*AVG(r.vibration)/10, 2),
    ROUND(MIN(r.vibration), 2), ROUND(MAX(r.vibration), 2)
FROM sensor_readings r JOIN machines m ON r.machine_id=m.machine_id
GROUP BY m.machine_name
ORDER BY machine_name, sensor;


-- ── QUERY 2: ANOMALY COUNT BY MACHINE & SEVERITY ─────────────────────────────
-- How many anomalies per machine, broken down by severity level?
SELECT
    m.machine_name,
    m.machine_type,
    m.location,
    COUNT(a.anomaly_id)                                               AS total_anomalies,
    SUM(CASE WHEN a.severity = 'Critical' THEN 1 ELSE 0 END)         AS critical,
    SUM(CASE WHEN a.severity = 'High'     THEN 1 ELSE 0 END)         AS high,
    SUM(CASE WHEN a.severity = 'Medium'   THEN 1 ELSE 0 END)         AS medium,
    ROUND(100.0 * COUNT(a.anomaly_id)
          / (SELECT COUNT(*) FROM sensor_readings WHERE machine_id = m.machine_id), 2)
                                                                      AS anomaly_rate_pct
FROM machines m
LEFT JOIN anomalies a ON m.machine_id = a.machine_id
GROUP BY m.machine_id, m.machine_name, m.machine_type, m.location
ORDER BY total_anomalies DESC;


-- ── QUERY 3: ANOMALY BREAKDOWN BY SENSOR TYPE ────────────────────────────────
-- Which sensors trigger the most anomalies?
SELECT
    sensor_type,
    COUNT(*)                                                          AS total_anomalies,
    ROUND(AVG(deviation), 2)                                          AS avg_sigma_deviation,
    ROUND(MAX(deviation), 2)                                          AS max_sigma_deviation,
    SUM(CASE WHEN severity = 'Critical' THEN 1 ELSE 0 END)           AS critical_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS pct_of_total
FROM anomalies
GROUP BY sensor_type
ORDER BY total_anomalies DESC;


-- ── QUERY 4: DAILY ANOMALY TREND ─────────────────────────────────────────────
-- How many anomalies were detected each day across all machines?
SELECT
    DATE(detected_at)                                                 AS anomaly_date,
    COUNT(*)                                                          AS daily_anomalies,
    SUM(CASE WHEN severity = 'Critical' THEN 1 ELSE 0 END)           AS critical,
    COUNT(DISTINCT machine_id)                                        AS machines_affected,
    GROUP_CONCAT(DISTINCT sensor_type)                                AS sensors_triggered
FROM anomalies
GROUP BY anomaly_date
ORDER BY anomaly_date
LIMIT 15;


-- ── QUERY 5: SHIFT-LEVEL PERFORMANCE COMPARISON ──────────────────────────────
-- Which shift produces the most defects and anomalies?
SELECT
    r.shift,
    COUNT(*)                                AS total_readings,
    ROUND(AVG(r.temperature), 2)            AS avg_temp,
    ROUND(AVG(r.vibration), 2)              AS avg_vibration,
    SUM(r.output_units)                     AS total_output,
    SUM(r.defect_count)                     AS total_defects,
    ROUND(100.0 * SUM(r.defect_count)
          / NULLIF(SUM(r.output_units),0), 2) AS defect_rate_pct,
    COUNT(a.anomaly_id)                     AS anomaly_count
FROM sensor_readings r
LEFT JOIN anomalies a ON r.reading_id = a.reading_id
GROUP BY r.shift
ORDER BY defect_rate_pct DESC;


-- ── QUERY 6: MACHINE DEFECT RATE OVER TIME ───────────────────────────────────
-- Weekly defect rate trend per machine
SELECT
    m.machine_name,
    STRFTIME('%Y-W%W', r.reading_time)      AS week,
    SUM(r.output_units)                     AS weekly_output,
    SUM(r.defect_count)                     AS weekly_defects,
    ROUND(100.0 * SUM(r.defect_count)
          / NULLIF(SUM(r.output_units),0), 2) AS defect_rate_pct
FROM sensor_readings r
JOIN machines m ON r.machine_id = m.machine_id
GROUP BY m.machine_name, week
ORDER BY m.machine_name, week;


-- ── QUERY 7: RUNNING ANOMALY COUNT (WINDOW FUNCTION) ─────────────────────────
-- Cumulative anomalies over time per machine
SELECT
    m.machine_name,
    DATE(a.detected_at)                     AS anomaly_date,
    COUNT(*)                                AS daily_anomalies,
    SUM(COUNT(*)) OVER (
        PARTITION BY a.machine_id
        ORDER BY DATE(a.detected_at))       AS cumulative_anomalies
FROM anomalies a
JOIN machines m ON a.machine_id = m.machine_id
GROUP BY a.machine_id, m.machine_name, anomaly_date
ORDER BY a.machine_id, anomaly_date
LIMIT 20;


-- ── QUERY 8: ANOMALY FREQUENCY RANK (RANK WINDOW FUNCTION) ───────────────────
-- Rank machines by anomaly frequency per sensor type
WITH machine_sensor_anomalies AS (
    SELECT
        m.machine_name,
        a.sensor_type,
        COUNT(*) AS anomaly_count
    FROM anomalies a
    JOIN machines m ON a.machine_id = m.machine_id
    GROUP BY m.machine_name, a.sensor_type
)
SELECT
    machine_name,
    sensor_type,
    anomaly_count,
    RANK() OVER (PARTITION BY sensor_type ORDER BY anomaly_count DESC) AS rank_in_sensor,
    DENSE_RANK() OVER (ORDER BY anomaly_count DESC)                    AS overall_rank
FROM machine_sensor_anomalies
ORDER BY sensor_type, rank_in_sensor;


-- ── QUERY 9: DAY-OVER-DAY ANOMALY CHANGE (LAG WINDOW FUNCTION) ───────────────
-- Track daily anomaly increase or decrease vs previous day
WITH daily AS (
    SELECT DATE(detected_at) AS dt, COUNT(*) AS cnt
    FROM anomalies GROUP BY dt
)
SELECT
    dt,
    cnt AS anomalies,
    LAG(cnt) OVER (ORDER BY dt)                          AS prev_day,
    cnt - LAG(cnt) OVER (ORDER BY dt)                    AS daily_change,
    ROUND(100.0 * (cnt - LAG(cnt) OVER (ORDER BY dt))
          / NULLIF(LAG(cnt) OVER (ORDER BY dt), 0), 1)  AS dod_change_pct
FROM daily
ORDER BY dt
LIMIT 15;


-- ── QUERY 10: TOP 10 WORST SENSOR READINGS ───────────────────────────────────
-- Most extreme anomalies by sigma deviation
SELECT
    m.machine_name,
    a.sensor_type,
    ROUND(a.reading_val, 2)                  AS actual_value,
    ROUND(a.mean_val, 2)                     AS process_mean,
    ROUND(a.ucl, 2)                          AS ucl,
    ROUND(a.lcl, 2)                          AS lcl,
    ROUND(a.deviation, 2)                    AS sigma_deviation,
    a.severity,
    a.detected_at
FROM anomalies a
JOIN machines m ON a.machine_id = m.machine_id
ORDER BY a.deviation DESC
LIMIT 10;


-- ── QUERY 11: MACHINE PERFORMANCE SCORECARD ──────────────────────────────────
-- Overall health score per machine combining multiple metrics
WITH stats AS (
    SELECT
        r.machine_id,
        ROUND(AVG(r.temperature), 2)                    AS avg_temp,
        ROUND(AVG(r.vibration), 2)                      AS avg_vibration,
        ROUND(AVG(r.pressure), 2)                       AS avg_pressure,
        ROUND(AVG(r.speed_rpm), 0)                      AS avg_rpm,
        SUM(r.output_units)                             AS total_output,
        SUM(r.defect_count)                             AS total_defects,
        ROUND(100.0*SUM(r.defect_count)/NULLIF(SUM(r.output_units),0),2) AS defect_rate
    FROM sensor_readings r
    GROUP BY r.machine_id
),
anom AS (
    SELECT machine_id, COUNT(*) AS anomalies
    FROM anomalies GROUP BY machine_id
)
SELECT
    m.machine_name,
    m.machine_type,
    m.location,
    s.avg_temp, s.avg_vibration, s.total_output, s.defect_rate,
    COALESCE(a.anomalies, 0)                            AS total_anomalies,
    RANK() OVER (ORDER BY s.defect_rate ASC)            AS quality_rank,
    RANK() OVER (ORDER BY COALESCE(a.anomalies,0) ASC)  AS reliability_rank
FROM machines m
JOIN stats s ON m.machine_id = s.machine_id
LEFT JOIN anom a ON m.machine_id = a.machine_id
ORDER BY quality_rank;


-- ── QUERY 12: HOURLY SENSOR PATTERN (PEAK ANOMALY HOURS) ─────────────────────
-- Which hours of the day have the most anomalies?
SELECT
    CAST(STRFTIME('%H', detected_at) AS INTEGER)        AS hour_of_day,
    COUNT(*)                                            AS anomaly_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_anomalies,
    GROUP_CONCAT(DISTINCT sensor_type)                  AS sensors_involved
FROM anomalies
GROUP BY hour_of_day
ORDER BY anomaly_count DESC
LIMIT 10;


-- ── QUERY 13: CORRELATION — HIGH TEMP VS HIGH DEFECTS ────────────────────────
-- Do high-temperature readings correlate with higher defect rates?
WITH temp_buckets AS (
    SELECT machine_id,
           CASE
               WHEN temperature < 70 THEN 'Low (<70°C)'
               WHEN temperature < 80 THEN 'Normal (70-80°C)'
               WHEN temperature < 90 THEN 'High (80-90°C)'
               ELSE 'Very High (>90°C)'
           END AS temp_bucket,
           defect_count, output_units
    FROM sensor_readings
)
SELECT
    temp_bucket,
    COUNT(*)                                                AS readings,
    SUM(output_units)                                       AS total_output,
    SUM(defect_count)                                       AS total_defects,
    ROUND(100.0 * SUM(defect_count)/NULLIF(SUM(output_units),0), 2) AS defect_rate_pct,
    ROUND(AVG(CAST(defect_count AS REAL)), 2)               AS avg_defects_per_reading
FROM temp_buckets
GROUP BY temp_bucket
ORDER BY defect_rate_pct DESC;


-- ── QUERY 14: VIBRATION ANOMALY CLUSTERS ─────────────────────────────────────
-- Identify clusters of vibration anomalies by machine and time period
WITH vib_anomalies AS (
    SELECT
        a.machine_id,
        m.machine_name,
        DATE(a.detected_at)  AS anomaly_date,
        COUNT(*)             AS vib_anomalies_that_day,
        ROUND(AVG(a.deviation), 2) AS avg_deviation
    FROM anomalies a
    JOIN machines m ON a.machine_id = m.machine_id
    WHERE a.sensor_type = 'vibration'
    GROUP BY a.machine_id, m.machine_name, anomaly_date
)
SELECT
    machine_name,
    anomaly_date,
    vib_anomalies_that_day,
    avg_deviation,
    SUM(vib_anomalies_that_day) OVER (
        PARTITION BY machine_id ORDER BY anomaly_date) AS cumulative_vib_anomalies,
    CASE WHEN vib_anomalies_that_day >= 3 THEN 'CLUSTER ALERT'
         ELSE 'Normal' END AS alert_flag
FROM vib_anomalies
ORDER BY machine_id, anomaly_date
LIMIT 20;


-- ── QUERY 15: PREDICTIVE MAINTENANCE PRIORITY SCORE ──────────────────────────
-- Score machines by maintenance urgency using weighted metrics
WITH machine_stats AS (
    SELECT
        r.machine_id,
        ROUND(AVG(r.vibration), 3)                       AS avg_vibration,
        ROUND(AVG(r.temperature), 2)                     AS avg_temp,
        ROUND(100.0*SUM(r.defect_count)/NULLIF(SUM(r.output_units),0),3) AS defect_pct,
        COUNT(a.anomaly_id)                              AS anomaly_count,
        SUM(CASE WHEN a.severity='Critical' THEN 3
                 WHEN a.severity='High' THEN 2
                 ELSE 1 END)                             AS weighted_anomaly_score
    FROM sensor_readings r
    LEFT JOIN anomalies a ON r.reading_id = a.reading_id
    GROUP BY r.machine_id
)
SELECT
    m.machine_name,
    m.machine_type,
    m.install_year,
    ms.avg_vibration,
    ms.avg_temp,
    ms.defect_pct,
    ms.anomaly_count,
    ms.weighted_anomaly_score,
    RANK() OVER (ORDER BY ms.weighted_anomaly_score DESC) AS maintenance_priority,
    CASE
        WHEN ms.weighted_anomaly_score >= 150 THEN '🔴 URGENT — Schedule immediately'
        WHEN ms.weighted_anomaly_score >= 100 THEN '🟠 HIGH — Schedule within 1 week'
        WHEN ms.weighted_anomaly_score >= 50  THEN '🟡 MEDIUM — Schedule within 1 month'
        ELSE                                       '🟢 LOW — Routine maintenance'
    END AS maintenance_recommendation
FROM machine_stats ms
JOIN machines m ON ms.machine_id = m.machine_id
ORDER BY maintenance_priority;


-- ── QUERY 16: SPC HEALTH DASHBOARD SUMMARY ───────────────────────────────────
-- Executive summary: overall process health using CTEs
WITH totals AS (
    SELECT COUNT(*) AS total_readings,
           SUM(output_units) AS total_output,
           SUM(defect_count) AS total_defects,
           ROUND(AVG(temperature),2) AS avg_temp,
           ROUND(AVG(vibration),2)   AS avg_vibration,
           ROUND(AVG(pressure),2)    AS avg_pressure
    FROM sensor_readings
),
anomaly_totals AS (
    SELECT COUNT(*) AS total_anomalies,
           SUM(CASE WHEN severity='Critical' THEN 1 ELSE 0 END) AS critical,
           SUM(CASE WHEN severity='High'     THEN 1 ELSE 0 END) AS high,
           SUM(CASE WHEN severity='Medium'   THEN 1 ELSE 0 END) AS medium,
           ROUND(MAX(deviation),2) AS worst_deviation
    FROM anomalies
)
SELECT
    t.total_readings,
    t.total_output,
    t.total_defects,
    ROUND(100.0 * t.total_defects / NULLIF(t.total_output,0), 2) AS overall_defect_rate_pct,
    t.avg_temp,
    t.avg_vibration,
    t.avg_pressure,
    a.total_anomalies,
    a.critical                                                    AS critical_anomalies,
    a.high                                                        AS high_anomalies,
    a.medium                                                      AS medium_anomalies,
    ROUND(100.0 * a.total_anomalies / t.total_readings, 2)        AS anomaly_rate_pct,
    a.worst_deviation                                             AS worst_sigma_deviation,
    CASE WHEN ROUND(100.0*a.total_anomalies/t.total_readings,2) < 5  THEN 'STABLE'
         WHEN ROUND(100.0*a.total_anomalies/t.total_readings,2) < 10 THEN 'WATCH'
         ELSE 'ACTION REQUIRED' END                               AS process_status
FROM totals t, anomaly_totals a;

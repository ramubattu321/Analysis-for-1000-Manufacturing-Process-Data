# Manufacturing Process Analysis & Anomaly Detection — SPC

![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-SQLite-003B57?style=flat&logo=sqlite&logoColor=white)
![SPC](https://img.shields.io/badge/SPC-3--Sigma%20Control%20Charts-orange?style=flat)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat)

---

## Overview

A manufacturing process analysis project combining **cluster sampling**, **Exploratory Data Analysis (EDA)**, and **Statistical Process Control (SPC)** to detect machine anomalies from sensor data. Post-EDA, sensor readings are loaded into a SQL database and analyzed with 16 production queries covering anomaly detection, defect rates, shift performance, and predictive maintenance prioritization.

---

## Business Problem

Manufacturing machines generate continuous sensor data (temperature, pressure, vibration, speed). Identifying process deviations before they cause failures or quality issues requires statistical monitoring. This project:

- Applies 3-sigma control charts to flag out-of-control readings
- Loads cleaned sensor data into SQL for structured querying
- Ranks machines by anomaly severity for maintenance planning
- Identifies peak anomaly hours and shift-level defect patterns

---

## Statistical Process Control — 3-Sigma Method

```
UCL (Upper Control Limit) = μ + 3σ
Center Line               = Process Mean (μ)
LCL (Lower Control Limit) = μ - 3σ

Reading > UCL or < LCL  →  Anomaly Flagged ⚠️
```

```python
import pandas as pd

def compute_spc(df, sensor_col):
    """Compute SPC control limits and flag anomalies."""
    mean = df[sensor_col].mean()
    std  = df[sensor_col].std()
    ucl  = mean + 3 * std
    lcl  = mean - 3 * std

    df[f'{sensor_col}_ucl']     = ucl
    df[f'{sensor_col}_lcl']     = lcl
    df[f'{sensor_col}_anomaly'] = (df[sensor_col] > ucl) | (df[sensor_col] < lcl)
    return df, mean, std, ucl, lcl
```

---

## Control Chart

![Manufacturing Process Control Chart](Image.png)

---

## Dataset

**3,600 sensor readings | 5 machines | 30 days | 3 sensors each**

| Table | Rows | Description |
|-------|------|-------------|
| machines | 5 | Machine registry — type, location, install year |
| sensor_readings | 3,600 | Hourly sensor data — temperature, pressure, vibration, RPM, output, defects |
| anomalies | 270 | SPC-flagged readings with severity classification |
| shift_summary | 450 | Daily shift-level performance aggregation |

**Machines:**

| Machine | Type | Location |
|---------|------|---------|
| Machine_A | CNC Lathe | Zone-1 |
| Machine_B | Press | Zone-1 |
| Machine_C | Conveyor | Zone-2 |
| Machine_D | Drill Press | Zone-2 |
| Machine_E | Injection Mold | Zone-3 |

---

## Project Structure

```
manufacturing-process-analysis-eda/
│
├── manufacturing_insights.ipynb    # EDA + SPC analysis notebook
├── Image.png                       # Control chart output
├── Requirements.txt                # Python dependencies
│
├── sql/
│   ├── schema.sql                  # 4-table database schema
│   ├── sample_data.sql             # 500 readings + 270 anomalies
│   ├── manufacturing_queries.sql   # 16 production SQL queries
│   └── setup_and_run.py            # Creates SQLite DB + runs queries
│
└── README.md
```

---

## SQL Queries — 16 Production Queries

### SPC & Anomaly Analysis

```sql
-- Anomaly count by machine and severity
SELECT m.machine_name, m.location,
    COUNT(a.anomaly_id) AS total_anomalies,
    SUM(CASE WHEN a.severity='Critical' THEN 1 ELSE 0 END) AS critical,
    SUM(CASE WHEN a.severity='High'     THEN 1 ELSE 0 END) AS high,
    ROUND(100.0*COUNT(a.anomaly_id)
          /(SELECT COUNT(*) FROM sensor_readings WHERE machine_id=m.machine_id),2) AS anomaly_rate_pct
FROM machines m LEFT JOIN anomalies a ON m.machine_id=a.machine_id
GROUP BY m.machine_id ORDER BY total_anomalies DESC;

-- Which sensors trigger the most anomalies? (SUM OVER window)
SELECT sensor_type, COUNT(*) AS anomalies,
    ROUND(AVG(deviation),2) AS avg_sigma,
    ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER(),2) AS pct_of_total
FROM anomalies GROUP BY sensor_type ORDER BY anomalies DESC;

-- Top 10 worst readings by sigma deviation
SELECT m.machine_name, a.sensor_type,
    ROUND(a.reading_val,2) AS actual, ROUND(a.mean_val,2) AS mean,
    ROUND(a.ucl,2) AS ucl, ROUND(a.deviation,2) AS sigma_deviation, a.severity
FROM anomalies a JOIN machines m ON a.machine_id=m.machine_id
ORDER BY a.deviation DESC LIMIT 10;
```

### Window Functions

```sql
-- Cumulative anomalies over time per machine (SUM OVER)
SELECT m.machine_name, DATE(a.detected_at) AS date,
    COUNT(*) AS daily_anomalies,
    SUM(COUNT(*)) OVER (PARTITION BY a.machine_id ORDER BY DATE(a.detected_at)) AS cumulative
FROM anomalies a JOIN machines m ON a.machine_id=m.machine_id
GROUP BY a.machine_id, date ORDER BY a.machine_id, date;

-- Day-over-day anomaly trend (LAG window)
WITH daily AS (SELECT DATE(detected_at) AS dt, COUNT(*) AS cnt FROM anomalies GROUP BY dt)
SELECT dt, cnt,
    LAG(cnt) OVER (ORDER BY dt) AS prev_day,
    ROUND(100.0*(cnt-LAG(cnt) OVER (ORDER BY dt))/NULLIF(LAG(cnt) OVER (ORDER BY dt),0),1) AS dod_pct
FROM daily ORDER BY dt;

-- Machine ranking by anomaly frequency per sensor (RANK + DENSE_RANK)
WITH stats AS (SELECT m.machine_name, a.sensor_type, COUNT(*) AS cnt
               FROM anomalies a JOIN machines m ON a.machine_id=m.machine_id
               GROUP BY m.machine_name, a.sensor_type)
SELECT machine_name, sensor_type, cnt,
    RANK() OVER (PARTITION BY sensor_type ORDER BY cnt DESC) AS sensor_rank
FROM stats ORDER BY sensor_type, sensor_rank;
```

### Predictive Maintenance

```sql
-- Maintenance priority scoring (weighted anomaly score)
WITH ms AS (
    SELECT r.machine_id,
        ROUND(AVG(r.vibration),3) AS avg_vibration,
        ROUND(100.0*SUM(r.defect_count)/NULLIF(SUM(r.output_units),0),3) AS defect_pct,
        SUM(CASE WHEN a.severity='Critical' THEN 3
                 WHEN a.severity='High' THEN 2 ELSE 1 END) AS weighted_score
    FROM sensor_readings r LEFT JOIN anomalies a ON r.reading_id=a.reading_id
    GROUP BY r.machine_id
)
SELECT m.machine_name, ms.avg_vibration, ms.defect_pct, ms.weighted_score,
    RANK() OVER (ORDER BY ms.weighted_score DESC) AS maintenance_priority,
    CASE WHEN ms.weighted_score>=150 THEN 'URGENT'
         WHEN ms.weighted_score>=100 THEN 'HIGH'
         ELSE 'ROUTINE' END AS recommendation
FROM ms JOIN machines m ON ms.machine_id=m.machine_id ORDER BY maintenance_priority;
```

### All 16 Queries Summary

| # | Query | SQL Technique |
|---|-------|--------------|
| 1 | SPC control limits per machine/sensor | UNION ALL aggregation |
| 2 | Anomaly count by machine & severity | LEFT JOIN + CASE WHEN |
| 3 | Anomaly breakdown by sensor type | SUM OVER window |
| 4 | Daily anomaly trend | DATE + GROUP BY |
| 5 | Shift-level performance (defect rate) | LEFT JOIN + aggregation |
| 6 | Weekly defect rate per machine | STRFTIME + GROUP BY |
| 7 | Cumulative anomalies over time | SUM OVER window |
| 8 | Machine rank by sensor anomalies | RANK + DENSE_RANK window |
| 9 | Day-over-day anomaly change | LAG window + CTE |
| 10 | Top 10 worst readings | ORDER BY sigma deviation |
| 11 | Machine performance scorecard | CTE + RANK + RANK |
| 12 | Peak anomaly hours | STRFTIME hour + SUM OVER |
| 13 | Temperature vs defect rate correlation | CASE WHEN bucketing |
| 14 | Vibration anomaly clusters | SUM OVER + alert flag |
| 15 | Predictive maintenance priority | CTE + weighted RANK |
| 16 | SPC health dashboard (executive) | Nested CTE |

---

## Key Results

| Metric | Value |
|--------|-------|
| Total sensor readings | 3,600 |
| Total anomalies detected | 270 |
| Overall anomaly rate | 7.5% |
| Critical anomalies | 141 |
| Overall defect rate | 3.06% |
| Highest anomaly machine | Machine_B (63 anomalies, 8.75%) |
| Most anomalous sensor | Temperature |
| Peak anomaly shift | Night shift |

---

## How to Run

```bash
# 1. Clone the repository
git clone https://github.com/ramubattu321/manufacturing-process-analysis-eda.git
cd manufacturing-process-analysis-eda

# 2. Install dependencies
pip install -r Requirements.txt

# 3. Run EDA + SPC notebook
jupyter notebook manufacturing_insights.ipynb

# 4. Set up SQL database and run all 16 queries
python sql/setup_and_run.py

# 5. Run SQL directly
sqlite3 sql/manufacturing.db < sql/manufacturing_queries.sql
```

---

## Tools & Technologies

| Tool | Purpose |
|------|---------|
| Python | EDA, cluster sampling, SPC computation |
| Pandas | Data cleaning, aggregation, SPC flagging |
| NumPy | Mean, std, UCL/LCL calculation |
| Matplotlib | Control chart and distribution plots |
| SQL (SQLite) | 16 structured analysis queries |
| Jupyter Notebook | Interactive analysis environment |

---

## Author

**Ramu Battu**
MS in Data Analytics — California State University, Fresno
📧 ramuusa61@gmail.com

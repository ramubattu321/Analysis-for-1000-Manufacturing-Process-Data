"""
Manufacturing Anomaly Detection & SPC — SQL Database Setup
===========================================================
Run: python sql/setup_and_run.py
"""
import sqlite3, pandas as pd, random, os, math
from datetime import datetime, timedelta

DB_PATH = "sql/manufacturing.db"
random.seed(42)

def build_db():
    if os.path.exists(DB_PATH): os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    with open("sql/schema.sql") as f:
        conn.executescript(f.read())
    with open("sql/sample_data.sql") as f:
        conn.executescript(f.read())
    conn.commit()
    return conn

def run(conn, sql, title):
    print(f"\n{'='*60}\n  {title}\n{'='*60}")
    df = pd.read_sql_query(sql, conn)
    print(df.to_string(index=False))

if __name__ == "__main__":
    conn = build_db()
    for t in ["machines","sensor_readings","anomalies","shift_summary"]:
        try:
            n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            print(f"✅ {t}: {n:,} rows")
        except: pass
    run(conn, "SELECT m.machine_name, COUNT(a.anomaly_id) AS anomalies FROM machines m LEFT JOIN anomalies a ON m.machine_id=a.machine_id GROUP BY m.machine_name ORDER BY anomalies DESC", "QUERY 2 — Anomaly Count by Machine")
    run(conn, "SELECT sensor_type, COUNT(*) AS anomalies, ROUND(AVG(deviation),2) AS avg_sigma, ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER(),2) AS pct FROM anomalies GROUP BY sensor_type ORDER BY anomalies DESC", "QUERY 3 — Anomaly by Sensor Type")
    run(conn, "SELECT shift, ROUND(100.0*SUM(defect_count)/NULLIF(SUM(output_units),0),2) AS defect_rate_pct, SUM(output_units) AS output FROM sensor_readings GROUP BY shift ORDER BY defect_rate_pct DESC", "QUERY 5 — Shift Defect Rate")
    print("\n✅ All queries complete!")
    conn.close()

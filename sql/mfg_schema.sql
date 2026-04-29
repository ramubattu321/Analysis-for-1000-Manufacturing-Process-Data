-- ============================================================
-- Manufacturing Anomaly Detection & SPC — Database Schema
-- Compatible with: SQLite, MySQL, PostgreSQL
-- Author: Ramu Battu — MS Data Analytics, CSU Fresno
-- ============================================================

DROP TABLE IF EXISTS anomalies;
DROP TABLE IF EXISTS shift_summary;
DROP TABLE IF EXISTS sensor_readings;
DROP TABLE IF EXISTS machines;

-- ── TABLE 1: MACHINES ─────────────────────────────────────────────────────────
CREATE TABLE machines (
    machine_id   INTEGER PRIMARY KEY,
    machine_name TEXT    NOT NULL,     -- Machine_A through Machine_E
    machine_type TEXT    NOT NULL,     -- CNC Lathe / Press / Conveyor etc.
    location     TEXT    NOT NULL,     -- Zone-1 / Zone-2 / Zone-3
    install_year INTEGER NOT NULL,
    status       TEXT    NOT NULL      -- Active / Inactive / Maintenance
);

-- ── TABLE 2: SENSOR READINGS ──────────────────────────────────────────────────
-- Hourly sensor data per machine — 30 days × 5 machines × 24 readings
CREATE TABLE sensor_readings (
    reading_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id    INTEGER NOT NULL,
    reading_time  DATETIME NOT NULL,   -- Timestamp of sensor reading
    shift         TEXT    NOT NULL,    -- morning / afternoon / night
    temperature   REAL    NOT NULL,    -- Machine temperature (°C)
    pressure      REAL    NOT NULL,    -- Operating pressure (bar)
    vibration     REAL    NOT NULL,    -- Vibration level (mm/s)
    speed_rpm     REAL    NOT NULL,    -- Spindle/motor speed (RPM)
    output_units  INTEGER NOT NULL,    -- Units produced in this interval
    defect_count  INTEGER NOT NULL,    -- Defective units detected
    FOREIGN KEY (machine_id) REFERENCES machines(machine_id)
);

-- ── TABLE 3: ANOMALIES ────────────────────────────────────────────────────────
-- Anomalies detected by 3-sigma SPC analysis
CREATE TABLE anomalies (
    anomaly_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id   INTEGER NOT NULL,
    reading_id   INTEGER NOT NULL,     -- Reference to flagged reading
    sensor_type  TEXT    NOT NULL,     -- temperature / pressure / vibration
    reading_val  REAL    NOT NULL,     -- Actual sensor value
    mean_val     REAL    NOT NULL,     -- Process mean (μ)
    ucl          REAL    NOT NULL,     -- Upper Control Limit (μ + 3σ)
    lcl          REAL    NOT NULL,     -- Lower Control Limit (μ - 3σ)
    deviation    REAL    NOT NULL,     -- Sigma deviation from mean
    severity     TEXT    NOT NULL,     -- Critical (>4σ) / High (>3.5σ) / Medium
    detected_at  DATETIME NOT NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(machine_id)
);

-- ── TABLE 4: SHIFT SUMMARY ────────────────────────────────────────────────────
-- Aggregated daily shift performance per machine
CREATE TABLE shift_summary (
    summary_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id    INTEGER NOT NULL,
    summary_date  DATE    NOT NULL,
    shift         TEXT    NOT NULL,    -- morning / afternoon / night
    avg_temp      REAL,
    avg_pressure  REAL,
    avg_vibration REAL,
    total_output  INTEGER,
    total_defects INTEGER,
    defect_rate   REAL,                -- defects / output * 100
    anomaly_count INTEGER
);

-- ── INDEXES ───────────────────────────────────────────────────────────────────
CREATE INDEX idx_reading_machine ON sensor_readings(machine_id);
CREATE INDEX idx_reading_time    ON sensor_readings(reading_time);
CREATE INDEX idx_reading_shift   ON sensor_readings(shift);
CREATE INDEX idx_anomaly_machine ON anomalies(machine_id);
CREATE INDEX idx_anomaly_sensor  ON anomalies(sensor_type);
CREATE INDEX idx_anomaly_sev     ON anomalies(severity);
CREATE INDEX idx_shift_machine   ON shift_summary(machine_id);
CREATE INDEX idx_shift_date      ON shift_summary(summary_date);

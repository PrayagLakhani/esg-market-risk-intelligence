CREATE TABLE dim_sector (
    sector_id    SERIAL PRIMARY KEY,
    sector_name  TEXT NOT NULL UNIQUE
);

CREATE TABLE dim_company (
    company_id    SERIAL PRIMARY KEY,
    company_name  TEXT NOT NULL,
    ticker        TEXT NOT NULL UNIQUE,
    sector_id     INTEGER REFERENCES dim_sector(sector_id),
    industry      TEXT,
    country       TEXT DEFAULT 'India',
    market_cap_category TEXT
);

CREATE TABLE dim_esg_category (
    esg_category_id  SERIAL PRIMARY KEY,
    category         TEXT NOT NULL UNIQUE,  -- Environmental / Social / Governance
    subcategory      TEXT
);

CREATE TABLE fact_controversy (
    controversy_id    INTEGER PRIMARY KEY,
    company_id        INTEGER REFERENCES dim_company(company_id),
    controversy_date  DATE NOT NULL,
    esg_category_id   INTEGER REFERENCES dim_esg_category(esg_category_id),
    controversy_type  TEXT,
    description        TEXT,
    source_name        TEXT,
    source_url          TEXT,
    confidence          TEXT,  -- 'V' verified / 'K' well-known / (Verify items resolved before this load)
    resolution_date      DATE,
    status                TEXT
);

CREATE TABLE fact_market_daily (
    company_id      INTEGER REFERENCES dim_company(company_id),
    date            DATE NOT NULL,
    open            NUMERIC,
    high            NUMERIC,
    low             NUMERIC,
    close           NUMERIC,
    adjusted_close  NUMERIC,
    volume          BIGINT,
    PRIMARY KEY (company_id, date)
);

CREATE TABLE fact_benchmark_daily (
    date         DATE PRIMARY KEY,
    index_close  NUMERIC,
    volume       BIGINT
);

CREATE TABLE fact_event_window (
    controversy_id          INTEGER PRIMARY KEY REFERENCES fact_controversy(controversy_id),
    company_id               INTEGER REFERENCES dim_company(company_id),
    alpha                     NUMERIC,
    beta                      NUMERIC,
    n_estimation_days         INTEGER,
    car_1_1_marketadj         NUMERIC,
    car_1_1_marketmodel       NUMERIC,
    car_3_3_marketadj         NUMERIC,
    car_3_3_marketmodel       NUMERIC,
    car_5_5_marketadj         NUMERIC,
    car_5_5_marketmodel       NUMERIC,
    car_10_10_marketadj       NUMERIC,
    car_10_10_marketmodel     NUMERIC,
    volume_change_pct         NUMERIC,
    volatility_change         NUMERIC,
    max_drawdown_pct          NUMERIC,
    recovery_days             INTEGER,
    recovered_within_60d      BOOLEAN
);

CREATE INDEX idx_controversy_company ON fact_controversy(company_id);
CREATE INDEX idx_controversy_date ON fact_controversy(controversy_date);
CREATE INDEX idx_market_company_date ON fact_market_daily(company_id, date);

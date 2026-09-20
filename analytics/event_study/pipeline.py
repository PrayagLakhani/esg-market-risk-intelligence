"""
Event-study pipeline.

Computes abnormal returns, CARs, volume changes, volatility changes,
drawdown, and recovery metrics for the finalized controversy events.
"""

import pandas as pd
import numpy as np
import os, sys

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(THIS_DIR, "..", ".."))
DATA_DIR = os.path.join(PROJECT_ROOT, "data", "raw")
OUT_PATH = os.path.join(PROJECT_ROOT, "data", "processed", "fact_event_window.csv")

sys.path.insert(0, THIS_DIR)
from events import events, sector_map, confound_exclusions

def load_prices(ticker):
    df = pd.read_csv(os.path.join(DATA_DIR, f"{ticker}.csv"))
    df.columns = [c.strip() for c in df.columns]
    df['Date'] = pd.to_datetime(df['Date'])
    price_col = 'Adj Close' if 'Adj Close' in df.columns else 'Close'
    df = df.sort_values('Date').reset_index(drop=True)
    df['ret'] = df[price_col].pct_change()
    df = df.rename(columns={price_col: 'price', 'Volume': 'volume'})
    return df[['Date', 'price', 'volume', 'ret']]

nsei = load_prices("NSEI").rename(columns={'ret':'mkt_ret'})[['Date','mkt_ret']]

price_cache = {}
def get_prices(ticker):
    if ticker not in price_cache:
        df = load_prices(ticker)
        df = df.merge(nsei, on='Date', how='left')
        price_cache[ticker] = df
    return price_cache[ticker]

def trading_day_index(df, event_date):
    idx = df[df['Date'] >= event_date].index
    return idx[0] if len(idx) else None

def run():
    results = []
    for eid, ticker, edate_str, category, desc, conf in events:
        df = get_prices(ticker)
        edate = pd.Timestamp(edate_str)
        t0 = trading_day_index(df, edate)
        if t0 is None or t0 < 130 or t0 > len(df) - 35:
            results.append(dict(event_id=eid, ticker=ticker, event_date=edate_str, category=category,
                                 desc=desc, confidence=conf, status="INSUFFICIENT_DATA"))
            continue

        est_start, est_end = t0 - 130, t0 - 21
        ev_start, ev_end = t0 - 10, t0 + 10
        rec_end = min(t0 + 60, len(df) - 1)

        est_df = df.iloc[est_start:est_end+1].dropna(subset=['ret','mkt_ret']).copy()
        excl_dates = [d for (tk, d) in confound_exclusions if tk == ticker]
        if excl_dates:
            est_df = est_df[~est_df['Date'].dt.strftime('%Y-%m-%d').isin(excl_dates)]

        if len(est_df) >= 30:
            X = np.vstack([np.ones(len(est_df)), est_df['mkt_ret'].values]).T
            y = est_df['ret'].values
            try:
                coef, *_ = np.linalg.lstsq(X, y, rcond=None)
                alpha, beta = coef
            except Exception:
                alpha, beta = 0.0, 1.0
        else:
            alpha, beta = 0.0, 1.0

        ev_df = df.iloc[ev_start:ev_end+1].copy()
        ev_df['ar_marketadj'] = ev_df['ret'] - ev_df['mkt_ret']
        ev_df['ar_marketmodel'] = ev_df['ret'] - (alpha + beta * ev_df['mkt_ret'])
        ev_df['rel_day'] = range(-10, 11)

        def car(window):
            lo, hi = window
            sub = ev_df[(ev_df['rel_day'] >= lo) & (ev_df['rel_day'] <= hi)]
            return sub['ar_marketadj'].sum(), sub['ar_marketmodel'].sum()

        car_1_1, car_3_3, car_5_5, car_10_10 = car((-1,1)), car((-3,3)), car((-5,5)), car((-10,10))

        baseline_vol = est_df['volume'].mean() if 'volume' in est_df else np.nan
        event_vol = ev_df['volume'].mean() if 'volume' in ev_df else np.nan
        vol_change_pct = (event_vol - baseline_vol) / baseline_vol * 100 if baseline_vol else np.nan
        vola_change = ev_df['ret'].std() - est_df['ret'].std()

        pre_price = df.iloc[t0-1]['price']
        rec_df = df.iloc[t0:rec_end+1].copy()
        trough_idx = rec_df['price'].idxmin()
        max_drawdown = (df.loc[trough_idx, 'price'] / pre_price) - 1
        recovered = rec_df[rec_df['price'] >= pre_price]
        recovery_days = int(recovered.index[0] - t0) if len(recovered) else None
        recovered_flag = len(recovered) > 0

        results.append(dict(
            event_id=eid, ticker=ticker, sector=sector_map[ticker], event_date=edate_str,
            category=category, desc=desc, confidence=conf, status="OK",
            alpha=round(alpha,5), beta=round(beta,3), n_estimation_days=len(est_df),
            car_1_1_marketadj=round(car_1_1[0]*100,2), car_1_1_marketmodel=round(car_1_1[1]*100,2),
            car_3_3_marketadj=round(car_3_3[0]*100,2), car_3_3_marketmodel=round(car_3_3[1]*100,2),
            car_5_5_marketadj=round(car_5_5[0]*100,2), car_5_5_marketmodel=round(car_5_5[1]*100,2),
            car_10_10_marketadj=round(car_10_10[0]*100,2), car_10_10_marketmodel=round(car_10_10[1]*100,2),
            volume_change_pct=round(vol_change_pct,1) if pd.notna(vol_change_pct) else None,
            volatility_change=round(vola_change,5) if pd.notna(vola_change) else None,
            max_drawdown_pct=round(max_drawdown*100,2),
            recovery_days=recovery_days, recovered_within_60d=recovered_flag,
        ))

    out = pd.DataFrame(results)
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    out.to_csv(OUT_PATH, index=False)
    print(out.to_string(index=False))
    print(f"\nWrote {OUT_PATH}")
    return out

if __name__ == "__main__":
    run()

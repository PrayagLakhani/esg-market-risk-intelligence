# Finalized event list: 20 companies, 25 controversies
events = [
    # (event_id, ticker, event_date, category, description, confidence)
    (1,  "OIL",        "2020-05-27", "Environmental", "Baghjan well blowout & fire, Assam", "V"),
    (2,  "RELIANCE",   "2017-03-24", "Governance",     "SEBI disgorgement order, RPL insider trading", "V"),
    (3,  "ADANIENT",   "2023-01-24", "Governance",     "Hindenburg Research report", "V"),
    (4,  "ADANIENT",   "2024-11-20", "Governance",     "US DOJ bribery indictment (Gautam Adani)", "K"),
    (5,  "VEDL",       "2018-05-22", "Environmental",  "Sterlite Copper Tuticorin protests", "V"),
    (6,  "TATASTEEL",  "2014-09-24", "Governance",     "Supreme Court cancels 204 coal-block allocations", "V"),
    (7,  "TATASTEEL",  "2024-01-19", "Social",         "Port Talbot blast-furnace closure, 2800 jobs", "V"),
    (8,  "JSWSTEEL",   "2014-09-24", "Governance",     "Coal-block cancellation (sector-contagion pair)", "V"),
    (9,  "YESBANK",    "2020-03-05", "Governance",     "Governance crisis: RBI moratorium (Mar 5) + Rana Kapoor arrest (Mar 8) + SBI-led rescue", "K"),
    (11, "PNB",        "2018-02-14", "Governance",     "Nirav Modi / Mehul Choksi LoU fraud disclosed", "K"),
    (12, "ICICIBANK",  "2018-03-28", "Governance",     "Kochhar-Videocon scandal breaks publicly", "V"),
    (13, "DHFL",       "2019-01-29", "Governance",     "Cobrapost expose, fund diversion allegations", "V"),
    (14, "DHFL",       "2019-06-04", "Governance",     "Default on NCD interest payment", "V"),
    (15, "MARUTI",     "2012-07-18", "Social",         "Manesar plant violence", "K"),
    (16, "MARUTI",     "2021-08-23", "Governance",     "CCI fines Maruti for restricting dealer discounts", "V"),
    (17, "TATAMOTORS", "2008-10-03", "Social",         "Nano plant relocated from Singur after protests", "K"),
    (18, "INFY",       "2017-08-18", "Governance",     "CEO Vishal Sikka resigns amid governance clash", "K"),
    (19, "INFY",       "2019-10-21", "Governance",     "Whistleblower complaints against CEO", "K"),
    (20, "SATYAM",     "2009-01-07", "Governance",     "Chairman confesses to accounting fraud", "K"),
    (21, "NTPC",       "2017-11-01", "Social",         "Unchahar plant boiler explosion", "K"),
    (23, "RANBAXY",    "2008-09-16", "Governance",     "US FDA import alert, Paonta Sahib plant", "V"),
    (24, "RANBAXY",    "2013-05-13", "Governance",     "Guilty plea to US DOJ, $500M settlement", "K"),
    (25, "SUNPHARMA",  "2015-12-17", "Governance",     "USFDA warning letter, Halol facility", "V"),
    (27, "HINDUNILVR", "2001-03-07", "Environmental",  "Kodaikanal mercury dumping exposed by Greenpeace/local protests", "V"),
    (28, "NESTLEIND",  "2015-06-05", "Social",         "Maggi noodles lead-content ban, nationwide recall", "K"),
]

sector_map = {
    "OIL": "Energy", "RELIANCE": "Energy", "ADANIENT": "Energy",
    "VEDL": "Metals & Mining", "TATASTEEL": "Metals & Mining", "JSWSTEEL": "Metals & Mining",
    "YESBANK": "Financials", "PNB": "Financials", "ICICIBANK": "Financials", "DHFL": "Financials",
    "MARUTI": "Automobiles", "TATAMOTORS": "Automobiles",
    "INFY": "IT", "SATYAM": "IT",
    "NTPC": "Power", "ADANIPOWER": "Power",
    "RANBAXY": "Pharma", "SUNPHARMA": "Pharma",
    "HINDUNILVR": "FMCG", "NESTLEIND": "FMCG",
}

# Known confounds to exclude from estimation-window regression (date, ticker)
confound_exclusions = {
    ("DHFL", "2018-09-21"): "IL&FS-crisis contagion crash, unrelated to tagged DHFL events",
    ("PNB", "2017-10-25"): "PSU bank recapitalization announcement, sector-wide rally",
}

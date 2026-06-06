#!/bin/bash
# Refresh VP Operations data from Tableau Cloud
# Run: ./refresh-data.sh
# Requires: tabcmd (logged in), python3, git

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/tableau-refresh"
mkdir -p "$TEMP_DIR"

echo "Exporting data from Tableau Cloud..."
cd "$TEMP_DIR"
tabcmd export "VPOperations2/VPOp" --csv -f vp_op.csv 2>/dev/null
tabcmd export "VPOperations2/Excess" --csv -f excess.csv 2>/dev/null
tabcmd export "VPOperations2/Sales" --csv -f sales.csv 2>/dev/null

echo "Building data.json..."
python3 << 'PYEOF'
import csv, json, datetime

def clean(s):
    if not s: return None
    s = str(s).strip().replace(',','').replace('$','').replace('(','').replace(')','')
    s = s.replace('▲','').replace('▼','').replace('+','').replace('%','').strip()
    try: return float(s)
    except: return None

vp = {}
with open('vp_op.csv') as f:
    for row in csv.DictReader(f):
        vp = row; break

sales_cy = sales_py = 0
with open('sales.csv') as f:
    for row in csv.DictReader(f):
        cy = clean(row.get('Sales CY',''))
        py = clean(row.get('Sales PY',''))
        if cy: sales_cy += cy
        if py: sales_py += py

ex = {}
with open('excess.csv') as f:
    for row in csv.DictReader(f):
        ex = row; break

ws_ytd = clean(vp.get('YTD Total',''))
qws_ytd = clean(vp.get('YTD',''))
ws_mtd = clean(vp.get('MTD Total',''))
qws_mtd = clean(vp.get('MTD',''))
diff = sales_cy - sales_py if sales_py else 0
pct = (diff / sales_py * 100) if sales_py else 0

data = {
    "lastUpdated": datetime.datetime.utcnow().isoformat() + "Z",
    "salesYtdVal": sales_cy, "salesYtdDiff": diff, "salesYtdPct": pct,
    "salesMtdVal": clean(vp.get('YoY MTD Total Sales Diff ','')) or 0,
    "salesMtdDiff": None, "salesMtdPct": None,
    "wsYtdVal": ws_ytd, "wsMtdVal": ws_mtd, "wsYtdPct": -24.5, "wsYtdDiff": -9100000,
    "wsMtdPct": -1.0, "wsMtdDiff": -7800,
    "qwsYtdVal": qws_ytd, "qwsMtdVal": qws_mtd, "qwsYtdPct": -23.5, "qwsYtdDiff": -6100000,
    "qwsMtdPct": 32.2, "qwsMtdDiff": 195000,
    "orderbookVal": 82800000, "orderbookProjectVal": 7000000, "orderbookProjectPct": 8.51,
    "orderbookOutletVal": 1800000, "orderbookOutletPct": 2.15,
    "orderbookUpgradeVal": 1400000, "orderbookUpgradePct": 20.54,
    "supplyYtdVal": 16000000, "supplyYtdDiff": -3700000, "supplyYtdPct": -18.7,
    "supplyMtdVal": 261000, "supplyRcvdVal": 1500000, "supplyRcvdDiff": -196000, "supplyRcvdPct": -11.5,
    "invYtdVal": 11600000, "invYtdDiff": 927000, "invYtdPct": 8.7,
    "invMtdVal": 11600000, "invMtdDiff": 2500000, "invMtdPct": 27.5,
    "invCadYtdVal": 17800000, "invCadYtdDiff": 1500000, "invCadYtdPct": 8.9,
    "invCadMtdVal": 17800000, "invCadMtdDiff": 3700000, "invCadMtdPct": 25.8,
    "excessNewVal": (clean(ex.get('Excess Product','')) or 0) + (clean(ex.get('Excess Accessory','')) or 0),
    "excessNewQty": str(int(clean(ex.get('Excess Product Qty','')) or 0) + int(clean(ex.get('Excess Accessory Qty','')) or 0)),
    "excessOutletVal": 1100000, "excessOutletQty": "348"
}

import os
target = os.environ.get('SCRIPT_DIR', '.') + '/data.json'
with open(target, 'w') as f:
    json.dump(data, f, indent=2)
print(f"Updated {target}")
PYEOF

echo "Pushing to GitHub Pages..."
cd "$SCRIPT_DIR"
git add data.json
git commit -m "Data refresh $(date '+%Y-%m-%d %H:%M')"
git push

echo "Done! Data will be live on GitHub Pages in ~1 minute."

"""
Runs every query in sql/ against the cleaned CSVs, without needing a MySQL server.

The queries are written for MySQL 8. Each one is translated to DuckDB with sqlglot and run on an
in-memory database loaded from data/processed/. The CREATE TABLE / LOAD DATA statements are MySQL-only
and are skipped. The run fails if a query errors or a data-quality check (DQ1-DQ5) finds a problem,
and the headline numbers are re-calculated with pandas to make sure SQL and Python agree.

Run:  python scripts/run_sql_tests.py        (add -v to print the first rows of every result)
"""
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd
import sqlglot

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR, DATA = ROOT / "sql", ROOT / "data" / "processed"
VERBOSE = "-v" in sys.argv
SKIP = re.compile(r"^\s*(CREATE\s+DATABASE|USE\s|DROP\s+TABLE|CREATE\s+TABLE|LOAD\s+DATA|SET\s+GLOBAL)", re.I)
TABLES = ["order_lines", "products", "customers", "countries", "delivery_charges"]
TEXT_COLS = {"invoice_no": "VARCHAR", "stock_code": "VARCHAR", "customer_id": "VARCHAR"}


def split_statements(sql: str):
    """Yield (label, statement). The label is the '-- XX1: question' comment above the query."""
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    current, label = [], None
    for line in sql.splitlines():
        m = re.match(r"\s*--\s*([A-Z]+\d+):\s*(.*)", line)
        if m and not "".join(current).strip():
            label = f"{m.group(1)} {m.group(2)}".strip()
        current.append(re.sub(r"--.*$", "", line))
        if line.rstrip().endswith(";"):
            stmt = "\n".join(current).strip().rstrip(";")
            if stmt:
                yield label, stmt
            current, label = [], None


def main() -> int:
    con = duckdb.connect()
    for t in TABLES:
        path = DATA / f"{t}.csv"
        with open(path, encoding="utf-8") as f:
            header = f.readline().strip().split(",")
        types = {c: v for c, v in TEXT_COLS.items() if c in header}  # keep ids as text, e.g. '85123A'
        options = f", types={types}" if types else ""
        con.execute(f"CREATE TABLE {t} AS SELECT * FROM read_csv('{path.as_posix()}'{options})")

    failures, ran = [], 0
    for path in sorted(SQL_DIR.glob("*.sql")):
        for label, stmt in split_statements(path.read_text(encoding="utf-8")):
            if SKIP.match(stmt):
                continue
            try:
                duck = sqlglot.transpile(stmt, read="mysql", write="duckdb")[0]
                res = con.execute(duck).fetchdf()
                ran += 1
                status = f"{len(res):>5} rows"
                if label and label.startswith("DQ") and label[:3] != "DQ6":
                    problems = len(res) if label.startswith("DQ1") else int(res.select_dtypes("number").fillna(0).to_numpy().sum())
                    if problems:
                        failures.append((path.name, label, f"{problems} data-quality problems"))
                        status += "  <-- DQ FAIL"
                print(f"  ok  {path.name:<30} {(label or '')[:70]:<70} {status}")
                if VERBOSE:
                    print(res.head(8).to_string(), "\n")
            except Exception as exc:  # noqa: BLE001
                failures.append((path.name, label, str(exc).splitlines()[0]))
                print(f"FAIL  {path.name:<30} {(label or '')[:70]:<70} {exc}")

    # re-calculate the headline numbers with pandas
    o = pd.read_csv(DATA / "order_lines.csv", dtype={"invoice_no": str, "stock_code": str, "customer_id": str})
    sql_sales, sql_returns = con.execute(
        "SELECT SUM(CASE WHEN line_type='Sale' THEN line_value END), -SUM(CASE WHEN line_type='Return' THEN line_value END) FROM order_lines"
    ).fetchone()
    checks = {
        "gross sales": (sql_sales, o.loc[o.line_type == "Sale", "line_value"].sum()),
        "returned value": (sql_returns, -o.loc[o.line_type == "Return", "line_value"].sum()),
    }
    for name, (sql_v, pd_v) in checks.items():
        ok = abs(float(sql_v) - float(pd_v)) < 0.5
        print(f"  {'ok' if ok else 'FAIL'}  reconcile {name:<15} sql={float(sql_v):,.2f}  pandas={float(pd_v):,.2f}")
        if not ok:
            failures.append(("reconcile", name, "mismatch"))

    print(f"\n{ran} queries run, {len(failures)} failure(s)")
    for f in failures:
        print("   -", *f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

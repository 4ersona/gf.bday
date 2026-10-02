#!/usr/bin/env python3
"""Pricing calculator for the Lumette catalog.

Formula (per market):
    landed_cost = cj_cost + cj_shipping(+ packaging_extra)
    price       = (landed_cost + fixed_fee) / (1 - payment_pct - target_margin)
    -> rounded UP to the next *.95 so the margin target is never undercut.

target_margin is the margin BEFORE ad spend (contribution after product, shipping and
payment fees). Organic-first stores can hold ~50-65%; once Google Ads is on, an ad
allowance of 20-30% of price must come out of that, so winners need >= 50% before ads.

Defaults assume Shopify Payments US/CA basic card rate of 2.9% + $0.30. VERIFY your plan's rate.
FX default is a rough placeholder: pass --fx with today's USD->CAD rate.
All costs in catalog.csv are ILLUSTRATIVE ESTIMATES. Replace with CJ's real numbers.

Usage:
    python3 tools/pricing.py catalog/catalog.csv catalog/catalog_priced.csv --fx 1.37
    python3 tools/pricing.py --cost 3.2 --ship 3.5 --margin 0.55          # one-off
"""
import argparse, csv, math, sys

def round_up_95(x: float) -> float:
    return math.floor(x) + 0.95 if x <= math.floor(x) + 0.95 else math.floor(x) + 1.95

def price(cost, ship, margin, pay_pct=0.029, fixed=0.30, extra=0.0):
    denom = 1 - pay_pct - margin
    if denom <= 0:
        raise ValueError("pay_pct + margin must be < 1")
    return round_up_95((cost + ship + extra + fixed) / denom)

def realised_margin(p, cost, ship, pay_pct=0.029, fixed=0.30, extra=0.0):
    return (p - cost - ship - extra - p * pay_pct - fixed) / p

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--fx", type=float, default=1.37, help="USD->CAD rate (placeholder default, verify)")
    ap.add_argument("--pay-pct", type=float, default=0.029)
    ap.add_argument("--fixed", type=float, default=0.30)
    ap.add_argument("--extra", type=float, default=0.30, help="per-order packaging/other cost, USD")
    ap.add_argument("--cost", type=float); ap.add_argument("--ship", type=float)
    ap.add_argument("--margin", type=float, default=0.55)
    a = ap.parse_args()
    if a.cost is not None:
        p = price(a.cost, a.ship or 0, a.margin, a.pay_pct, a.fixed, a.extra)
        print(f"price {p:.2f}  realised margin {realised_margin(p, a.cost, a.ship or 0, a.pay_pct, a.fixed, a.extra):.1%}")
        return
    if not (a.src and a.dst):
        ap.error("give src and dst CSV, or --cost/--ship")
    rows = list(csv.DictReader(open(a.src, newline="")))
    out = []
    for r in rows:
        cost = float(r["est_cj_cost_usd"]); m = float(r["target_margin"])
        us_ship = float(r["est_cj_ship_usd_us"]); ca_ship = float(r["est_cj_ship_usd_ca"])
        p_us = price(cost, us_ship, m, a.pay_pct, a.fixed, a.extra)
        # Canada: costs converted to CAD, same % fees, fixed fee in CAD
        p_ca = price(cost * a.fx, ca_ship * a.fx, m, a.pay_pct, a.fixed, a.extra * a.fx)
        r2 = dict(r)
        r2.update({
            "price_usd": f"{p_us:.2f}", "margin_usd_realised": f"{realised_margin(p_us, cost, us_ship, a.pay_pct, a.fixed, a.extra):.1%}",
            "price_cad": f"{p_ca:.2f}",
            "margin_cad_realised": f"{realised_margin(p_ca, cost*a.fx, ca_ship*a.fx, a.pay_pct, a.fixed*1.0, a.extra*a.fx):.1%}",
            "free_ship_note": "free-shipping orders absorb shipping: need basket >= threshold AND 2+ items to protect margin",
        })
        out.append(r2)
    with open(a.dst, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
    print(f"wrote {len(out)} rows to {a.dst}")
    for r in out:
        print(f"{r['slot']} {r['title'][:38]:38} US ${r['price_usd']:>6} ({r['margin_usd_realised']})  CA ${r['price_cad']:>6} ({r['margin_cad_realised']})")

if __name__ == "__main__":
    main()

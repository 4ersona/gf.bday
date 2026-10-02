#!/usr/bin/env python3
"""Convert a Shopify product export (Admin > Products > Export, CSV) into a Google
Merchant Center feed (tab-separated) and validate it against common disapproval causes.

PRIMARY RECOMMENDATION: use the official "Google & YouTube" Shopify app for the live,
auto-syncing feed (it knows variant IDs and inventory in real time). Use this script to
(1) audit your catalog BEFORE it syncs and (2) produce a file feed for a supplemental
or fallback feed.

Usage:
  python3 tools/merchant_feed.py products_export.csv feed.tsv \
      --domain lumette.com --brand Lumette --currency USD [--taxonomy taxonomy-with-ids.en-US.txt]

Exit code 1 when there are blocking errors.
"""
import argparse, csv, html, re, sys
from collections import defaultdict

# Google product taxonomy by Shopify "Type". VERIFY each value against Google's current taxonomy file
# (https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt) - pass it with --taxonomy
# and the script will flag any category that does not exist.
CATEGORY_MAP = {
    "Hair Styling Tools": "Health & Beauty > Personal Care > Hair Care > Hair Styling Tools",
    "Hair Accessories": "Apparel & Accessories > Clothing Accessories > Hair Accessories",
    "Hair Care Tools": "Health & Beauty > Personal Care > Hair Care",
    "Makeup Tools": "Health & Beauty > Personal Care > Cosmetics",
    "Mirrors": "Health & Beauty > Personal Care > Cosmetics",
    "Storage": "Health & Beauty > Personal Care > Cosmetics",
    "Bags": "Luggage & Bags > Cosmetic & Toiletry Bags",
    "Skincare Tools": "Health & Beauty > Personal Care > Skin Care",
    "Eye Tools": "Health & Beauty > Personal Care > Cosmetics",
}
DEFAULT_CATEGORY = "Health & Beauty > Personal Care > Cosmetics"

PROMO_RE = re.compile(r"(free shipping|% off|sale|best price|buy now|limited time|#1|guaranteed)", re.I)
CLAIM_RE = re.compile(r"\b(cure|treat|heal|anti-?aging|wrinkle|detox|hair growth|clinically|FDA|miracle)\b", re.I)
HEADERS = ["id", "title", "description", "link", "image_link", "additional_image_link", "availability", "price",
           "condition", "brand", "gtin", "mpn", "identifier_exists", "google_product_category", "product_type",
           "item_group_id", "color", "size", "shipping_weight", "adult"]

def strip_html(s):
    s = re.sub(r"<(br|/p|/li|/h\d)\s*/?>", " ", s or "", flags=re.I)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s))).strip()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--domain", required=True, help="primary domain without scheme, e.g. lumette.com")
    ap.add_argument("--brand", required=True); ap.add_argument("--currency", default="USD")
    ap.add_argument("--taxonomy", help="path to Google's taxonomy-with-ids txt (optional, enables category validation)")
    a = ap.parse_args()

    taxonomy = None
    if a.taxonomy:
        taxonomy = {l.split(" - ", 1)[1].strip() for l in open(a.taxonomy, encoding="utf-8") if " - " in l}

    rows = list(csv.DictReader(open(a.src, newline="", encoding="utf-8-sig")))
    products = defaultdict(list)
    order = []
    for r in rows:
        h = r.get("Handle")
        if not h: continue
        if h not in products: order.append(h)
        products[h].append(r)

    errors, warns, out = [], [], []
    for h in order:
        rs = products[h]; head = rs[0]
        title = (head.get("Title") or "").strip()
        status = (head.get("Status") or "active").lower()
        if status != "active" or (head.get("Published") or "true").lower() == "false":
            continue
        desc = strip_html(head.get("Body (HTML)"))
        ptype = (head.get("Type") or "").strip()
        images = [(int(r.get("Image Position") or 0), r["Image Src"]) for r in rs if r.get("Image Src")]
        images.sort(); img_urls = [u for _, u in images]
        if not title: errors.append(f"{h}: missing title"); continue
        if len(title) > 150: errors.append(f"{h}: title is {len(title)} chars (max 150)")
        elif len(title) > 70: warns.append(f"{h}: title is {len(title)} chars; keep the key words in the first 70")
        if title.isupper(): errors.append(f"{h}: title is ALL CAPS")
        if PROMO_RE.search(title): errors.append(f"{h}: promotional text in title ('{PROMO_RE.search(title).group(0)}')")
        if len(desc) < 50: warns.append(f"{h}: description under 50 chars; write a real one")
        if len(desc) > 5000: errors.append(f"{h}: description over 5000 chars")
        if CLAIM_RE.search(title + " " + desc): warns.append(f"{h}: risky claim word '{CLAIM_RE.search(title + ' ' + desc).group(0)}' (health/medical claims can cause disapproval)")
        if not img_urls: errors.append(f"{h}: no image"); continue
        cat = CATEGORY_MAP.get(ptype, DEFAULT_CATEGORY)
        if not ptype: warns.append(f"{h}: empty Type; using default category")
        if taxonomy is not None and cat not in taxonomy: errors.append(f"{h}: category not in taxonomy: {cat}")
        names = [head.get(f"Option{i} Name") for i in (1, 2, 3)]
        multi = len([r for r in rs if r.get("Variant Price")]) > 1
        for n, r in enumerate([r for r in rs if r.get("Variant Price")], 1):
            try: price = float(r["Variant Price"])
            except ValueError: errors.append(f"{h}: bad price '{r.get('Variant Price')}'"); continue
            if price <= 0: errors.append(f"{h}: price must be > 0")
            opts = {}
            for i, nm in enumerate(names, 1):
                if nm and r.get(f"Option{i} Value") and nm != "Title":
                    opts[nm.lower()] = r[f"Option{i} Value"]
            vtitle = title + (" - " + " / ".join(opts.values()) if opts else "")
            qty = r.get("Variant Inventory Qty"); tracker = (r.get("Variant Inventory Tracker") or "").strip()
            policy = (r.get("Variant Inventory Policy") or "deny").lower()
            in_stock = (not tracker) or policy == "continue" or (qty not in (None, "") and float(qty) > 0)
            gtin = re.sub(r"\D", "", r.get("Variant Barcode") or "")
            if gtin and len(gtin) not in (8, 12, 13, 14): warns.append(f"{h}: barcode '{gtin}' is not a valid GTIN length"); gtin = ""
            vimg = r.get("Variant Image") or img_urls[0]
            if not vimg.startswith("https://"): errors.append(f"{h}: image not https")
            grams = r.get("Variant Grams")
            out.append({
                "id": r.get("Variant SKU") or f"{h}-{n}", "title": vtitle[:150], "description": desc[:5000],
                "link": f"https://{a.domain}/products/{h}", "image_link": vimg,
                "additional_image_link": ",".join(u for u in img_urls[1:11] if u != vimg),
                "availability": "in_stock" if in_stock else "out_of_stock",
                "price": f"{price:.2f} {a.currency}", "condition": "new", "brand": a.brand,
                "gtin": gtin, "mpn": "", "identifier_exists": "" if gtin else "no",
                "google_product_category": cat, "product_type": ptype, "item_group_id": h if multi else "",
                "color": opts.get("color", ""), "size": opts.get("size", ""),
                "shipping_weight": f"{float(grams):.0f} g" if grams not in (None, "", "0", "0.0") else "", "adult": "no",
            })
    ids = [o["id"] for o in out]
    dupes = {i for i in ids if ids.count(i) > 1}
    for d in dupes: errors.append(f"duplicate id: {d} (give every variant a unique SKU)")
    with open(a.dst, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=HEADERS, delimiter="\t", quoting=csv.QUOTE_MINIMAL); w.writeheader(); w.writerows(out)
    print(f"{len(out)} feed rows from {len(order)} products -> {a.dst}")
    for e in errors: print("ERROR", e)
    for w_ in warns: print("WARN ", w_)
    print(f"{len(errors)} errors, {len(warns)} warnings")
    print("Reminder: shipping, tax and return policy are set inside Merchant Center, not in this file.")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()

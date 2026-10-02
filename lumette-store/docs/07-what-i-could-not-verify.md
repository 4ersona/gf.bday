# 7. What I could not verify

This was built without access to a Shopify store, CJdropshipping account, Google account or a browser against Shopify's renderer. Everything below is therefore a known gap. Items marked **HIGH** can cost money or block launch.

## Verified in this build
- Theme passes Shopify's official **Theme Check** (`@shopify/theme-check-node`): zero errors; one warning (the GA4 script loaded from Google when tracking is switched on).
- All JSON (templates, locales, settings) parses; EN and FR locale files have identical keys.
- `theme.js` passes a syntax check and was smoke-tested in headless Chromium against hand-written mock markup (quantity stepper, variant switching and sold-out state, add-to-cart into the cart drawer, sticky bar appearing on scroll, delivery-estimate dates, popup open/Esc-close, drawer Esc-close): no runtime errors. The mock is not Shopify's real output. `tools/pricing.py` and `tools/merchant_feed.py` were run against sample data. Palette contrast was computed with `tools/contrast_check.py`.
- The zip has theme files at its root, as Shopify requires.

## Not verified: theme behaviour
- The theme was **never rendered by Shopify**. Liquid objects, filters and JSON template references pass Theme Check, but real rendering, the interaction of the JavaScript with Shopify's actual responses (Cart API sections, Section Rendering API, filter form, customer form POST) and layout on real devices are untested. Expect to fix small bugs on first upload. **HIGH**
- **Font IDs** (`playfair_display_n4`, `assistant_n4`) are what I believe Shopify's font library uses. If either is missing in your admin, pick a font in Theme settings > Typography.
- **Collection filters** need Search & Discovery configured; filter canonical/robots behaviour is unverified (see docs/03).
- **Custom Pixel** (`tracking/custom-pixel.js`) uses Shopify's analytics event names (`checkout_started`, `checkout_completed`) and property paths from memory; check against Shopify's current Web Pixels API docs and test in GA4 DebugView.
- The Track Your Order page deep-links to `https://t.17track.net/en#nums=<number>`. I could not confirm that URL format still works; swap in AfterShip/Parcel Panel if needed.
- Product recommendations use Shopify's `recommendations` API. Results are empty until Shopify has data/related products.
- Accessibility: contrast was computed, focus management and ARIA were written to spec, but no screen reader or axe audit was run.
- French strings were machine-assisted. They need a native (Quebec) reader. Quebec's French-language rules (Bill 96) may require more than translation (e.g., French-first content for Quebec consumers).

## Not verified: business facts
- **CJ delivery times (HIGH).** I have no live access to CJ. The 8-18 / 3-8 / 3-9 business-day windows are conservative assumptions based on commonly reported ranges for CJ's standard lines (processing 1-3 days plus roughly 7-15 days transit from China; faster from US/CA warehouses). CJ's lines, prices and times change. **Replace them using CJ's shipping calculator and your own sample orders.**
- **CJ costs (HIGH).** All costs in `catalog.csv` are illustrative. The resulting prices may be above or below market.
- **US tariffs and de minimis (HIGH).** Rules for duties on low-value parcels from China have changed repeatedly (the US ended the duty-free de minimis exemption in 2025, with later changes). I can't confirm the situation today or how CJ handles it for each line (DDP vs DDU). This affects prices, delivery times and whether customers get surprise charges. Check before pricing and fix the Shipping policy wording.
- **Payment fees** (2.9% + $0.30) are the common Shopify Payments US rate on some plans; yours may differ.
- **FX rate** 1.37 USD->CAD is a placeholder.
- **Tax thresholds and registration rules** (US nexus; Canada CAD 30,000 small-supplier threshold; Quebec QST) are summarized from memory and change. Ask an accountant.
- **Shopify's checkout and admin menu names** change often. Where steps differ from your admin, trust the admin.
- **Google product taxonomy categories** in `merchant_feed.py` could not be checked (Google's file was unreachable from this environment). Download the file and run with `--taxonomy`.
- **Merchant Center / Google Ads current rules**, including which campaign types new Shopping accounts get, were not checked live.
- **Legal copy** (policies) is drafted, not lawyer-reviewed, and is not legal advice. CASL, CAN-SPAM, CCPA/CPRA, PIPEDA, Quebec Law 25 and Bill 96, and product regulations (electrical certification, textile labelling, cosmetic-tool claims) need a professional check.
- **Brand name, domain and trademark availability** were not checked.
- **Product compliance** of any specific CJ item (battery certification, materials, "latex-free" etc.) can only be confirmed with CJ's documents.

## Things deliberately left for you
- Real photos and logo upload, reviews app choice and install, domain purchase, legal entity, tax registration, payment verification.
- Product-level metafields (benefits, how to use, shipping origin).
- A real return address for `{{RETURN_ADDRESS}}`.

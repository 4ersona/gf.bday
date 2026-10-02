# Handoff: Lumette Shopify store

Paste the "Starter prompt" at the bottom into a new Claude Code session opened on this repo (branch `claude/blissful-cannon-y5pjmj`, PR https://github.com/4ersona/gf.bday/pull/1).

## Goal
Launch-ready Shopify beauty-tools dropshipping store (CJdropshipping, US + Canada, EN + FR). Working brand name: **Lumette** (unverified domain/trademark). Honesty rules: no fake reviews, timers, stock counters or "as seen in"; realistic CJ delivery windows; no health claims.

## Repo contents (`lumette-store/`)
- `theme/` Shopify OS2.0 theme source; `dist/lumette-theme.zip` built by `tools/build_zip.sh`
- `docs/01..07` brand, catalog, SEO/ads, setup checklist, content plan, email flow, **unverified items (read 07)**
- `copy/en`, `copy/fr` page + policy copy (merge fields `{{BRAND}}`, `{{LEGAL_NAME}}`, `{{BUSINESS_ADDRESS}}`, `{{SUPPORT_EMAIL}}`, `{{RETURN_ADDRESS}}`, `{{EFFECTIVE_DATE}}`, `{{JURISDICTION}}`)
- `catalog/catalog.csv` (18 product slots, ILLUSTRATIVE costs), `catalog_priced.csv`
- `tools/pricing.py`, `merchant_feed.py`, `contrast_check.py`; `tracking/custom-pixel.js`
- Theme Check passes (1 expected warning). JS smoke-tested only against mock markup, never on real Shopify rendering.

## Connected Shopify store (via Shopify MCP connector)
Store: `qjmgy1-jt.myshopify.com` ("My Store 2"), Basic plan, **store currency CAD**, Canada, EDT. Live theme is still Horizon (publishing is blocked for the connector; user must publish).

Already created in the store:
- Collections (handles exact): heatless-hair 508638036153, hair-tools 508638068921, makeup-brushes 508638101689, vanity-organizers 508638134457, face-skin-tools 508638167225, nails-lashes 508638199993, best-sellers 508638232761 (BEST_SELLING sort). IDs are `gid://shopify/Collection/<id>`.
- Product metafield definitions (namespace `custom`): benefits (list.single_line_text), short_description, how_to_use, whats_included, specs, shipping_origin (choices cn/us/ca).
- Discount `WELCOME10`: 10%, once per customer, all customers, no end date.
- Pages (all unpublished except Contact): About (about template), FAQ (faq), Track your order (track-order), Shipping Policy, Returns and Refunds, Privacy Policy, Terms of Service. Policy pages still contain `{{...}}` placeholders, so keep unpublished until filled. The pre-existing Contact page (published, template `contact`) has default body.
- Menus: `main-menu` (Shop dropdown + Best Sellers, About, FAQ, Track Your Order), `footer` (six collections), `footer-help` (new).
- Theme "Lumette 1.0" uploaded UNPUBLISHED: `gid://shopify/OnlineStoreTheme/186308165817` (loaded from the raw GitHub URL of the zip on this branch). Re-upload after theme changes via `themeCreate` or `themeFilesUpsert` (unpublished theme only).
- Store has 0 products. Only fulfillment service is "Manual" (no CJ fulfillment service seen).

## Blocked / open
1. **CJ site is blocked by the network egress proxy** (`www.cjdropshipping.com`). User asked how to allowlist it: environment menu in session title bar > Edit > Network access > allowed domains. User could not find it. Fallback: user pastes/screenshots CJ listings (name, price, link, warehouse, ship estimate to US/CA, rating).
   Category page the user wants mined: https://www.cjdropshipping.com/list/wholesale-health-beauty-hair-l-2C7D4A0B-1AB2-41EC-8F9E-13DC31B1C902.html
2. **CJ app**: user says it is linked, but the store shows no CJ fulfillment service. Needs verifying in Shopify Apps and in CJ's store authorization. Products should be imported through the CJ app so orders auto-fulfil. Manual Shopify products would not be linked to CJ.
3. **Currency decision**: store is CAD; docs/catalog assume USD base. Decide: CAD base + USD via Markets (needs Markets setup), or recreate store with USD base. Free-shipping settings in theme: $50 USD / $65 CAD.
4. **User-only steps**: payments, tax registration, domain, legal entity, filling merge fields, publishing theme/pages, real CJ sample orders, reviews app, Google/Merchant Center.
5. Unverified assumptions (CJ transit windows 8-18 / 3-8 / 3-9 business days, tariffs/de minimis, taxes, fonts, taxonomy) are in `docs/07-what-i-could-not-verify.md`.

## Plan for importing products "slowly"
Once CJ data is available: shortlist 3-4 products per batch starting with heatless-hair, then hair-tools, makeup-brushes, vanity-organizers, face-skin-tools, nails-lashes. For each: title (<=70 chars), description from the docs/02 template, SEO title/description, alt text, metafields (benefits, how_to_use, whats_included, specs, shipping_origin), price from `tools/pricing.py` with REAL CJ cost + shipping, collection, status DRAFT. User reviews before anything is published. Avoid health claims, brand look-alikes, uncertified electrical items.

## Starter prompt (paste into Claude Code)
> Read `lumette-store/HANDOFF.md` and `lumette-store/docs/07-what-i-could-not-verify.md`. Continue the Lumette Shopify store setup. First, check whether `www.cjdropshipping.com` is reachable; if not, work from listing data I paste. Use the Shopify MCP connector (store qjmgy1-jt.myshopify.com) to create products as DRAFT in small batches, starting with the heatless-hair collection. Do not publish anything or change the live theme without asking. Report anything you cannot verify.

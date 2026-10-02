# Lumette: Shopify beauty-tools store (Online Store 2.0)

A complete, launch-oriented kit for a niche beauty-tools dropshipping store (CJdropshipping, US + Canada, English + French).
"Lumette" is the working brand name; change it in Theme settings > Brand.

| Path | What it is |
|---|---|
| `dist/lumette-theme.zip` | **Upload this** (Online Store > Themes > Add theme > Upload zip) |
| `theme/` | Source of the theme (Liquid, JSON templates, sections editable in the theme editor, EN + FR locales) |
| `docs/01-brand-identity.md` | 5 name options, palette, typography, wordmark, tone of voice |
| `docs/02-catalog.md` | 6 collections, 18 product slots, pricing formula, description template, image guidance, metafields |
| `docs/03-seo-and-ads.md` | SEO, schema, Merchant Center feed, GA4/Ads hooks, campaign plan |
| `docs/04-setup-checklist.md` | Step-by-step: Shopify settings, payments, shipping, taxes, CJ app, import, domain, Merchant Center, test orders, launch |
| `docs/05-content-plan-30-days.md` | 30-day organic plan with 10 short-video ideas |
| `docs/06-email-capture-and-welcome-flow.md` | Popup behaviour, welcome discount flow, email copy EN/FR |
| `docs/07-what-i-could-not-verify.md` | **Read this.** Known gaps and assumptions |
| `copy/en/`, `copy/fr/` | Page and policy copy (About, Contact, Track, FAQ, Shipping, Returns, Privacy, Terms) and FR theme content |
| `catalog/catalog.csv`, `catalog_priced.csv` | Product slots and computed prices (illustrative costs) |
| `tools/pricing.py` | CJ cost + shipping -> price at target margin (USD and CAD) |
| `tools/merchant_feed.py` | Shopify product export -> Merchant Center feed + validation |
| `tools/contrast_check.py` | WCAG contrast check for the palette |
| `tools/build_zip.sh` | Rebuilds `dist/lumette-theme.zip` |
| `tracking/custom-pixel.js` | GA4 + Google Ads purchase tracking as a Shopify Custom Pixel (optional) |

## Theme contents
Home (hero, category chips, brand-promise bar, featured collections, best sellers, brand story, reviews slot, email signup) · Collection (filters via Search & Discovery, sorting, pagination) · Product (gallery, variants, benefit bullets from metafields, delivery estimate by shipping origin, accordions, FAQ, related products, sticky mobile add-to-cart, app blocks for reviews) · Slide-out cart with free-shipping progress bar (USD and CAD thresholds) · Cart page · About, Contact, Track Your Order, FAQ, policy pages · Search, 404, blog · Email popup · Country/language selector · Product/Organization/Breadcrumb schema, meta tags, optional GA4/Ads hooks.

## Merge fields
Replace `{{BRAND}}`, `{{LEGAL_NAME}}`, `{{BUSINESS_ADDRESS}}`, `{{SUPPORT_EMAIL}}`, `{{RETURN_ADDRESS}}`, `{{EFFECTIVE_DATE}}`, `{{JURISDICTION}}` in the copy before publishing.

## Quick start
1. Follow `docs/04-setup-checklist.md` from Phase 0.
2. Rebuild the zip after editing the theme: `./tools/build_zip.sh`.
3. Check the theme: `npm i @shopify/theme-check-node` then run its `themeCheckRun` on `theme/` (or `shopify theme check` with the Shopify CLI).

Not legal, tax or accounting advice. See `docs/07`.

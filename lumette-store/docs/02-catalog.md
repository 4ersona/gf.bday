# 2. Catalog structure

## Collections (6 categories + 1 merchandising collection)
| Handle | Title | Contains | Notes |
|---|---|---|---|
| `heatless-hair` | Heatless Hair | Heatless curling ribbons, flexi rods, bonnets, scrunchies | Strongest content category on TikTok/Reels |
| `hair-tools` | Hair Tools & Accessories | Scalp massager, detangling brush, claw clips, towel wrap | |
| `makeup-brushes` | Makeup Brushes & Sponges | Brush sets, sponges, cleaning mat | |
| `vanity-organizers` | Vanity & Organizers | LED mirror, rotating/acrylic organizers, travel bag | Electrical and bulky: see compliance flags |
| `face-skin-tools` | Face & Skin Tools | Gua sha, cooling roller | Tools only; no skincare claims |
| `nails-lashes` | Nails & Lashes | Lash curler (add nail art brushes, cuticle tools later) | Room to grow |
| `best-sellers` | Best Sellers *(not a category)* | Automated: sorted by "Best selling" | Powers the homepage grid. Create as a *manual* collection until you have sales, then switch to automated/sorted. Never label something "best seller" it isn't. |

Create all collections under Products > Collections with exactly these handles, since the homepage template points to them. Menu structure: **Main menu** = Shop (dropdown of the six), Best Sellers, About, FAQ, Track Your Order. **Footer** = the six collections. **Footer help** = FAQ, Shipping Policy, Returns and Refunds, Track Your Order, Contact, Privacy, Terms.

## Starter products (18 slots)
Full detail, including cost columns, is in `catalog/catalog.csv`; computed prices in `catalog/catalog_priced.csv`. **Every cost in that file is an illustrative estimate, not a quote from CJ.** Replace with real CJ cost and shipping for the exact variant and warehouse before pricing.

| # | Product | Collection | US price* | CA price* |
|---|---|---|---|---|
| 01 | Heatless Curling Ribbon Set | heatless-hair | $17.95 | $26.95 |
| 02 | Flexi Foam Curler Rods (12 pack) | heatless-hair | $16.95 | $26.95 |
| 03 | Satin Sleep Bonnet | heatless-hair | $17.95 | $25.95 |
| 04 | Satin Scrunchie Set (6 pack) | heatless-hair | $15.95 | $24.95 |
| 05 | Shampoo Scalp Massager Brush | hair-tools | $16.95 | $26.95 |
| 06 | Wet and Dry Detangling Brush | hair-tools | $16.95 | $26.95 |
| 07 | Matte Claw Clip Set (4 pack) | hair-tools | $15.95 | $24.95 |
| 08 | Microfiber Hair Towel Wrap | hair-tools | $15.95 | $25.95 |
| 09 | 12-Piece Makeup Brush Set | makeup-brushes | $24.95 | $36.95 |
| 10 | Beauty Sponge Blender Set (5 pack) | makeup-brushes | $16.95 | $27.95 |
| 11 | Silicone Brush Cleaning Mat | makeup-brushes | $16.95 | $26.95 |
| 12 | LED Makeup Mirror with Dimmable Light | vanity-organizers | $34.95 | $52.95 |
| 13 | 360 Rotating Makeup Organizer | vanity-organizers | $33.95 | $50.95 |
| 14 | Stackable Acrylic Drawer Organizer | vanity-organizers | $27.95 | $42.95 |
| 15 | Waterproof Travel Makeup Bag | vanity-organizers | $20.95 | $31.95 |
| 16 | Gua Sha Facial Massage Tool | face-skin-tools | $20.95 | $32.95 |
| 17 | Cooling Face Roller | face-skin-tools | $19.95 | $30.95 |
| 18 | Eyelash Curler Set with Refill Pads | nails-lashes | $17.95 | $27.95 |

\*Computed from placeholder costs at a 55-65% margin before ads and a placeholder FX rate of 1.37. **These numbers are a ceiling to test against the market, not a recommendation.** Several are above what comparable items sell for; compare 5 competitor listings per product and drop or bundle anything you can't sell at the formula price.

## Pricing formula
```
landed_cost = CJ product cost + CJ shipping to the customer's country (for the chosen line) + packaging/extra
price       = (landed_cost + 0.30) / (1 - 0.029 - target_margin)      -> round UP to the next x.95
```
- `0.029` and `0.30` are the card fee percentage and fixed fee. **Check the rate on your Shopify plan and payment provider** (they differ by plan and country).
- `target_margin` is margin **before ad spend**. Organic-first: 55-65% is realistic. When Google Ads starts, an ad allowance of 20-30% of price must come out of that, so a product needs >= 50% before ads to be advertisable.
- CAD is computed separately with costs converted at an FX rate you provide, not a blind conversion of the USD price. Re-check monthly.
- Free-shipping orders: shipping to the customer is free above $50 USD / $65 CAD, but **you still pay CJ's shipping per item**. The margin formula above already includes shipping in the landed cost, so the threshold doesn't break margin as long as the order includes 2+ items. Under the threshold, charge a flat rate (suggested $4.95 USD / $6.95 CAD) that covers about one item's shipping.
- Run: `python3 tools/pricing.py catalog/catalog.csv catalog/catalog_priced.csv --fx <today's rate>`; one-off: `python3 tools/pricing.py --cost 3.2 --ship 3.5 --margin 0.55`.
- Never show a fake "was" price. Use a real, time-limited promotion in Shopify discounts if you want to run a sale.
- Charm endings (.95) are applied to every price for consistency.

## Product page template (what each product needs)
**Title (<= 70 chars, keywords first):** `[Product type/benefit noun] [distinguishing feature] ([count/size])` e.g. "Satin Sleep Bonnet, Adjustable" / "12-Piece Makeup Brush Set with Pouch". No brand-name knock-off terms, no ALL CAPS, no promo text ("free shipping", "sale").

**Description template (HTML, ~120-200 words):**
```
<p>[One sentence: what it is, who it's for, the main use.]</p>
<p>[Two sentences: how it fits into a routine, what makes it comfortable/easy. Specific and checkable.]</p>
<ul>
  <li>[Material / size / quantity]</li>
  <li>[Included items]</li>
  <li>[Care: how to clean/store]</li>
</ul>
<p>[One honest sentence on delivery origin if it matters, e.g. "Ships from our partner's warehouse; delivery window shown above."]</p>
```
Store the rest in metafields (they render as separate theme blocks): `custom.benefits` (3 bullets), `custom.how_to_use`, `custom.whats_included`, `custom.specs`, `custom.short_description` (one line under the title), `custom.shipping_origin` (`cn`/`us`/`ca`).

**Metafield definitions** (Settings > Custom data > Products > Add definition; namespace and key exactly as below):
| Name | Namespace.key | Type |
|---|---|---|
| Benefits | `custom.benefits` | List of single line text |
| Short description | `custom.short_description` | Single line text |
| How to use | `custom.how_to_use` | Multi-line text (or rich text) |
| What's included | `custom.whats_included` | Multi-line text |
| Specifications | `custom.specs` | Multi-line text |
| Shipping origin | `custom.shipping_origin` | Single line text, limit to `cn`, `us`, `ca` |

**Image guidance**
- Minimum 1600x1600 px (square 1:1 serves Merchant Center and the theme grid). 5-8 images per product.
- Order: (1) clean hero on neutral background, product fills ~75% of frame; (2) in use; (3) detail/texture; (4) what's in the box; (5) size reference next to a hand or ruler; (6) colour/size options; (7) packaging if it's a gift candidate.
- CJ supplier images are often watermarked, low-res, or reused by dozens of stores. Request samples for your 3-5 hero products and shoot your own (phone, daylight, white/cream backdrop). Google can disapprove images with watermarks, promo text or logos overlays.
- **Alt text pattern:** `[Product] [colour/variant], [what is shown]` -> "Satin sleep bonnet in blush, worn from the side". Describe, don't keyword-stuff, max ~125 chars. Set in Admin > Products > media > Edit alt text. The theme falls back to the product title if alt text is empty. Decorative duplicate images (hover image) are rendered with empty alt on purpose.
- Video: a 10-20 second vertical clip per hero product doubles as organic content.

## Compliance flags for the starter list
- **Electrical/battery items** (LED mirror): require FCC (US) and ISED/CSA-style marking (Canada) and battery transport certification (UN38.3). Ask CJ for documents *before* listing. If they can't produce them, drop the SKU.
- **Skin-contact items** (brushes, sponges, rollers, lash tools): use materials claims only if the supplier confirms them in writing ("latex-free", "vegan", "cruelty-free" in particular).
- **Fabric items**: don't write "silk" unless it is silk; the FTC and Canada's Textile Labelling Act care about fibre content.
- **No health claims**: gua sha/rollers must not claim to reduce wrinkles, puffiness, inflammation or to "detox" (FDA / Health Canada treat those as therapeutic claims; Google Ads also restricts them).
- **No look-alike brands**: avoid products that copy a branded design (hair tools especially). CJ listings sometimes do.
- **Re-check dimensional weight** for organizers; they can wreck shipping margins.

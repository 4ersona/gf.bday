# 1. Brand identity

## Brand name: five options
I can't check domain or trademark availability from here, so treat all five as **candidates to verify**: search the exact `.com` (and `.ca`) at a registrar, then search USPTO (US) and CIPO (Canada) trademark databases, then search the name in TikTok/Instagram. Names are chosen to read naturally in English *and* French (the store is bilingual).

| # | Name | Why it works | Domain to check | Risk |
|---|---|---|---|---|
| 1 | **Lumette** *(default used in the theme)* | "Lumière" + a diminutive: small light, glow. Easy to say in both languages. | lumette.com, lumette.ca | Common-sounding; likely taken somewhere. Check trademark classes 35 and 3/21. |
| 2 | **Belloré** | "Belle" + "doré": pretty, golden. Feels like a salon brand. | belloré -> use bellore.com | Accent drops in the domain. |
| 3 | **Ondine** | Evokes waves, fits a hair-led catalogue (heatless curls). | ondinebeauty.com, shopondine.com | Many existing uses; plain `.com` is probably gone. |
| 4 | **Nacrée** | Mother-of-pearl; shimmer. Elegant, distinctive. | nacree.com, nacreebeauty.com | Hard to spell in English; accent. |
| 5 | **Doucette** | "Gentle/sweet" in French; friendly and soft. | doucettebeauty.com | Also a surname; Canadian market sees it as very Quebecois. |

**How to rename:** change Theme settings > Brand > Brand name. The wordmark, SEO titles, footer, emails and popup all read it. Search the copy files for `{{BRAND}}`.

## 3-second test
A first-time visitor sees, above the fold on mobile: the announcement bar (free-shipping message), the wordmark, the eyebrow "Beauty tools & accessories", the headline "Beauty tools that make your routine easier.", the sub-line naming the products (heatless curlers, brush sets, LED mirrors, gua sha, organizers), and directly beneath, six category chips. Product nouns appear in the first screen, so the category is clear without scrolling.

## Palette (all pairs tested)
Warm neutrals + one deep rose accent, with sage for success/free-shipping. Contrast verified with `tools/contrast_check.py` (WCAG 2.1; every text pair >= 4.5:1).

| Token | Hex | Use |
|---|---|---|
| Cream `--color-bg` | `#FBF7F2` | Page background |
| Sand `--color-surface` | `#F4E9E1` | Panels, image placeholders |
| Blush `--color-blush` | `#F2D9D2` | Hero, newsletter, highlights |
| Ink `--color-ink` | `#2A2220` | Body text, footer, announcement bar (14.6:1 on cream) |
| Ink soft `--color-ink-soft` | `#5B4D47` | Secondary text (7.6:1) |
| Rose `--color-accent` | `#8F3A4B` | Buttons, links, focus ring (white text on it: 7.3:1) |
| Rose dark `--color-accent-hover` | `#742E3C` | Hover state (9.6:1) |
| Sage `--color-sage` | `#3F5C4D` | Free-shipping progress, check marks (7.4:1 with white) |
| Line `--color-line` | `#E6D8CE` | Decorative borders only |

All colours are theme settings (Customize > Theme settings > Colors). Re-run `python3 tools/contrast_check.py` after changing any.

## Typography
- **Headings:** Playfair Display (elegant high-contrast serif; reads "beauty" without feeling cold).
- **Body:** Assistant (clean, highly legible sans; ships with Shopify's font library).
- Both are chosen through Shopify's `font_picker`, so they load from Shopify's font CDN with `font-display: swap`. If Playfair isn't offered in your admin font list, pick another serif there (e.g. a "Cormorant" or "Lora" family).
- Scale: body 16px (15-18 adjustable), H1 clamp 2-3.5rem, H2 1.6-2.4rem.

## Wordmark
Text wordmark: "Lumette" set in the heading font, with a four-point sparkle after the final letter in rose. It is rendered live by `snippets/logo.liquid` (no image to load, always crisp). `theme/assets/logo-wordmark.svg` is the same mark as a standalone file for social profile images; **convert the text to outlines in a vector editor before using it anywhere the font may be missing**. Upload a final PNG/SVG logo in Theme settings > Brand > Logo image to replace the text version.

Social avatar: a rose circle (`#8F3A4B`) with a cream "L" in the heading font. Favicon: the sparkle alone, rose on cream, 512x512 PNG.

## Tone of voice
**Warm, plain and specific. A knowledgeable friend, not a hype machine.**

| Do | Don't |
|---|---|
| "Wrap it before bed, take it out in the morning." | "Revolutionary overnight transformation!" |
| "Soft synthetic bristles. 12 brushes and a pouch." | "The best brush set on the planet." |
| "Arrives in about 8-18 business days. Here's why." | "Fast shipping!" (when it isn't) |
| "A facial massage tool." | "Lifts, tightens and detoxes." |
| "Most customers..." only if you have real data | Any invented statistic, rating or testimonial |

Voice rules: second person ("you"), short sentences, name the thing (not "solution"), always say what's in the box, state delivery honestly, no medical or anti-aging claims, no exclamation marks except in confirmations. In French: use "vous", Canadian vocabulary (courriel, magasiner, infolettre), avoid anglicisms where a common French word exists.

## Honesty rules baked into the theme
- No fake reviews: the Reviews section renders **only** a reviews-app block. With no app connected, shoppers see nothing.
- No fake countdown timers, stock counters, "X people are viewing" or "as seen in" logos: none exist in the theme.
- Compare-at ("was") prices show only if you set a real one in Shopify; the theme never invents one.
- Delivery estimate ranges come from settings you control and are labelled as estimates.

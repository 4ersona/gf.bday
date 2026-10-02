# 4. Setup checklist (step by step)

Tick in order; later steps depend on earlier ones. Estimated 2-4 focused days, plus waiting time for payment verification, domain DNS and Merchant Center review.

## Phase 0: Decisions and accounts
- [ ] Choose the brand name (docs/01) and check domain + trademark availability.
- [ ] Decide the legal entity (sole proprietorship/LLC/corp), get a business email (`support@yourdomain`) and a mailing address that is *not* your home if you can (virtual mailbox/PO-compliant address; Shopify and CAN-SPAM/CASL require a physical address in emails).
- [ ] Open: Shopify account, CJdropshipping account, Google account for the business (Analytics, Search Console, Merchant Center, Ads), TikTok/Instagram/Pinterest business accounts (claim the handle early).
- [ ] Decide Shopify plan. Start on Basic; start the free trial only once you're ready to build (the trial clock runs).

## Phase 1: Shopify core settings (Settings menu)
- [ ] **Store details:** store name, business email, legal business name and address, currency = **USD** (store currency), time zone, units (imperial for US; metric/imperial as you prefer), default weight unit.
- [ ] **Plan > Pause/Password:** keep the storefront password *on* while building.
- [ ] **Languages:** add **French** (English default). Install Translate & Adapt (free).
- [ ] **Markets:** Primary market = United States (USD). Add **Canada** (CAD, English + French). Turn on automatic currency conversion with price rounding, or set fixed CAD prices from `catalog_priced.csv` via "Prices" overrides on the Canada market. Check duties/import tax settings per market.
- [ ] **Checkout:** customer accounts = *new customer accounts* (the theme has no classic account templates; Shopify hosts them), contact method = email, enable "Require first and last name", phone optional. **Marketing consent checkbox: show it, leave it UNCHECKED** by default (CASL requires opt-in; don't pre-tick).
- [ ] **Customer privacy:** enable Shopify's cookie banner for the regions you target (analytics and marketing consent). Needed for the theme's consent-mode hooks.
- [ ] **Policies:** paste the legal text from `copy/en/*.html` (Refund policy, Privacy policy, Terms of service, Shipping policy, optional Contact information). Fill `{{...}}` placeholders. Have a lawyer review. Add French versions via Translate & Adapt using `copy/fr`.
- [ ] **Notifications:** customize order confirmation, shipping confirmation, shipping update, abandoned checkout. Add your support email and make sure the shipping confirmation includes tracking and a link to Track your order. Send yourself a test.
- [ ] **Brand:** logo, colours, favicon (Settings > Brand), also used by checkout. Checkout branding (Customize checkout) with the palette in docs/01.

## Phase 2: Payments
- [ ] **Shopify Payments** (available for US and Canada merchants): complete identity and bank verification (can take days). Currencies payout: set USD and CAD bank accounts if you want to avoid conversion fees. Verify the card rate on your plan (docs/02 assumes 2.9% + $0.30).
- [ ] Enable wallets: Shop Pay, Apple Pay, Google Pay (appear automatically with Shopify Payments).
- [ ] **PayPal** as an additional method (important for conversion; note PayPal holds on new accounts).
- [ ] Fraud: enable fraud analysis; for orders flagged high risk, **do not** auto-fulfil in the CJ app until reviewed.
- [ ] Do NOT use bogus-gateway tests on a live store without Shopify test mode (see Phase 9).

## Phase 3: Shipping, taxes and duties
**Shipping and delivery**
- [ ] Remove the default "General" rates you don't want. Create zones **United States** and **Canada** (keep other countries off).
- [ ] Rates for each zone (these must match Theme settings > Shipping & delivery messaging):
  - Free shipping when order price >= **$50 USD** / **$65 CAD**.
  - Flat rate below: suggested **$4.95 USD** / **$6.95 CAD**. Adjust after you see CJ's real per-order costs.
- [ ] Optional: shipping profiles per origin if you want different rates for US/CA-warehouse items.
- [ ] Processing time, per policy: 1-3 business days. Delivery windows come from the theme settings (defaults: China 8-18 business days, US warehouse 3-8, Canada warehouse 3-9). **Re-set these from CJ's shipping calculator for each line you actually use, and from your own test orders.** See docs/07 for why these are unverified.
- [ ] Packing slip: remove prices or use branded one only if CJ can brand. (CJ packaging is typically CJ-branded unless you pay for custom packaging.)

**Taxes and duties**
- [ ] **US:** economic nexus rules differ by state (commonly $100k revenue or 200 transactions, varies). Register for sales tax only where required; turn on collecting in Settings > Taxes and duties for states where you register. Prices are tax-exclusive. Shopify can calculate rates but **you** file and remit.
- [ ] **Canada:** register for GST/HST once you exceed the small-supplier threshold (CAD $30,000 in four consecutive quarters) or earlier voluntarily; PST/QST rules differ by province (Quebec QST registration is separate). Enter your registrations so Shopify collects the right taxes. Consult an accountant.
- [ ] **Duties/import taxes:** ask CJ which shipping lines are DDP (duties pre-paid) vs DDU for US/Canada, and what rules apply today (see docs/07: tariff and de minimis rules have changed repeatedly). Align the Shipping policy text and checkout "duties and import taxes" setting to what is true.
- [ ] Decide your **business registration** and file income tax (accountant).

## Phase 4: CJdropshipping app and products
- [ ] Shopify admin > Apps > Shopify App Store > install **CJdropshipping**. Authorize the connection; log in with your CJ account.
- [ ] In CJ: add a payment method / funds. Check whether orders auto-pay or sit as "awaiting payment" (**verify this setting; unpaid orders do not ship**). Turn on automatic order sync and tracking-number sync back to Shopify.
- [ ] **Select suppliers' products** using the keywords in `catalog/catalog.csv`. For each candidate: check the CJ **shipping calculator to the US and Canada** (warehouse, method, days, cost), ratings/sales, stock, variant list, product weight/size, and whether the supplier has certifications for electrical items.
- [ ] **Order samples** of your 3-5 hero products and measure real transit time and quality. This is the only reliable way to get honest delivery windows and images.
- [ ] Add chosen products to your CJ list, **Push to Shopify**. Then in Shopify, for each product: rewrite title and description using docs/02 template; replace images; set price using `tools/pricing.py`; set collection; fill metafields (`custom.benefits`, `custom.shipping_origin`, etc.); set SKU on each variant; set weight; leave inventory *not tracked* or track via CJ sync.
- [ ] Remove supplier-branded text, logos or watermarks from images; remove any claims you can't support.
- [ ] Create the **collections** with exact handles from docs/02 and the **Best sellers** collection.

## Phase 5: Install and configure the theme
- [ ] Online Store > Themes > **Add theme > Upload zip file** > `dist/lumette-theme.zip`. Don't publish yet. Preview it.
- [ ] Customize > Theme settings: Brand (name, logo), Colors (keep defaults), Typography, **Shipping & delivery messaging** (thresholds and windows), Email popup copy, Social links, Tracking (leave off unless using Option B in docs/03).
- [ ] **Navigation:** create menus `main-menu` (Shop with the six collections as sub-items, Best Sellers, About, FAQ, Track Your Order) and `footer`, `footer-help` (docs/02).
- [ ] **Pages:** create About, Contact, Track your order, FAQ, Shipping Policy, Returns and Refunds, Privacy Policy, Terms of Service. Set templates: About -> `page.about`, Contact -> `page.contact`, Track your order -> `page.track-order`, FAQ -> `page.faq`; policies use default `page`. Paste copy from `copy/en/*.html` (HTML view).
- [ ] **Metafield definitions:** Settings > Custom data > Products, create the six listed in docs/02.
- [ ] Home page: the template points to collections by handle; confirm each chip/tile shows once collections exist. Upload a hero photo and brand story image when ready.
- [ ] **Search & Discovery app** (free): enable filters (Availability, Price, Product type, and any product options such as Color) for the collections; the theme reads whatever filters you configure.
- [ ] **Reviews app:** install one that supports *verified purchase* reviews (and photo requests), set it to publish only reviews from real orders, add its block into the **Customer reviews** section on the product template and rating stars block on the product section. The theme shows nothing until you do.
- [ ] **Translate & Adapt:** translate theme content using `copy/fr/theme-content-fr.md`, translate product titles/descriptions, collections, menus and pages. Check the FR storefront with `?country=CA` and the language selector in the footer.
- [ ] Add a 404/search test and a gift card test if you sell gift cards.

## Phase 6: Domain and email
- [ ] Settings > Domains: buy through Shopify or connect an existing domain (update A record to Shopify's IP and CNAME `www` per the screen). Wait for SSL to activate. Set the primary domain; redirect others to it.
- [ ] Email deliverability: for marketing email from your domain add the SPF/DKIM records your sender (Shopify Email or Klaviyo) tells you.
- [ ] Create `support@` mailbox (Google Workspace, Zoho, or Shopify Email forwarding).

## Phase 7: Email capture and welcome flow
- [ ] Follow docs/06: create discount `WELCOME10`, welcome automation (Shopify Email or Klaviyo) and abandoned checkout email.
- [ ] Submit the popup once on the live store; confirm the customer appears in Customers with "Subscribed" status and tags `newsletter, popup, welcome-offer`, and that the welcome email arrives with the code.

## Phase 8: Search Console, GA4, Merchant Center, Ads
- [ ] **Search Console:** add the domain property (DNS verification), submit `https://yourdomain.com/sitemap.xml`.
- [ ] **GA4:** create property + web data stream. Use Option A (Google & YouTube app) or B (docs/03). Verify events in DebugView.
- [ ] **Google & YouTube app:** connect Google account, Merchant Center, Google Ads (optional until ready), enable the free listings.
- [ ] **Merchant Center:** business info, verify/claim domain, **shipping** (US and Canada, handling 1-3 days, transit realistic for each line), **returns** (30 days, customer pays change-of-mind), tax, contact. Run `tools/merchant_feed.py` on a catalog export before first sync, fix errors, and clear the Diagnostics tab.
- [ ] **Google Ads:** don't launch yet. Link accounts, create conversions (docs/03). Wait for organic traction.

## Phase 9: Test orders (do all of these before launch)
- [ ] **Checkout test (no real money):** Settings > Payments > Shopify Payments > *Test mode* on. Place orders with Shopify's test cards (e.g. 4242 4242 4242 4242, any future expiry, any CVC; confirm current details on Shopify's help page). Test: US address and Canada address, USD and CAD, free-shipping threshold (the cart progress bar should reach 100% exactly when checkout shows free shipping), a discount code (WELCOME10), a coupon over a threshold, a sold-out variant, a French checkout. Turn test mode **off** afterward.
- [ ] **Real CJ order:** place one real order for a cheap item to your own address. Confirm: it appears in the CJ app, CJ requests/accepts payment, order status flows, tracking number returns to Shopify and triggers the shipping email, actual delivery time vs. the window on the product page.
- [ ] Refund test: refund the test order; check email and fulfilment cancellation behaviour.
- [ ] **Mobile QA** (real iPhone + Android): hero loads fast, chips scroll, product gallery swipes, variant pills, sticky add-to-cart appears after scrolling past the main button, cart drawer opens, focus doesn't get trapped, checkout loads.
- [ ] **Accessibility QA:** tab through home, product, cart and popup with the keyboard only; run axe or Lighthouse accessibility; check zoom to 200%; screen reader label of the cart button and quantity steppers. Esc closes the popup, cart and menu.
- [ ] **Performance QA:** Lighthouse mobile on home and a product page after real images are uploaded. Compress images (<= 300KB each where possible).
- [ ] Verify structured data with Google's Rich Results Test on one product.
- [ ] Proofread every page; check all `{{...}}` placeholders are gone (search the theme editor and pages).

## Phase 10: Launch
- [ ] Remove storefront password. Publish the theme.
- [ ] Switch Shopify Payments out of test mode; confirm payouts bank.
- [ ] Post the first videos (docs/05), link to your store in bios (use the product link, not just the home page).
- [ ] Submit sitemap again; check Merchant Center diagnostics after 48-72 hours.
- [ ] Calendar reminders: re-check CJ delivery times and prices monthly; review the cart/checkout drop-off weekly for the first month.

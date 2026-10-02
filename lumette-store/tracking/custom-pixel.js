/*
 * Lumette - GA4 + Google Ads purchase tracking as a Shopify Custom Pixel.
 * Install: Shopify admin > Settings > Customer events > Add custom pixel > paste this file.
 * Replace the three constants below, save, then CONNECT the pixel.
 *
 * Use this ONLY if you are not using the Google & YouTube app (which tracks purchases itself).
 * Running both double-counts revenue.
 *
 * Known limitation: custom pixels run in a sandbox, so GA4 may not be able to stitch the
 * checkout session to the storefront session (purchases can show as "direct"). The
 * Google & YouTube app handles this better. Test in GA4 DebugView before trusting it.
 */
const GA4_ID = 'G-XXXXXXXXXX';            // GA4 measurement ID
const ADS_ID = 'AW-XXXXXXXXX';            // Google Ads conversion ID
const ADS_PURCHASE_LABEL = 'XXXXXXXXXXXX'; // Google Ads purchase conversion label

// Load gtag inside the sandbox.
const s = document.createElement('script');
s.async = true;
s.src = 'https://www.googletagmanager.com/gtag/js?id=' + GA4_ID;
document.head.appendChild(s);
window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }
gtag('consent', 'default', { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'denied' });
gtag('js', new Date());
gtag('config', GA4_ID, { send_page_view: false });
gtag('config', ADS_ID);

// Respect the visitor's consent choices as provided by Shopify's Customer Privacy API.
function applyConsent(c) {
  const a = c && c.analyticsProcessingAllowed ? 'granted' : 'denied';
  const m = c && c.marketingAllowed ? 'granted' : 'denied';
  gtag('consent', 'update', { analytics_storage: a, ad_storage: m, ad_user_data: m, ad_personalization: m });
}
init.customerPrivacy && applyConsent(init.customerPrivacy);
api.customerPrivacy.subscribe('visitorConsentCollected', (e) => applyConsent(e.customerPrivacy));

analytics.subscribe('checkout_started', (event) => {
  const c = event.data.checkout;
  gtag('event', 'begin_checkout', {
    currency: c.currencyCode, value: Number(c.subtotalPrice && c.subtotalPrice.amount || 0),
    items: c.lineItems.map((li) => ({ item_id: li.variant.sku || li.variant.id, item_name: li.title, quantity: li.quantity, price: Number(li.variant.price.amount) })),
  });
});

analytics.subscribe('checkout_completed', (event) => {
  const c = event.data.checkout;
  const txn = (c.order && c.order.id) || c.token;
  const value = Number(c.totalPrice.amount);
  const items = c.lineItems.map((li) => ({ item_id: li.variant.sku || li.variant.id, item_name: li.title, quantity: li.quantity, price: Number(li.variant.price.amount) }));
  gtag('event', 'purchase', {
    transaction_id: txn, currency: c.currencyCode, value: value,
    tax: Number(c.totalTax && c.totalTax.amount || 0), shipping: Number(c.shippingLine && c.shippingLine.price.amount || 0), items: items,
  });
  gtag('event', 'conversion', { send_to: ADS_ID + '/' + ADS_PURCHASE_LABEL, value: value, currency: c.currencyCode, transaction_id: txn });
});

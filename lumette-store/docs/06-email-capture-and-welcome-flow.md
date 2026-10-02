# 6. Email capture popup and welcome discount flow

## How the popup behaves (`sections/email-popup.liquid`, settings in Theme settings > Email popup)
- Appears once, after a delay (default 12 s), never on cart/checkout/account pages, and not while the cart drawer is open.
- Dismiss with the close button, Esc key or clicking outside. Dismissal is remembered for 14 days (setting) in the browser; a successful sign-up for 90 days.
- Keyboard accessible: focus moves into the dialog, is trapped inside it, and returns where it was when closed.
- Posts to Shopify's customer form with tags `newsletter, popup, welcome-offer`, creating a customer who accepts email marketing.
- No countdown timers, no "only 3 left", no pre-ticked boxes. The consent sentence is shown under the button.
- Fires GA4 `generate_lead` if Option B tracking is on.
- Turn off: Theme settings > Email popup > uncheck *Enable email popup*.

## The offer: 10% off first order
Honest mechanics (don't show the code on the page; send it by email so the sign-up is real):
1. **Create the discount:** Discounts > Create > Discount code `WELCOME10`. 10% off entire order. Customer eligibility: all customers. **Limit to one use per customer.** Combinations: not with other discounts. Set a real end date only if you'll honour it (e.g. valid 14 days after sign-up if you generate unique codes; otherwise no end date).
2. **Welcome automation:** use **Shopify Email** (Marketing > Automations > "Welcome new subscribers") or Klaviyo. Trigger: customer subscribes to email marketing. Email 1 includes the code (below). (Shopify Email may let you generate a unique code per subscriber; verify in your admin: unique codes reduce code leakage on coupon sites.)
3. **Sequence:** E1 immediately, E2 on day 2, E3 on day 5.
4. **CASL/CAN-SPAM:** every email needs your name, physical address and a working unsubscribe link. Consent text is in the popup. For extra protection with Canadian subscribers use *double opt-in* (confirmation email) if your email tool supports it. Keep a record of when and how consent was obtained.
5. **Abandoned checkout email:** Settings > Notifications > Customer notifications > Abandoned checkout, or an Automation. Send the first email after 1-4 hours, a second at 24 h. Don't add the welcome code to it automatically unless you intend to give everyone the discount.

## Email 1: Welcome + code (send immediately)
**Subject EN:** Your welcome code is inside
**Preheader:** 10% off your first order, plus how delivery works.

> Hi,
>
> Thanks for joining {{BRAND}}. Here's your welcome code:
>
> **WELCOME10**: 10% off your first order. One use per customer, can't be combined with other discounts.
>
> **[Shop the tools]**
>
> Before you order, two honest notes:
> - Most items ship from our fulfilment partner's warehouse and arrive in about 8-18 business days. Every product page shows the estimated window for that item.
> - If something's not right, tell us within 30 days of delivery and we'll fix it.
>
> New here? Start with our best sellers.
>
> {{BRAND}} · {{BUSINESS_ADDRESS}}
> You're receiving this because you signed up at {{BRAND}}. [Unsubscribe]

**Objet FR :** Votre code de bienvenue est à l'intérieur
**Texte d'aperçu :** 10 % de rabais sur votre première commande, et comment fonctionne la livraison.

> Bonjour,
>
> Merci de joindre {{BRAND}}. Voici votre code de bienvenue :
>
> **WELCOME10** : 10 % de rabais sur votre première commande. Un seul usage par client; non cumulable avec d'autres rabais.
>
> **[Magasiner les outils]**
>
> Avant de commander, deux précisions :
> - La plupart des articles partent de l'entrepôt de notre partenaire logistique et arrivent en 8 à 18 jours ouvrables environ. Chaque fiche produit indique la fenêtre estimée pour l'article.
> - Si quelque chose ne va pas, dites-le-nous dans les 30 jours suivant la livraison et nous réglerons la situation.
>
> {{BRAND}} · {{BUSINESS_ADDRESS}}
> Vous recevez ce courriel parce que vous vous êtes inscrit chez {{BRAND}}. [Se désabonner]

## Email 2: Day 2, how to choose (education, no pressure)
**Subject EN:** Which tool fits your routine?
> Hi, quick guide: **Hair** (heatless curlers, bonnets, scrunchies), **Makeup** (brush sets, sponges, organizers), **Skin** (gua sha, cooling roller). Each product page lists what's in the box and how to use it. Questions? Reply to this email.
> [Shop by category] · Your code WELCOME10 is still waiting.

**Objet FR :** Quel outil convient à votre routine?
> Bonjour, un petit guide rapide : **Cheveux** (boucleurs sans chaleur, bonnets, chouchous), **Maquillage** (ensembles de pinceaux, éponges, rangements), **Peau** (gua sha, rouleau rafraîchissant). Chaque fiche produit indique le contenu de la boîte et le mode d'emploi. Des questions? Répondez à ce courriel.
> [Magasiner par catégorie] · Votre code WELCOME10 vous attend toujours.

## Email 3: Day 5, gentle reminder
Only state an expiry if you've actually configured one on the discount.
**Subject EN:** Still thinking it over?
> Your welcome code **WELCOME10** is still active{{ until [date] if you set an end date}}. Orders over $50 USD / $65 CAD ship free. [Back to the shop]

**Objet FR :** Vous hésitez encore?
> Votre code de bienvenue **WELCOME10** est toujours actif{{ jusqu'au [date] si vous avez fixé une date de fin}}. Livraison gratuite dès 50 $ US / 65 $ CA. [Retourner à la boutique]

## Abandoned checkout email (short version)
**Subject EN:** You left something in your cart
> Your cart is saved. [Return to checkout]. Delivery windows are shown at checkout; questions? Reply to this email and a person will answer.

**Objet FR :** Vous avez laissé des articles dans votre panier
> Votre panier est sauvegardé. [Retourner à la caisse]. Les délais de livraison sont affichés à la caisse; des questions? Répondez à ce courriel et une personne vous répondra.

## Measure
Popup conversion rate (target 2-4% of sessions, rule of thumb), welcome email open/click rate, share of first orders using WELCOME10, and whether discounted first-orders still clear break-even (10% off lowers margin: check `tools/pricing.py` margins before enabling).

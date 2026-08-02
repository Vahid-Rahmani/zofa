// zova · Stripe checkout edge function.
//
// Creates a Stripe subscription for the signed-in user and returns the
// PaymentIntent client secret + ephemeral key that the Flutter app needs to
// open the native payment sheet.
//
// Env vars (secrets):
//   STRIPE_SECRET_KEY       — live/test secret key (server only)
//   STRIPE_WEBHOOK_SECRET   — used by the webhook handler
//   STRIPE_PRICE_MONTHLY    — price id for the monthly plan
//   STRIPE_PRICE_YEARLY     — price id for the yearly plan
//
// Deploy:
//   supabase functions deploy stripe-checkout --no-verify-jwt
//   supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx
//   supabase secrets set STRIPE_PRICE_MONTHLY=price_xxx
//   supabase secrets set STRIPE_PRICE_YEARLY=price_yyy

import Stripe from 'npm:stripe@16.8.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2024-12-18.acacia',
});

const PRICES: Record<string, string | undefined> = {
  monthly: Deno.env.get('STRIPE_PRICE_MONTHLY'),
  yearly: Deno.env.get('STRIPE_PRICE_YEARLY'),
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = new URL(req.url);
  if (url.pathname.endsWith('/webhook')) return handleWebhook(req);

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.replace('Bearer ', '');
  const { data: user, error } = await supabaseClient().auth.getUser(jwt);
  if (error || !user.user) {
    return json({ error: 'Unauthorized' }, 401);
  }

  let planId: string;
  try {
    ({ plan_id: planId } = await req.json());
  } catch {
    return json({ error: 'Invalid body' }, 400);
  }

  const price = PRICES[planId];
  if (!price) return json({ error: 'Unknown plan' }, 400);

  const customer = await getOrCreateCustomer(user.user.id, user.user.email ?? '');
  const subscription = await stripe.subscriptions.create({
    customer: customer.id,
    items: [{ price }],
    payment_behavior: 'default_incomplete',
    payment_settings: { save_default_payment_method: 'on_subscription' },
    expand: ['latest_invoice.payment_intent'],
    metadata: { user_id: user.user.id },
  });

  const paymentIntent = subscription.latest_invoice?.payment_intent;
  if (typeof paymentIntent === 'string' || !paymentIntent?.client_secret) {
    return json({ error: 'Could not start payment' }, 500);
  }

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customer.id },
    { apiVersion: '2024-12-18.acacia' },
  );

  await supabaseClient()
    .from('subscriptions')
    .upsert({
      user_id: user.user.id,
      stripe_customer_id: customer.id,
      stripe_subscription_id: subscription.id,
      plan: planId,
      status: subscription.status,
    });

  return json({
    payment_intent: paymentIntent.client_secret,
    customer_id: customer.id,
    ephemeral_key: ephemeralKey.secret,
  });
});

async function getOrCreateCustomer(userId: string, email: string) {
  const { data } = await supabaseClient()
    .from('subscriptions')
    .select('stripe_customer_id')
    .eq('user_id', userId)
    .maybeSingle();

  if (data?.stripe_customer_id) {
    return stripe.customers.retrieve(data.stripe_customer_id as string);
  }
  return stripe.customers.create({ email, metadata: { user_id: userId } });
}

// Updates local subscription state when Stripe confirms a payment.
async function handleWebhook(req: Request) {
  const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
  const signature = req.headers.get('stripe-signature') ?? '';
  const body = await req.text();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, secret);
  } catch {
    return json({ error: 'Invalid signature' }, 400);
  }

  if (event.type === 'invoice.payment_succeeded' || event.type === 'customer.subscription.updated') {
    const subscription = event.data.object as Stripe.Subscription;
    await supabaseClient()
      .from('subscriptions')
      .update({
        status: subscription.status,
        current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
      })
      .eq('stripe_subscription_id', subscription.id);
  }

  return json({ received: true });
}

function supabaseClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } },
  );
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

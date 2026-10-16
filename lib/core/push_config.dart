/// Offentlig VAPID-nøkkel for demomodus.
/// Privatnøkkelen ligger i gitignorert `supabase/.vapid.env` og skal settes
/// som secret på Edge Function `send-push`, sammen med denne offentlige nøkkelen.
const demoVapidPublicKey =
    'BFwxPWQsAd9cWWrbL4RzHc5EtqwvyRmb29M6HSRwmAHsuiVd1qH-c6_QgSUHwW3VOfFv74pVxsRb8jX8MQtuT3Y';

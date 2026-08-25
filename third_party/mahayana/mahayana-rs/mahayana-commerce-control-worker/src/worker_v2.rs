@@PATCH@@
    let database = env.d1(DB)?;
    let candidates = worker::query!(&database,
        "SELECT p.developer_id,p.preferred_currency,p.payout_schedule,p.minimum_payout_amount,p.last_scheduled_payout_at,a.payout_account_id
         FROM developer_payout_profiles p
         JOIN developer_payout_accounts a ON a.developer_id=p.developer_id
         WHERE p.compliance_state='eligible' AND p.payout_schedule<>'manual'
           AND a.is_default=1 AND a.state='active' AND a.onboarding_state='verified'
           AND a.kyc_status='verified' AND a.payouts_enabled=1
           AND EXISTS (SELECT 1 FROM json_each(a.currencies_json) WHERE value=p.preferred_currency)
           AND EXISTS (SELECT 1 FROM json_each(a.purposes_json) WHERE value='marketplace_payout')
           AND EXISTS (
             SELECT 1 FROM payout_provider_routes r
             WHERE r.region_code=CASE WHEN p.country_code='CN' THEN 'CN' ELSE 'GLOBAL' END
               AND r.purpose='marketplace_payout' AND r.provider=a.provider AND r.state='active'
           )
         ORDER BY p.developer_id,a.is_default DESC,a.created_at ASC").all().await?.results::<AutoPayoutCandidate>()?;
@@ENDPATCH@@
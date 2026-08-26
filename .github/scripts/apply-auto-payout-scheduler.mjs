@@PATCH@@
-         ORDER BY p.developer_id,a.is_default DESC,a.created_at ASC")?.all().await?.results::<AutoPayoutCandidate>()?;
+         ORDER BY p.developer_id,a.is_default DESC,a.created_at ASC").all().await?.results::<AutoPayoutCandidate>()?;
@@ENDPATCH@@
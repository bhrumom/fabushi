@@PATCH@@
 include!("payout_orchestration.rs");
 include!("reconciled_refund.rs");
 include!("reserve_release.rs");
+include!("payout_finalize.rs");
@@
         "payoutPaid" => {
             let payout_id = required_event_value(event.payout_id.as_deref(), "payoutId")?;
-            worker::query!(
-                database,
-                "UPDATE developer_payouts SET status = 'paid', provider_reference = COALESCE(?1, provider_reference), updated_at = ?2
-                 WHERE payout_id = ?3 AND status IN ('pending', 'processing')",
-                event.provider_reference.as_deref(),
-                occurred_at,
-                payout_id
-            )?
-            .run()
-            .await?;
-            worker::query!(database,"UPDATE developer_payout_attempts SET state='paid',provider_reference=COALESCE(?1,provider_reference),last_error=NULL,updated_at=?2 WHERE payout_id=?3 AND state IN ('created','submitted','processing')",event.provider_reference.as_deref(),occurred_at,payout_id)?.run().await?;
+            finalize_paid_payout(
+                database,
+                payout_id,
+                event.provider_reference.as_deref(),
+                occurred_at,
+            )
+            .await?;
             Ok(None)
         }
@@ENDPATCH@@
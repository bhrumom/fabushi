"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

type NativeBridge = { invoke<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T> };
type Json = Record<string, unknown>;

type PayoutOverview = {
  profile?: Json | null;
  balances?: Json[];
  accounts?: Json[];
  settlements?: Json[];
  payouts?: Json[];
  routes?: Json[];
};

function bridge(): NativeBridge {
  const value = (window as typeof window & { fabushiNative?: NativeBridge }).fabushiNative;
  if (!value?.invoke) throw new Error("Fabushi Desktop native bridge is unavailable.");
  return value;
}

function text(row: Json | null | undefined, ...keys: string[]) {
  for (const key of keys) {
    const value = row?.[key];
    if (typeof value === "string") return value;
  }
  return "";
}

function integer(row: Json | null | undefined, ...keys: string[]) {
  for (const key of keys) {
    const value = row?.[key];
    if (typeof value === "number" && Number.isSafeInteger(value)) return value;
  }
  return 0;
}

function minorExponent(currency: string) {
  const zero = new Set(["BIF","CLP","DJF","GNF","ISK","JPY","KMF","KRW","PYG","RWF","UGX","UYI","VND","VUV","XAF","XOF","XPF"]);
  const three = new Set(["BHD","IQD","JOD","KWD","LYD","OMR","TND"]);
  return zero.has(currency) ? 0 : three.has(currency) ? 3 : 2;
}

function toMinor(value: string, currency: string) {
  const exponent = minorExponent(currency);
  const normalized = value.trim();
  if (!/^\d+(?:\.\d+)?$/.test(normalized)) throw new Error("请输入有效提现金额。");
  const [whole, fraction = ""] = normalized.split(".");
  if (fraction.length > exponent) throw new Error(`${currency} 最多允许 ${exponent} 位小数。`);
  const minor = BigInt(whole) * 10n ** BigInt(exponent) + BigInt((fraction + "0".repeat(exponent)).slice(0, exponent) || "0");
  if (minor <= 0n || minor > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("提现金额超出支持范围。");
  return Number(minor);
}

function money(amount: number, currency: string) {
  const exponent = minorExponent(currency);
  const factor = 10 ** exponent;
  return `${currency} ${(amount / factor).toLocaleString(undefined, { minimumFractionDigits: exponent, maximumFractionDigits: exponent })}`;
}

function accountKind(accountId: string) {
  if (accountId.startsWith("developer-available:")) return "可提现";
  if (accountId.startsWith("developer-reserved:")) return "风险准备金";
  if (accountId.startsWith("developer-pending:")) return "待结算";
  return "余额";
}

function idempotencyKey() {
  return `developer-payout-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export default function DeveloperPayoutPanel() {
  const [overview, setOverview] = useState<PayoutOverview>({});
  const [countryCode, setCountryCode] = useState("CN");
  const [legalEntityType, setLegalEntityType] = useState("company");
  const [preferredCurrency, setPreferredCurrency] = useState("CNY");
  const [payoutSchedule, setPayoutSchedule] = useState("manual");
  const [payoutAccountId, setPayoutAccountId] = useState("");
  const [payoutCurrency, setPayoutCurrency] = useState("CNY");
  const [payoutAmount, setPayoutAmount] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const refresh = useCallback(async () => {
    const result = await bridge().invoke<PayoutOverview>("getDeveloperPayoutOverview");
    setOverview(result ?? {});
    const profile = result?.profile;
    if (profile) {
      setCountryCode(text(profile, "countryCode", "country_code") || "CN");
      setLegalEntityType(text(profile, "legalEntityType", "legal_entity_type") || "company");
      const currency = text(profile, "preferredCurrency", "preferred_currency") || "CNY";
      setPreferredCurrency(currency);
      setPayoutCurrency(currency);
      setPayoutSchedule(text(profile, "payoutSchedule", "payout_schedule") || "manual");
    }
    const firstAccount = result?.accounts?.find((row) => text(row, "state") === "active") ?? result?.accounts?.[0];
    if (firstAccount) setPayoutAccountId(text(firstAccount, "payoutAccountId", "payout_account_id"));
  }, []);

  useEffect(() => { void refresh().catch((reason) => setError(reason instanceof Error ? reason.message : String(reason))); }, [refresh]);

  const activeAccounts = useMemo(() => (overview.accounts ?? []).filter((row) => text(row, "state") === "active" && integer(row, "payoutsEnabled", "payouts_enabled") === 1), [overview.accounts]);

  async function saveProfile(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError(""); setMessage("");
    try {
      await bridge().invoke("upsertDeveloperPayoutProfile", { countryCode: countryCode.toUpperCase(), legalEntityType, preferredCurrency: preferredCurrency.toUpperCase(), payoutSchedule });
      setMessage("结算主体资料已保存。KYC/KYB 与出款能力仍以支付机构审核结果为准。");
      await refresh();
    } catch (reason) { setError(reason instanceof Error ? reason.message : String(reason)); }
    finally { setBusy(false); }
  }

  async function requestPayout(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError(""); setMessage("");
    try {
      await bridge().invoke("requestDeveloperPayout", { payoutAccountId, currency: payoutCurrency.toUpperCase(), amount: toMinor(payoutAmount, payoutCurrency.toUpperCase()), idempotencyKey: idempotencyKey() });
      setPayoutAmount(""); setMessage("提现已进入 Fabushi Payout Orchestrator；资金已锁定并等待对应持牌通道执行。");
      await refresh();
    } catch (reason) { setError(reason instanceof Error ? reason.message : String(reason)); }
    finally { setBusy(false); }
  }

  return <section style={{ padding: 20, border: "1px solid #d1d5db", borderRadius: 16, marginTop: 18 }}>
    <h2>5. 收益与结算 · China + Global</h2>
    <p style={{ opacity: .72 }}>Fabushi Ledger 是唯一权威账本。中国大陆优先使用微信/支付宝原单分账及连连/汇付结算；全球按可用能力路由 Stripe Connect / Adyen / PayPal。未完成 KYC/KYB 或未开通的通道会自动拒绝出款。</p>
    {error && <div role="alert" style={{ padding: 10, border: "1px solid #ef4444", borderRadius: 10, marginBottom: 12 }}>{error}</div>}
    {message && <div role="status" style={{ padding: 10, border: "1px solid #22c55e", borderRadius: 10, marginBottom: 12 }}>{message}</div>}

    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(180px,1fr))", gap: 10, marginBottom: 18 }}>
      {(overview.balances ?? []).map((row, index) => { const currency = text(row, "currency"); const accountId = text(row, "accountId", "account_id"); return <div key={`${accountId}-${index}`} style={{ padding: 12, border: "1px solid #e5e7eb", borderRadius: 12 }}><div style={{ fontSize: 13, opacity: .65 }}>{accountKind(accountId)}</div><strong>{money(integer(row, "balance"), currency)}</strong></div>; })}
      {(overview.balances ?? []).length === 0 && <div style={{ opacity: .6 }}>暂无开发者结算余额。</div>}
    </div>

    <form onSubmit={saveProfile} style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(160px,1fr))", gap: 10, padding: 14, background: "rgba(127,127,127,.05)", borderRadius: 12, marginBottom: 16 }}>
      <input aria-label="结算国家地区" value={countryCode} onChange={(e)=>setCountryCode(e.target.value.toUpperCase())} maxLength={2} required placeholder="CN / US" />
      <select aria-label="开发者主体类型" value={legalEntityType} onChange={(e)=>setLegalEntityType(e.target.value)}><option value="company">企业</option><option value="individual_business">个体工商户 / Sole proprietor</option><option value="nonprofit">非营利组织</option><option value="individual">个人（受地区/额度政策限制）</option></select>
      <input aria-label="首选结算币种" value={preferredCurrency} onChange={(e)=>setPreferredCurrency(e.target.value.toUpperCase())} maxLength={3} required />
      <select aria-label="自动结算周期" value={payoutSchedule} onChange={(e)=>setPayoutSchedule(e.target.value)}><option value="manual">手动提现</option><option value="daily">每日</option><option value="weekly">每周</option><option value="monthly">每月</option></select>
      <button disabled={busy} type="submit">保存结算资料</button>
    </form>

    <div style={{ display: "grid", gap: 10, marginBottom: 16 }}>
      <h3 style={{ marginBottom: 0 }}>KYC/KYB 与出款账户</h3>
      {(overview.accounts ?? []).length === 0 ? <p style={{ opacity: .65 }}>尚无已入驻的结算账户。生产环境需通过对应持牌 provider 的 hosted/embedded onboarding 完成审核后，由服务端登记 provider account。</p> : (overview.accounts ?? []).map((row) => <article key={text(row,"payoutAccountId","payout_account_id")} style={{ padding: 12, border: "1px solid #e5e7eb", borderRadius: 12 }}><strong>{text(row,"provider")}</strong><div style={{ fontSize: 13, opacity: .7 }}>账户：{text(row,"payoutAccountId","payout_account_id")} · 状态 {text(row,"state")} · KYC {text(row,"kycStatus","kyc_status")} · payouts {integer(row,"payoutsEnabled","payouts_enabled") === 1 ? "enabled" : "blocked"}</div></article>)}
    </div>

    <div style={{ display: "grid", gap: 8, marginBottom: 16 }}><h3 style={{ marginBottom: 0 }}>地区路由</h3>{(overview.routes ?? []).map((row) => <div key={text(row,"routeId","route_id")} style={{ fontSize: 13 }}>{text(row,"purpose")} → <strong>{text(row,"provider")}</strong> · {text(row,"state")}</div>)}</div>

    <form onSubmit={requestPayout} style={{ display: "grid", gridTemplateColumns: "2fr 1fr 1fr auto", gap: 10, marginBottom: 18 }}>
      <select aria-label="出款账户" value={payoutAccountId} onChange={(e)=>setPayoutAccountId(e.target.value)} required><option value="">选择已验证账户</option>{activeAccounts.map((row)=><option key={text(row,"payoutAccountId","payout_account_id")} value={text(row,"payoutAccountId","payout_account_id")}>{text(row,"provider")} · {text(row,"payoutAccountId","payout_account_id")}</option>)}</select>
      <input aria-label="提现币种" value={payoutCurrency} onChange={(e)=>setPayoutCurrency(e.target.value.toUpperCase())} maxLength={3} required />
      <input aria-label="提现金额" value={payoutAmount} onChange={(e)=>setPayoutAmount(e.target.value)} placeholder="1000.00" required />
      <button disabled={busy || activeAccounts.length === 0} type="submit">提现</button>
    </form>

    <h3>结算明细</h3>
    <div style={{ display: "grid", gap: 8, marginBottom: 16 }}>{(overview.settlements ?? []).slice(0, 20).map((row) => { const currency=text(row,"currency"); return <article key={text(row,"reconciliationId","reconciliation_id")} style={{ padding: 10, border: "1px solid #e5e7eb", borderRadius: 10, fontSize: 13 }}><strong>{text(row,"settlementSource","settlement_source")}</strong> · gross {money(integer(row,"grossAmount","gross_amount"),currency)} · provider/store {money(integer(row,"providerFeeAmount","provider_fee_amount"),currency)} · tax {money(integer(row,"taxAmount","tax_amount"),currency)} · Fabushi {money(integer(row,"platformFeeAmount","platform_fee_amount"),currency)} · reserve {money(integer(row,"reserveAmount","reserve_amount"),currency)} · developer {money(integer(row,"developerPayableAmount","developer_payable_amount"),currency)}</article>; })}{(overview.settlements ?? []).length===0 && <p style={{opacity:.6}}>暂无已核对 settlement。</p>}</div>

    <h3>提现历史</h3>
    <div style={{ display:"grid", gap:8 }}>{(overview.payouts ?? []).slice(0,20).map((row)=><article key={text(row,"payoutId","payout_id")} style={{padding:10,border:"1px solid #e5e7eb",borderRadius:10,fontSize:13}}><strong>{money(integer(row,"amount"),text(row,"currency"))}</strong> · {text(row,"provider")} · {text(row,"status")}</article>)}{(overview.payouts ?? []).length===0 && <p style={{opacity:.6}}>暂无提现记录。</p>}</div>
  </section>;
}

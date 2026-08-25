"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

type NativeBridge = {
  invoke<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T>;
};

type DeveloperProfile = { developerId?: string; developer_id?: string; displayName?: string; display_name?: string; status?: string };
type MiniApp = { miniAppId?: string; mini_app_id?: string; displayName?: string; display_name?: string; role?: string; status?: string };
type ProviderBinding = { provider: string; syncState?: string; sync_state?: string; externalProductRef?: string; external_product_ref?: string };
type Product = {
  productId?: string; product_id?: string; sku: string; displayName?: string; display_name?: string;
  description?: string; productKind?: string; product_kind?: string; entitlementCapability?: string; entitlement_capability?: string;
  currency: string; amount: number; taxCode?: string | null; tax_code?: string | null;
  subscriptionPeriodSeconds?: number | null; subscription_period_seconds?: number | null;
  providerBindings?: ProviderBinding[]; provider_bindings?: ProviderBinding[];
};

function bridge(): NativeBridge {
  const value = (window as typeof window & { fabushiNative?: NativeBridge }).fabushiNative;
  if (!value?.invoke) throw new Error("Fabushi Desktop native bridge is unavailable.");
  return value;
}

function minorExponent(currency: string) {
  const zero = new Set(["BIF","CLP","DJF","GNF","ISK","JPY","KMF","KRW","PYG","RWF","UGX","UYI","VND","VUV","XAF","XOF","XPF"]);
  const three = new Set(["BHD","IQD","JOD","KWD","LYD","OMR","TND"]);
  return zero.has(currency) ? 0 : three.has(currency) ? 3 : 2;
}

function toMinorUnits(value: string, currency: string) {
  const exponent = minorExponent(currency);
  const normalized = value.trim();
  if (!/^\d+(?:\.\d+)?$/.test(normalized)) throw new Error("请输入有效的正数价格。");
  const [whole, fraction = ""] = normalized.split(".");
  if (fraction.length > exponent) throw new Error(`${currency} 最多允许 ${exponent} 位小数。`);
  const minor = BigInt(whole) * 10n ** BigInt(exponent) + BigInt((fraction + "0".repeat(exponent)).slice(0, exponent) || "0");
  if (minor <= 0n || minor > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("价格超出支持范围。");
  return Number(minor);
}

function fromMinorUnits(value: number, currency: string) {
  const exponent = minorExponent(currency);
  if (exponent === 0) return String(value);
  const factor = 10 ** exponent;
  return (value / factor).toFixed(exponent).replace(/0+$/, "").replace(/\.$/, "");
}

function normalized<T>(value: T | { profile?: T; miniApps?: T; products?: T }): T {
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    return (record.profile ?? record.miniApps ?? record.products ?? value) as T;
  }
  return value as T;
}

export default function BotFatherCommercePanel() {
  const [profile, setProfile] = useState<DeveloperProfile | null>(null);
  const [apps, setApps] = useState<MiniApp[]>([]);
  const [selectedApp, setSelectedApp] = useState("");
  const [products, setProducts] = useState<Product[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const [developerName, setDeveloperName] = useState("");
  const [appId, setAppId] = useState("");
  const [appName, setAppName] = useState("");
  const [sku, setSku] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [description, setDescription] = useState("");
  const [kind, setKind] = useState("digital_durable");
  const [capability, setCapability] = useState("");
  const [currency, setCurrency] = useState("CNY");
  const [price, setPrice] = useState("");
  const [taxCode, setTaxCode] = useState("");
  const [rails, setRails] = useState(["apple_advanced_commerce", "google_play", "web_provider"]);
  const [editingProductId, setEditingProductId] = useState("");

  const selected = useMemo(() => apps.find((item) => (item.miniAppId ?? item.mini_app_id) === selectedApp), [apps, selectedApp]);

  const run = useCallback(async <T,>(method: string, params: Record<string, unknown> = {}) => {
    setError(""); setMessage("");
    try { return await bridge().invoke<T>(method, params); }
    catch (reason) { const text = reason instanceof Error ? reason.message : String(reason); setError(text); throw reason; }
  }, []);

  const refreshApps = useCallback(async () => {
    const result = await run<MiniApp[] | { miniApps?: MiniApp[] }>("listDeveloperCommerceMiniApps");
    const list = normalized<MiniApp[]>(result) ?? [];
    setApps(Array.isArray(list) ? list : []);
    setSelectedApp((current) => current || (list[0]?.miniAppId ?? list[0]?.mini_app_id ?? ""));
  }, [run]);

  const refreshProducts = useCallback(async (miniAppId: string) => {
    if (!miniAppId) { setProducts([]); return; }
    const result = await run<Product[] | { products?: Product[] }>("listDeveloperCommerceProducts", { miniAppId });
    const list = normalized<Product[]>(result) ?? [];
    setProducts(Array.isArray(list) ? list : []);
  }, [run]);

  useEffect(() => {
    void (async () => {
      try {
        const result = await run<DeveloperProfile | { profile?: DeveloperProfile | null }>("getDeveloperCommerceProfile");
        const current = normalized<DeveloperProfile | null>(result);
        setProfile(current ?? null);
        setDeveloperName(current?.displayName ?? current?.display_name ?? "");
        await refreshApps();
      } catch { /* rendered in error state */ }
    })();
  }, [refreshApps, run]);

  useEffect(() => { void refreshProducts(selectedApp).catch(() => undefined); }, [refreshProducts, selectedApp]);

  async function saveProfile(event: FormEvent) {
    event.preventDefault(); setBusy(true);
    try {
      const result = await run<DeveloperProfile>("upsertDeveloperCommerceProfile", { displayName: developerName });
      setProfile(result); setMessage("开发者资料已保存。"); await refreshApps();
    } finally { setBusy(false); }
  }

  async function registerApp(event: FormEvent) {
    event.preventDefault(); setBusy(true);
    try {
      await run("registerDeveloperCommerceMiniApp", { miniAppId: appId, displayName: appName });
      setMessage("Mini App 已绑定到当前开发者。"); setAppId(""); setAppName(""); await refreshApps();
    } finally { setBusy(false); }
  }

  async function saveProduct(event: FormEvent) {
    event.preventDefault();
    if (!selectedApp) { setError("请先选择 Mini App。"); return; }
    setBusy(true);
    try {
      const payload = {
        miniAppId: selectedApp, productId: editingProductId || undefined, sku, displayName, description,
        productKind: kind, entitlementCapability: capability, currency,
        amount: toMinorUnits(price, currency), taxCode: taxCode || undefined,
        subscriptionPeriodSeconds: kind === "subscription" ? 2_592_000 : undefined, rails,
      };
      await run(editingProductId ? "updateDeveloperCommerceProduct" : "createDeveloperCommerceProduct", payload);
      setMessage(editingProductId ? "新价格版本已创建。" : "商品已创建。");
      setEditingProductId(""); setSku(""); setDisplayName(""); setDescription(""); setCapability(""); setPrice("");
      await refreshProducts(selectedApp);
    } finally { setBusy(false); }
  }

  function editProduct(product: Product) {
    setEditingProductId(product.productId ?? product.product_id ?? ""); setSku(product.sku);
    setDisplayName(product.displayName ?? product.display_name ?? ""); setDescription(product.description ?? "");
    setKind(product.productKind ?? product.product_kind ?? "digital_durable");
    setCapability(product.entitlementCapability ?? product.entitlement_capability ?? ""); setCurrency(product.currency);
    setPrice(fromMinorUnits(product.amount, product.currency)); setTaxCode(product.taxCode ?? product.tax_code ?? "");
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function syncGoogle(product: Product) {
    const productId = product.productId ?? product.product_id;
    if (!productId || !selectedApp) return;
    setBusy(true);
    try { await run("syncDeveloperCommerceGoogleProduct", { miniAppId: selectedApp, productId }); setMessage("Google Play 商品同步完成。"); await refreshProducts(selectedApp); }
    finally { setBusy(false); }
  }

  const railChoices = [
    ["apple_advanced_commerce", "iOS · Advanced Commerce"], ["google_play", "Android · Google Play"], ["web_provider", "Web / Desktop"],
  ] as const;

  return <main style={{ maxWidth: 1080, margin: "0 auto", padding: "28px 24px 64px", color: "var(--foreground, #111827)" }}>
    <header style={{ marginBottom: 28 }}><p style={{ opacity: .6, margin: 0 }}>Bot Father · Developer Commerce</p><h1 style={{ fontSize: 30, margin: "6px 0" }}>Mini App 法币商品管理</h1><p style={{ opacity: .7 }}>商品目录由 Fabushi 托管。开发者定义 SKU 与法币价格；Apple / Google / Web 的商店映射和结算由平台处理。</p></header>
    {error && <div role="alert" style={{ padding: 12, border: "1px solid #ef4444", borderRadius: 10, marginBottom: 16 }}>{error}</div>}
    {message && <div role="status" style={{ padding: 12, border: "1px solid #22c55e", borderRadius: 10, marginBottom: 16 }}>{message}</div>}

    <section style={{ padding: 20, border: "1px solid #d1d5db", borderRadius: 16, marginBottom: 18 }}><h2>1. 开发者身份</h2>
      <form onSubmit={saveProfile} style={{ display: "flex", gap: 10, flexWrap: "wrap" }}><input aria-label="开发者名称" value={developerName} onChange={(e)=>setDeveloperName(e.target.value)} required maxLength={80} placeholder="开发者/公司名称" style={{ flex: 1, minWidth: 220, padding: 10 }} /><button disabled={busy} type="submit">{profile ? "更新资料" : "创建开发者"}</button></form>
    </section>

    <section style={{ padding: 20, border: "1px solid #d1d5db", borderRadius: 16, marginBottom: 18 }}><h2>2. Mini App</h2>
      <form onSubmit={registerApp} style={{ display:"grid", gridTemplateColumns:"1fr 1fr auto", gap:10 }}><input aria-label="Mini App ID" value={appId} onChange={(e)=>setAppId(e.target.value)} required placeholder="example-app" /><input aria-label="Mini App 名称" value={appName} onChange={(e)=>setAppName(e.target.value)} required placeholder="显示名称" /><button disabled={busy} type="submit">注册</button></form>
      {apps.length > 0 && <select aria-label="选择 Mini App" value={selectedApp} onChange={(e)=>setSelectedApp(e.target.value)} style={{ marginTop:12, width:"100%", padding:10 }}>{apps.map((item)=>{const id=item.miniAppId??item.mini_app_id??"";return <option key={id} value={id}>{item.displayName??item.display_name??id} · {item.role??"owner"}</option>})}</select>}
    </section>

    <section style={{ padding:20, border:"1px solid #d1d5db", borderRadius:16, marginBottom:18 }}><h2>3. {editingProductId ? "修改商品 / 创建价格版本" : "创建法币商品"}</h2>
      <form onSubmit={saveProduct} style={{ display:"grid", gridTemplateColumns:"repeat(2,minmax(0,1fr))", gap:12 }}>
        <input aria-label="SKU" value={sku} onChange={(e)=>setSku(e.target.value)} required disabled={Boolean(editingProductId)} placeholder="pro.monthly" />
        <input aria-label="商品名称" value={displayName} onChange={(e)=>setDisplayName(e.target.value)} required maxLength={30} placeholder="专业版月会员" />
        <input aria-label="商品描述" value={description} onChange={(e)=>setDescription(e.target.value)} maxLength={45} placeholder="功能说明" />
        <input aria-label="权益能力" value={capability} onChange={(e)=>setCapability(e.target.value)} required placeholder="pro.access" />
        <select aria-label="商品类型" value={kind} onChange={(e)=>setKind(e.target.value)} disabled={Boolean(editingProductId)}><option value="digital_durable">一次性数字权益</option><option value="digital_consumable">消耗品</option><option value="subscription">30 天订阅</option><option value="physical">实体商品</option><option value="service">服务</option></select>
        <div style={{display:"flex",gap:8}}><input aria-label="货币" value={currency} onChange={(e)=>setCurrency(e.target.value.toUpperCase())} required maxLength={3} style={{width:90}} /><input aria-label="法币价格" value={price} onChange={(e)=>setPrice(e.target.value)} required placeholder="30.00" style={{flex:1}} /></div>
        <input aria-label="税务分类" value={taxCode} onChange={(e)=>setTaxCode(e.target.value)} placeholder="Apple / Google tax code" />
        <div>{railChoices.map(([value,label])=><label key={value} style={{display:"block"}}><input type="checkbox" checked={rails.includes(value)} onChange={(e)=>setRails((current)=>e.target.checked?[...new Set([...current,value])]:current.filter((item)=>item!==value))} /> {label}</label>)}</div>
        <div style={{gridColumn:"1 / -1",display:"flex",gap:8}}><button disabled={busy||!selected} type="submit">{editingProductId ? "保存新价格版本" : "创建商品"}</button>{editingProductId && <button type="button" onClick={()=>setEditingProductId("")}>取消编辑</button>}</div>
      </form>
    </section>

    <section style={{ padding:20, border:"1px solid #d1d5db", borderRadius:16 }}><h2>4. 商品与商店状态</h2>
      {products.length===0 ? <p style={{opacity:.6}}>当前 Mini App 还没有商品。</p> : <div style={{display:"grid",gap:12}}>{products.map((product)=>{const id=product.productId??product.product_id??product.sku;const bindings=product.providerBindings??product.provider_bindings??[];return <article key={id} style={{padding:14,border:"1px solid #e5e7eb",borderRadius:12}}><strong>{product.displayName??product.display_name??product.sku}</strong><div>{product.sku} · {product.currency} {fromMinorUnits(product.amount,product.currency)}</div><div style={{fontSize:13,opacity:.7,margin:"6px 0"}}>{bindings.length ? bindings.map((binding)=>`${binding.provider}: ${binding.syncState??binding.sync_state??"unknown"}`).join(" · ") : "商店状态将在同步后显示"}</div><div style={{display:"flex",gap:8}}><button type="button" onClick={()=>editProduct(product)}>改价/编辑</button><button type="button" disabled={busy} onClick={()=>void syncGoogle(product)}>同步 Google Play</button></div></article>})}</div>}
    </section>
  </main>;
}

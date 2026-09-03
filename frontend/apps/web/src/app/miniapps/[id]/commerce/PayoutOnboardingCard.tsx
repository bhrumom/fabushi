"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

type NativeBridge = { invoke<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T> };
type Row = Record<string, unknown>;
type Overview = { profile?: Row | null; routes?: Row[]; accounts?: Row[] };
type Onboarding = { onboardingUrl?: string; provider?: string; purpose?: string; state?: string };

function bridge(): NativeBridge {
  const value=(window as typeof window & { fabushiNative?: NativeBridge }).fabushiNative;
  if(!value?.invoke) throw new Error("Fabushi Desktop native bridge is unavailable.");
  return value;
}
function text(row: Row | null | undefined, ...keys:string[]) {
  for(const key of keys){ const value=row?.[key]; if(typeof value === "string") return value; }
  return "";
}

const labels: Record<string,string> = {
  stripe_connect:"Stripe Connect",
  adyen_platform:"Adyen for Platforms",
  paypal_multiparty:"PayPal Multiparty",
  paypal_payouts:"PayPal Payouts",
  wechat_platform:"微信支付 · 平台收付通",
  alipay_platform:"支付宝 · 互联网平台直付通",
  lianlian_account_plus:"连连账户+",
  huifu_dougong:"汇付天下 · 斗拱",
};

export default function PayoutOnboardingCard(){
  const [overview,setOverview]=useState<Overview>({});
  const [busy,setBusy]=useState("");
  const [error,setError]=useState("");
  const [message,setMessage]=useState("");
  const refresh=useCallback(async()=>setOverview(await bridge().invoke<Overview>("getDeveloperPayoutOverview") ?? {}),[]);
  useEffect(()=>{void refresh().catch((e)=>setError(e instanceof Error?e.message:String(e)));},[refresh]);
  const activeRoutes=useMemo(()=>{
    const unique=new Map<string,Row>();
    for(const row of overview.routes ?? []){
      if(text(row,"state")!=="active") continue;
      const provider=text(row,"provider"), purpose=text(row,"purpose");
      if(provider && purpose) unique.set(`${provider}:${purpose}`,row);
    }
    return [...unique.values()];
  },[overview.routes]);
  async function onboard(provider:string,purpose:string){
    setBusy(`${provider}:${purpose}`); setError(""); setMessage("");
    try{
      const result=await bridge().invoke<Onboarding>("createDeveloperPayoutOnboarding",{provider,purpose});
      const url=result?.onboardingUrl;
      if(!url || !url.startsWith("https://")) throw new Error("Provider did not return a secure onboarding URL.");
      await bridge().invoke("openExternal",{url});
      setMessage(`${labels[provider] ?? provider} 开户/验证页面已打开。审核完成后，Fabushi 会依据 provider capability 更新账户状态。`);
      await refresh();
    }catch(e){setError(e instanceof Error?e.message:String(e));}
    finally{setBusy("");}
  }
  return <section style={{padding:20,border:"1px solid #d1d5db",borderRadius:16,marginTop:18}}>
    <h2>6. 开通结算通道</h2>
    <p style={{opacity:.72}}>这里仅显示运营侧已经批准并激活的地区路由。身份材料、受益所有人资料和银行信息直接提交给持牌 provider，Fabushi renderer 不保存这些原始敏感材料。</p>
    {error && <div role="alert" style={{padding:10,border:"1px solid #ef4444",borderRadius:10,marginBottom:10}}>{error}</div>}
    {message && <div role="status" style={{padding:10,border:"1px solid #22c55e",borderRadius:10,marginBottom:10}}>{message}</div>}
    <div style={{display:"grid",gap:10}}>
      {activeRoutes.map((row)=>{const provider=text(row,"provider"),purpose=text(row,"purpose"),key=`${provider}:${purpose}`;return <article key={key} style={{display:"flex",justifyContent:"space-between",gap:12,alignItems:"center",padding:12,border:"1px solid #e5e7eb",borderRadius:12}}><div><strong>{labels[provider] ?? provider}</strong><div style={{fontSize:13,opacity:.65}}>{purpose}</div></div><button type="button" disabled={busy===key} onClick={()=>void onboard(provider,purpose)}>{busy===key?"正在创建…":"开始开户 / KYC-KYB"}</button></article>;})}
      {activeRoutes.length===0 && <p style={{opacity:.65}}>当前地区还没有已激活的结算 provider。系统会保持 fail-closed，不会把“接口存在”当成“支付机构已经批准”。</p>}
    </div>
  </section>;
}

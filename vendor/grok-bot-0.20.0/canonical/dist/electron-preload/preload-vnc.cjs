"use strict";function S(e,...n){return{edge:e,hasEvents:n.length>0}}var _="edge/unknown-method";var L="edge/handler-failed",E=class extends Error{code;detail;constructor(n){super(`${n.code}: ${n.detail}`),this.name="EdgeCallFailure",this.code=n.code,this.detail=n.detail}};function ce(e){return typeof e!="object"||e==null||!("ok"in e)?!1:typeof e.ok=="boolean"}function de(e,n){return`sand-rpc:${e}:m:${n}`}function ue(e,n){return`sand-rpc:${e}:e:${n}`}function R(e,n,t){let r={},a=async(i,c)=>{let o;try{o=await t.invoke(de(e.edge,i),c)}catch(l){let s=l instanceof Error?l.message:String(l);throw new E({code:_,detail:s})}if(!ce(o))throw new E({code:L,detail:"The edge replied outside its envelope."});if(o.ok)return o.value;throw new E(o.failure)};for(let[i,c]of Object.entries(n))r[i]=c.args==="none"?()=>a(i,{}):o=>a(i,o);return e.hasEvents&&(r.subscribe=i=>{let c=[];for(let[o,l]of Object.entries(i))l!=null&&c.push(t.on(ue(e.edge,o),l));return()=>{for(let o of c)o()}}),r}var T={now:()=>Date.now(),monotonicNow:()=>performance.now(),schedule(e,n){pe(e);let t=!0,r=globalThis.setTimeout(()=>{t&&(t=!1,n())},e);return r.unref?.(),{dispose(){t&&(t=!1,globalThis.clearTimeout(r))}}}};function pe(e){if(!Number.isFinite(e)||e<0)throw new RangeError("delayMs must be a finite non-negative number")}var w=class extends Error{constructor(t){super(`Deadline exceeded for ${t}`);this.policyName=t;this.name="DeadlineExceededError"}policyName;code="deadline_exceeded"};function V(e,n){return N(n.name),B(n.timeoutMs,"timeoutMs"),{name:n.name,async run(t,r){if(r?.aborted)throw O(r);let a=new AbortController,i=()=>{},c=new Promise((f,p)=>{i=p}),o=()=>{},l=new Promise((f,p)=>{o=p}),s=()=>{};if(r!=null){let f=()=>{let p=O(r);o(p),a.abort(p)};r.addEventListener("abort",f,{once:!0}),s=()=>r.removeEventListener("abort",f)}let m=e.schedule(n.timeoutMs,()=>{let f=new w(n.name);i(f),a.abort(f)});try{return await Promise.race([t(a.signal),c,l])}finally{m.dispose(),s()}}}}function A(e,n){if(N(n.name),B(n.intervalMs,"intervalMs"),n.intervalMs===0)throw new RangeError("intervalMs must be greater than 0");return{name:n.name,start(t,r){let a=!0,i,c=()=>{},o=()=>{a&&(a=!1,i?.dispose(),i=void 0,c())},l=()=>{if(i=void 0,!a)return;let m;try{m=t()}catch{o();return}m.then(()=>{a&&(i=e.schedule(n.intervalMs,l))},()=>o())},s={dispose:o};return r?.aborted?(o(),s):(r!=null&&(r.addEventListener("abort",o,{once:!0}),c=()=>r.removeEventListener("abort",o)),l(),s)}}}function O(e){return e.reason??ye()}function ye(){let e=new Error("Operation aborted");return e.name="AbortError",e}function N(e,n="name"){if(e.trim().length===0)throw new TypeError(`${n} must not be empty`)}function B(e,n){if(!Number.isFinite(e)||e<0)throw new RangeError(`${n} must be a finite non-negative number`)}function I(e){return V(T,e)}function M(e){return A(T,e)}var H=S("box-vnc"),W={readClipboard:{args:"none"},writeClipboard:{args:"object"},reportUserPresence:{args:"object"}};var F="sand:vnc-liveness";var K="sand:vnc-viewer-visible";function j(e){return`
    import("./app/ui.js")
      .then(function (m) {
        var rfb = m && m.default && m.default.rfb;
        var text = ${JSON.stringify(e)};
        if (rfb && typeof rfb.clipboardPasteFrom === "function" && text) {
          rfb.clipboardPasteFrom(text);
          return true;
        }
        return false;
      })
      .catch(function () {
        return false;
      });
  `}function U(e,n){return n&&e.length>0?e:null}var D="__sandVncLivenessBeacon";function q(){return`
    (function () {
      if (window.${D}) return;
      var counters = { keys: 0, clicks: 0, moves: 0, drawOps: 0, inBytes: 0 };
      window.${D} = counters;
      var PRIMARY_BUTTON_MASK_BITS = 0x07;
      var lastButtonMask = 0;
      import("./core/rfb.js").then(function (m) {
        var messages = m.default.messages;
        var keyEvent = messages.keyEvent;
        messages.keyEvent = function (sock, keysym, down) {
          if (down) counters.keys += 1;
          return keyEvent.apply(this, arguments);
        };
        if (typeof messages.QEMUExtendedKeyEvent === "function") {
          var qemuKeyEvent = messages.QEMUExtendedKeyEvent;
          messages.QEMUExtendedKeyEvent = function (sock, keysym, down) {
            if (down) counters.keys += 1;
            return qemuKeyEvent.apply(this, arguments);
          };
        }
        var pointerEvent = messages.pointerEvent;
        messages.pointerEvent = function (sock, x, y, mask) {
          if (mask & ~lastButtonMask & PRIMARY_BUTTON_MASK_BITS) counters.clicks += 1;
          else counters.moves += 1;
          lastButtonMask = mask;
          return pointerEvent.apply(this, arguments);
        };
      }).catch(function () {});
      import("./core/display.js").then(function (m) {
        var damage = m.default.prototype._damage;
        m.default.prototype._damage = function () {
          counters.drawOps += 1;
          return damage.apply(this, arguments);
        };
      }).catch(function () {});
      import("./core/websock.js").then(function (m) {
        var recvMessage = m.default.prototype._recvMessage;
        m.default.prototype._recvMessage = function (e) {
          counters.inBytes += (e && e.data && e.data.byteLength) || 0;
          return recvMessage.apply(this, arguments);
        };
      }).catch(function () {});
    })();
  `}function G(){return`JSON.stringify(window.${D} || null)`}function C(e){return typeof e=="number"&&Number.isFinite(e)&&e>=0}function J(e){if(typeof e!="string")return null;let n=JSON.parse(e);if(typeof n!="object"||n===null)return null;let t=n;return!C(t.keys)||!C(t.clicks)||!C(t.moves)||!C(t.drawOps)||!C(t.inBytes)?null:{keys:t.keys,clicks:t.clicks,moves:t.moves,drawOps:t.drawOps,inBytes:t.inBytes}}function Q(){let e=null,n=[],t=null,r=!1;function a(){e=null,n=[],t=null,r=!1}function i(o,l){a(),e=l,t=o}function c(o,l){if(e==null)return i(o,l),null;let s={atMs:o,keys:l.keys-e.keys,clicks:l.clicks-e.clicks,moves:l.moves-e.moves,drawOps:l.drawOps-e.drawOps,inBytes:l.inBytes-e.inBytes};if(s.keys<0||s.clicks<0||s.moves<0||s.drawOps<0||s.inBytes<0)return i(o,l),null;e=l,n.push(s);let m=o-1e4;if(n=n.filter(g=>g.atMs>m),s.drawOps>0&&(r=!1),r||t==null||o-t<1e4)return null;let f=0,p=0,y=0,h=0,b=0;for(let g of n)f+=g.keys,p+=g.clicks,y+=g.moves,h+=g.drawOps,b+=g.inBytes;if(f+p<3||h>0||b>0)return null;r=!0;let k=n.find(g=>g.keys+g.clicks>0);return{phase:"post_connect",stallMs:o-(k?.atMs??o),keys:f,clicks:p,moves:y,inBytes:b}}return{sample:c,reset:a}}function X(){let e=!1;return{isVisible:()=>e,update(n){let t=n===!0,r=t&&!e;return e=t,r}}}var Y=6e4;function z(e){return e.policy.run(()=>e.call).catch(n=>{throw n instanceof w?(e.reportStall({method:e.method,since:e.since}),e.buildStallError()):n})}var Z=[".okta.com",".okta-emea.com",".oktapreview.com",".duosecurity.com",".login.microsoftonline.com",".onelogin.com",".auth0.com",".pingidentity.com",".rippling.com"];function d(e){return e instanceof Error?e.message:void 0}function u(...e){console.warn("[sand-webview-preload]",...e)}var ee=!1,te=null,re=null;function oe(){if(!ee){ee=!0;try{let e=require("electron");te=e.ipcRenderer??null,re=e.webFrame??null}catch(e){u("electron module unavailable",d(e))}}}function v(){return oe(),te}function x(){return oe(),re}function me(e){if(typeof e!="string"||e.length===0)return!1;for(let n=0;n<Z.length;n++)if(e.endsWith(Z[n]))return!0;return!1}function ge(){let e=x();if(e==null||typeof location>"u"||!me(location.hostname))return;e.executeJavaScript(`
    (function () {
      var permissions = navigator && navigator.permissions;
      if (!permissions || typeof permissions.query !== "function") return;
      if (permissions.__sandLocalNetworkPolyfill) return;
      permissions.__sandLocalNetworkPolyfill = true;
      var originalQuery = permissions.query.bind(permissions);
      permissions.query = function (descriptor) {
        var name = descriptor && descriptor.name;
        if (name === "local-network-access" || name === "local-network") {
          var status = new EventTarget();
          Object.defineProperties(status, {
            name: { value: name },
            state: { value: "granted" },
            onchange: { value: null, writable: true },
          });
          return Promise.resolve(status);
        }
        return originalQuery(descriptor);
      };
    })();
  `).catch(t=>{u("local network polyfill injection failed",d(t))})}function ve(){try{return new DOMException("Passkey request stalled","NotAllowedError")}catch{let n=new Error("Passkey request stalled");return n.name="NotAllowedError",n}}var he=I({name:"sand-webview-passkey-stall",timeoutMs:Y});function ne(e,n,t){return function(...a){let i=Date.now(),c;try{let o=t.apply(navigator.credentials,a);c=Promise.resolve(o)}catch(o){return Promise.reject(o)}return z({policy:he,method:n,since:i,call:c,reportStall:o=>{try{e.sendToHost("sand:browser-passkey-stalled",o)}catch(l){u("passkey stall send failed",d(l))}},buildStallError:ve})}}function be(){if(typeof navigator>"u")return;let e=v();if(e!=null&&navigator.credentials){if(typeof navigator.credentials.create=="function"){let n=navigator.credentials.create.bind(navigator.credentials);navigator.credentials.create=ne(e,"create",n)}if(typeof navigator.credentials.get=="function"){let n=navigator.credentials.get.bind(navigator.credentials);navigator.credentials.get=ne(e,"get",n)}}}function Ee(){typeof window>"u"||window.__sandDialogOverridesApplied!==!0&&(window.alert=function(){},window.confirm=function(){return!0},window.prompt=function(){return null},window.__sandDialogOverridesApplied=!0)}function we(){let e=v();if(e==null)return;let n=e;if(typeof window>"u"||typeof location>"u")return;let t=location.origin;function r(){try{n.sendToHost("sand:browser-popup-closed",{url:location.href})}catch(a){u("popup-closed send failed",d(a))}}window.addEventListener("beforeunload",r),window.addEventListener("pagehide",r),window.addEventListener("pageshow",function(i){if(!(!i||i.persisted!==!0)&&location.origin===t)try{n.sendToHost("sand:browser-origin-return",{origin:t,currentUrl:location.href})}catch(c){u("origin-return send failed",d(c))}})}function ie(){try{ge()}catch(e){u("local network polyfill install failed",d(e))}try{be()}catch(e){u("webauthn polyfill install failed",d(e))}try{Ee()}catch(e){u("dialog stubs install failed",d(e))}try{we()}catch(e){u("ipc wiring install failed",d(e))}}function ae(){let e=v();return e==null?null:R(H,W,{invoke:(t,r)=>e.invoke(t,r),on:(t,r)=>{let a=(i,c)=>{r(c)};return e.on(t,a),()=>{e.off(t,a)}}})}function P(){if(typeof location>"u"||!location.pathname.endsWith("/vnc.html"))return!1;try{return new URLSearchParams(location.search).get("sandInteractive")==="1"}catch{return!1}}function se(){if(typeof document>"u")return null;let e=document.getElementById("noVNC_clipboard_text");return e instanceof HTMLTextAreaElement?e:null}function xe(){if(typeof location>"u"||!location.pathname.endsWith("/vnc.html"))return;let e=`
    #noVNC_control_bar,
    #noVNC_control_bar_handle,
    #noVNC_control_bar_anchor,
    #noVNC_status,
    .noVNC_logo {
      display: none !important;
      pointer-events: none !important;
      visibility: hidden !important;
    }
  `;try{x()?.insertCSS(e)}catch(t){u("noVNC CSS injection failed",d(t))}function n(){document.getElementById("noVNC_control_bar")?.classList.remove("noVNC_open")}typeof document>"u"||(n(),document.addEventListener("DOMContentLoaded",n,{once:!0}),window.addEventListener("load",n,{once:!0}))}function ke(){let e=v(),n=ae();if(e==null||n==null)return;let t=n;if(typeof window>"u"||typeof document>"u"||!P())return;let r=500,a=200,i="",c="",o=0,l=X();e.on(K,(p,y)=>{l.update(y)&&m()});function s(){if(!l.isVisible())return;let p=se();if(p==null)return;let y=p.value;y.length!==0&&(y===c||y===i||(i=y,t.writeClipboard({text:y}).catch(h=>{u("vnc clipboard write failed",d(h))})))}function m(){if(!l.isVisible())return;let p=Date.now();p-o<a||(o=p,t.readClipboard().then(y=>{if(y.length===0)return;let h=x();h?.executeJavaScript(j(y)).then(b=>{let k=U(y,b===!0);if(k==null)return;c=k;let g=se();g!=null&&(g.value=k)}).catch(b=>{u("vnc clipboard paste failed",d(b))})}).catch(y=>{u("vnc clipboard read failed",d(y))}))}let f=M({name:"vnc-clipboard-mirror",intervalMs:r}).start(async()=>{s()});window.addEventListener("focus",m),document.addEventListener("mousedown",m,!0),document.addEventListener("visibilitychange",()=>{document.visibilityState==="visible"&&m()}),window.addEventListener("pagehide",()=>f.dispose(),{once:!0})}function le(){let e=ae();if(e==null)return;let n=e;if(typeof window>"u"||typeof document>"u"||!P())return;if(document.documentElement==null){document.addEventListener("DOMContentLoaded",()=>le(),{once:!0});return}let t=null;function r(i){i!==t&&(t=i,n.reportUserPresence({isPresent:i}).catch(c=>{u("vnc user presence report failed",d(c))}))}let a=document.documentElement;a.addEventListener("mouseenter",()=>r(!0)),a.addEventListener("mouseleave",()=>r(!1)),document.addEventListener("mousemove",()=>r(!0),{passive:!0}),window.addEventListener("blur",()=>r(!1)),window.addEventListener("pagehide",()=>r(!1),{once:!0})}function Ce(){let e=v();if(e==null||typeof document>"u"||!P())return;let n=new Set(["ArrowUp","ArrowDown","ArrowLeft","ArrowRight"]);document.addEventListener("keydown",t=>{if(n.has(t.key))try{e.sendToHost("sand:vnc-host-key",t.key)}catch(r){u("vnc host key forward failed",d(r))}},!0)}function Pe(){let e=v();if(e==null)return;let n=e;if(typeof window>"u"||typeof document>"u"||typeof location>"u"||!location.pathname.endsWith("/vnc.html"))return;function t(s,m){try{n.sendToHost("sand:vnc-session",JSON.stringify({phase:s,clean:m}))}catch(f){u("vnc session report failed",d(f))}}let r=0,a=!1,i=null;function c(){let s=document.documentElement.classList;return s.contains("noVNC_connected")?"connected":s.contains("noVNC_reconnecting")?"reconnecting":s.contains("noVNC_connecting")?"connecting":s.contains("noVNC_disconnecting")?"disconnecting":"disconnected"}function o(){let s=c();s!==i&&(i=s,s==="connected"?(r+=1,t(r>1?"reconnect":"rfb_connect",!0),a=!0):a&&s!=="connecting"&&(t("rfb_disconnect",s==="disconnecting"),a=!1))}function l(){let s=new MutationObserver(o);s.observe(document.documentElement,{attributes:!0,attributeFilter:["class"]}),o(),window.addEventListener("pagehide",()=>s.disconnect(),{once:!0})}document.documentElement==null?document.addEventListener("DOMContentLoaded",()=>l(),{once:!0}):l()}function Se(){let e=v(),n=x();if(e==null||n==null)return;let t=e,r=n;if(typeof window>"u"||typeof document>"u"||!P())return;r.executeJavaScript(q()).catch(o=>{u("vnc liveness beacon install failed",d(o))});let a=Q(),i=G(),c=M({name:"vnc-liveness-sampler",intervalMs:1e3}).start(async()=>{if(document.documentElement?.classList.contains("noVNC_connected")!==!0){a.reset();return}try{let o=await r.executeJavaScript(i),l=J(o);if(l==null)return;let s=a.sample(performance.now(),l);if(s==null)return;t.sendToHost(F,s)}catch(o){u("vnc liveness sample failed",d(o))}});window.addEventListener("pagehide",()=>c.dispose(),{once:!0})}function Re(){let e=x();if(e==null||!P())return;e.executeJavaScript(`
    (function () {
      if (window.__sandVncMacKeysInstalled) return;
      if (!/Mac/i.test((navigator && navigator.platform) || "")) return;
      window.__sandVncMacKeysInstalled = true;

      var SHORTCUTS = { KeyA: 0x61, KeyC: 0x63, KeyV: 0x76, KeyX: 0x78, KeyZ: 0x7a };
      // V forces Shift: terminals paste on Ctrl+Shift+V (plain Ctrl+V is a
      // verbatim keystroke there) and Chrome accepts Ctrl+Shift+V as paste.
      // C must stay plain: Ctrl+Shift+C is DevTools inspect in Chrome, not copy.
      // Shifted chords must carry the UPPERCASE keysym (ASCII - 0x20): x11vnc's
      // default -modtweak momentarily lifts the held Shift to type a lowercase
      // keysym, which would turn Ctrl+Shift+V back into plain Ctrl+V in the box.
      var FORCE_SHIFT = { KeyV: true };
      var CONTROL_L = 0xffe3;
      var SHIFT_L = 0xffe1;
      var HELD_MODIFIERS = [
        [0xffe7, "MetaLeft"], [0xffe8, "MetaRight"],
        [0xffe9, "AltLeft"], [0xffea, "AltRight"],
        [0xffeb, "SuperLeft"], [0xffec, "SuperRight"]
      ];

      var ui = null;
      import("./app/ui.js")
        .then(function (m) { ui = m && m.default; })
        .catch(function () {});

      document.addEventListener("keydown", function (e) {
        if (!e.metaKey) return;
        var keysym = SHORTCUTS[e.code];
        if (keysym === undefined) return;
        var rfb = ui && ui.rfb;
        if (!rfb || typeof rfb.sendKey !== "function") return;
        e.preventDefault();
        e.stopImmediatePropagation();
        // noVNC presses Meta/Alt down for Cmd, so release them first to avoid
        // sending Alt+Ctrl+key instead of a clean Ctrl+key.
        for (var i = 0; i < HELD_MODIFIERS.length; i++) {
          try { rfb.sendKey(HELD_MODIFIERS[i][0], HELD_MODIFIERS[i][1], false); } catch (_e) {}
        }
        var withShift = e.shiftKey || FORCE_SHIFT[e.code] === true;
        var chordKeysym = withShift ? keysym - 0x20 : keysym;
        rfb.sendKey(CONTROL_L, "ControlLeft", true);
        if (withShift) rfb.sendKey(SHIFT_L, "ShiftLeft", true);
        rfb.sendKey(chordKeysym, e.code, true);
        rfb.sendKey(chordKeysym, e.code, false);
        if (withShift) rfb.sendKey(SHIFT_L, "ShiftLeft", false);
        rfb.sendKey(CONTROL_L, "ControlLeft", false);
      }, true);
    })();
  `).catch(t=>{u("vnc mac key mapping injection failed",d(t))})}ie();try{xe()}catch(e){u("noVNC chrome hider install failed",d(e))}try{ke()}catch(e){u("vnc clipboard bridge install failed",d(e))}try{le()}catch(e){u("vnc user presence reporter install failed",d(e))}try{Ce()}catch(e){u("vnc host key forwarder install failed",d(e))}try{Pe()}catch(e){u("vnc rfb session reporter install failed",d(e))}try{Re()}catch(e){u("vnc mac key mapping install failed",d(e))}try{Se()}catch(e){u("vnc liveness tripwire install failed",d(e))}

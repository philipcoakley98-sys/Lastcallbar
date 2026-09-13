(function(){
  function ready(){
    const sb=window.LASTCALL&&window.LASTCALL.sb;
    if(!sb){setTimeout(ready,100);return;}
    function esc(s){return String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
    function show(html,type){const p=document.getElementById('panel'),c=document.getElementById('panelContent');if(!p||!c)return;c.innerHTML=html;p.dataset.panel=type||'auth';p.classList.remove('hidden')}
    window.openPanel=function(type){
      if(type==='join') return authForm(false);
      if(type==='signin') return authForm(true);
      if(type==='write') return typeof window.__lastCallWriteForm==='function'?window.__lastCallWriteForm():document.querySelector('[onclick*="write"]')?.click();
      if(type==='search') return typeof window.__lastCallSearchForm==='function'?window.__lastCallSearchForm():null;
      if(type==='about') return typeof window.__lastCallAboutForm==='function'?window.__lastCallAboutForm():null;
    };
    function authForm(signin){
      show(`<div class="eyebrow">LAST CALL · Members</div><h1>${signin?'Sign in':'Become a free member'}</h1><p class="muted">${signin?'Welcome back.':'To keep the stories going, feel free to become a member.'}</p><div class="formbox"><label>Email</label><input id="lcEmail" type="email" autocomplete="email" placeholder="you@example.com"><label>Password</label><input id="lcPassword" type="password" autocomplete="${signin?'current-password':'new-password'}" placeholder="${signin?'Password':'Create a password'}">${signin?'':'<label>Display name (optional)</label><input id="lcName" type="text" autocomplete="nickname" placeholder="Anonymous">'}<button class="btn primary" id="lcAuthBtn">${signin?'Sign in':'Become a free member →'}</button><p id="lcAuthMsg" class="note" aria-live="polite"></p><p class="note">It’s completely FREE to join. No subscription. No fees. Just good stories.</p>${signin?'':'<p class="note"><a href="#" id="lcSwitchSignIn">Already a member? Sign in →</a></p>'}</div>`,signin?'signin':'join');
      const btn=document.getElementById('lcAuthBtn'),msg=document.getElementById('lcAuthMsg');
      document.getElementById('lcSwitchSignIn')?.addEventListener('click',e=>{e.preventDefault();authForm(true)});
      btn.onclick=async()=>{
        const email=document.getElementById('lcEmail').value.trim(),password=document.getElementById('lcPassword').value,msgEl=msg;
        if(!email||!password){msgEl.textContent='Please enter your email and password.';return;}
        btn.disabled=true;btn.style.opacity='.65';msgEl.textContent=signin?'Signing you in…':'Creating your free account…';
        try{
          if(signin){
            const r=await sb.auth.signInWithPassword({email,password});
            if(r.error){msgEl.textContent=r.error.message;btn.disabled=false;btn.style.opacity='1';return;}
            msgEl.textContent='You’re in. Welcome to LAST CALL.';setTimeout(()=>window.closePanel?.(),500);return;
          }
          const name=document.getElementById('lcName')?.value.trim()||'Anonymous';
          const r=await sb.auth.signUp({email,password,options:{data:{display_name:name},emailRedirectTo:location.origin}});
          if(r.error){
            const raw=r.error.message||'';
            if(/security purposes|rate limit|too many requests/i.test(raw)){
              msgEl.innerHTML='A confirmation email has already been requested for this address. Check your inbox, then <a href="#" id="lcRateSignIn">sign in →</a>';
              document.getElementById('lcRateSignIn')?.addEventListener('click',e=>{e.preventDefault();authForm(true)});
              btn.textContent='Check your email';
              return;
            }
            if(/already registered|already exists|user already/i.test(raw)){
              msgEl.innerHTML='That email is already registered. <a href="#" id="lcExistingSignIn">Sign in →</a>';
              document.getElementById('lcExistingSignIn')?.addEventListener('click',e=>{e.preventDefault();authForm(true)});
              btn.textContent='Sign in →';
              return;
            }
            msgEl.textContent=raw;btn.disabled=false;btn.style.opacity='1';return;
          }
          if(r.data.session){msgEl.textContent='You’re in. Welcome to LAST CALL.';setTimeout(()=>window.closePanel?.(),500);return;}
          msgEl.innerHTML='You’re nearly there. Check your email to confirm your account, then <a href="#" id="lcCreatedSignIn">sign in →</a>';
          document.getElementById('lcCreatedSignIn')?.addEventListener('click',e=>{e.preventDefault();authForm(true)});
          btn.textContent='Check your email';
        }catch(e){msgEl.textContent='Something went wrong. Please try again.';btn.disabled=false;btn.style.opacity='1';}
      };
    }
  }
  ready();
})();

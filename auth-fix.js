(function(){
  const PROD_URL='https://lastcallbar.co';
  function ready(){
    const sb=window.LASTCALL&&window.LASTCALL.sb;
    if(!sb){setTimeout(ready,100);return;}
    const originalOpenPanel=window.openPanel;
    function show(html,type){const p=document.getElementById('panel'),c=document.getElementById('panelContent');if(!p||!c)return;c.innerHTML=html;p.dataset.panel=type||'auth';p.classList.remove('hidden')}
    function messageText(error){
      const raw=error?.message||String(error||'');
      if(/invalid login credentials/i.test(raw))return 'That email or password was not recognised. If you have not confirmed your email yet, check your inbox first.';
      if(/email not confirmed/i.test(raw))return 'Your email is not confirmed yet. Check your inbox, or send yourself a new confirmation email below.';
      if(/redirect.*url|redirect.*not.*allowed|invalid.*redirect/i.test(raw))return 'The confirmation link needs the LAST CALL production address. Please try creating the account again.';
      if(/rate limit|too many requests|security purposes/i.test(raw))return 'We have already sent an email recently. Check your inbox or spam folder, then try again shortly.';
      if(/password.*weak|password.*short/i.test(raw))return 'Choose a stronger password with at least 6 characters.';
      return raw||'Something went wrong. Please try again.';
    }
    window.openPanel=function(type){
      if(type==='join') return authForm(false);
      if(type==='signin') return authForm(true);
      return originalOpenPanel?.(type);
    };
    function confirmationScreen(){
      show('<div class="eyebrow">LAST CALL · Members</div><h1>Email confirmed.</h1><p class="muted">You’re all set. Welcome to LAST CALL.</p><div class="formbox"><p style="font:18px Georgia;color:#f4eddf;line-height:1.6;margin:0 0 16px">Your account is confirmed and ready to use.</p><button class="btn primary" id="lcConfirmedContinue">Continue to LAST CALL →</button></div>','confirmed');
      document.getElementById('lcConfirmedContinue')?.addEventListener('click',()=>{window.history.replaceState({},document.title,PROD_URL+'/');window.closePanel?.()});
    }
    async function handleConfirmation(){
      const hasAuthHash=location.hash.includes('access_token=')||location.hash.includes('type=signup');
      if(!hasAuthHash&&!location.search.includes('auth=confirmed'))return;
      const hashParams=new URLSearchParams(location.hash.replace(/^#/,'') );
      if(hashParams.get('error')){show('<div class="eyebrow">LAST CALL · Members</div><h1>Email confirmation</h1><p class="muted">'+messageText({message:hashParams.get('error_description')||hashParams.get('error')})+'</p><div class="formbox"><button class="btn primary" id="lcBackAuth">BACK TO SIGN IN →</button></div>','auth-error');document.getElementById('lcBackAuth')?.addEventListener('click',()=>authForm(true));return;}
      setTimeout(async()=>{
        const {data}=await sb.auth.getSession();
        if(data?.session){confirmationScreen();window.history.replaceState({},document.title,location.pathname);}
      },300);
    }
    function authForm(signin){
      show(`<div class="eyebrow">LAST CALL · Members</div><h1>${signin?'Sign in':'Become a free member'}</h1><p class="muted">${signin?'Welcome back.':'To keep the stories going, feel free to become a member.'}</p><div class="formbox"><label>Email</label><input id="lcEmail" type="email" autocomplete="email" placeholder="you@example.com"><label>Password</label><input id="lcPassword" type="password" autocomplete="${signin?'current-password':'new-password'}" placeholder="${signin?'Password':'Create a password'}">${signin?'':'<label>Display name (optional)</label><input id="lcName" type="text" autocomplete="nickname" placeholder="Anonymous">'}<button class="btn primary" id="lcAuthBtn">${signin?'Sign in':'Become a free member →'}</button><p id="lcAuthMsg" class="note" aria-live="polite"></p>${signin?'<div style="margin-top:10px"><button class="btn" id="lcForgot">Forgot your password?</button></div>':'<div style="margin-top:10px"><button class="btn" id="lcResend">Resend confirmation email</button></div>'}<p class="note">It’s completely FREE to join. No subscription. No fees. Just good stories.</p>${signin?'<p class="note"><a href="#" id="lcSwitchSignUp">Need an account? Become a free member →</a></p>':'<p class="note"><a href="#" id="lcSwitchSignIn">Already a member? Sign in →</a></p>'}</div>`,signin?'signin':'join');
      const btn=document.getElementById('lcAuthBtn'),msg=document.getElementById('lcAuthMsg');
      document.getElementById('lcSwitchSignIn')?.addEventListener('click',e=>{e.preventDefault();authForm(true)});
      document.getElementById('lcSwitchSignUp')?.addEventListener('click',e=>{e.preventDefault();authForm(false)});
      document.getElementById('lcResend')?.addEventListener('click',async()=>{
        const email=document.getElementById('lcEmail').value.trim();
        if(!email){msg.textContent='Enter your email address first.';return;}
        msg.textContent='Sending a fresh confirmation email…';
        const r=await sb.auth.resend({type:'signup',email,options:{emailRedirectTo:PROD_URL+'/'}});
        msg.textContent=r.error?messageText(r.error):'Confirmation email sent. Check your inbox and spam folder.';
      });
      document.getElementById('lcForgot')?.addEventListener('click',async()=>{
        const email=document.getElementById('lcEmail').value.trim();
        if(!email){msg.textContent='Enter your email address first.';return;}
        msg.textContent='Sending a password reset email…';
        const r=await sb.auth.resetPasswordForEmail(email,{redirectTo:PROD_URL+'/?reset=1'});
        msg.textContent=r.error?messageText(r.error):'Password reset email sent. Check your inbox and follow the link.';
      });
      btn.onclick=async()=>{
        const email=document.getElementById('lcEmail').value.trim(),password=document.getElementById('lcPassword').value;
        if(!email||!password){msg.textContent='Please enter your email and password.';return;}
        btn.disabled=true;btn.style.opacity='.65';msg.textContent=signin?'Signing you in…':'Creating your free account…';
        try{
          if(signin){
            const r=await sb.auth.signInWithPassword({email,password});
            if(r.error){msg.textContent=messageText(r.error);btn.disabled=false;btn.style.opacity='1';return;}
            msg.textContent='You’re in. Welcome to LAST CALL.';setTimeout(()=>window.closePanel?.(),500);return;
          }
          const name=document.getElementById('lcName')?.value.trim()||'Anonymous';
          const r=await sb.auth.signUp({email,password,options:{data:{display_name:name},emailRedirectTo:PROD_URL+'/'}});
          if(r.error){
            msg.textContent=messageText(r.error);
            btn.disabled=false;btn.style.opacity='1';
            if(/already registered|already exists|user already|email not confirmed|rate limit|too many requests|security purposes/i.test(r.error.message||''))btn.textContent='Check your email';
            return;
          }
          if(r.data.session){msg.textContent='You’re in. Welcome to LAST CALL.';setTimeout(()=>window.closePanel?.(),500);return;}
          msg.textContent='Account created. Check your inbox for the LAST CALL confirmation email.';
          btn.textContent='Check your email';
          btn.disabled=false;btn.style.opacity='1';
        }catch(e){msg.textContent=messageText(e);btn.disabled=false;btn.style.opacity='1';}
      };
    }
    sb.auth.onAuthStateChange((event)=>{if(event==='SIGNED_IN'&&(location.hash.includes('access_token=')||location.hash.includes('type=signup'))){confirmationScreen();window.history.replaceState({},document.title,location.pathname)}});
    handleConfirmation();
  }
  ready();
})();

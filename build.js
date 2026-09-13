const fs=require('fs');
const files=['index.html','community.html','messenger.html'];
for(const file of files){
  let html=fs.readFileSync(file,'utf8');
  if(file==='index.html' && !html.includes('id="last-call-live"')){
    html=html.replace('</body>','<script id="last-call-live" src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script><script src="app.js"></script></body>');
  }
  if(file==='index.html' && !html.includes('header-fix.css')){
    html=html.replace('</head>','<link rel="stylesheet" href="header-fix.css"></head>');
  }
  if(!html.includes('site-polish.css')){
    html=html.replace('</head>','<link rel="stylesheet" href="site-polish.css"></head>');
  }
  fs.writeFileSync(file,html);
}
console.log('LAST CALL build integration and visual polish applied');

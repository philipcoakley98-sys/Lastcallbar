const fs=require('fs');
const file='index.html';
let html=fs.readFileSync(file,'utf8');
if(!html.includes('id="last-call-live"')){
  html=html.replace('</body>','<script id="last-call-live" src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script><script src="app.js"></script></body>');
}
if(!html.includes('header-fix.css')){
  html=html.replace('</head>','<link rel="stylesheet" href="header-fix.css"></head>');
}
fs.writeFileSync(file,html);
console.log('LAST CALL build integration applied');

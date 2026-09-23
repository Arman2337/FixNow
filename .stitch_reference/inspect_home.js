const fs = require('fs');
const files = [
  'FixNow_-_Customer_Home__Modern_Dynamic_Utility_.html',
  'FixNow_-_Customer_Home__Editorial_Express_.html',
  'FixNow_-_Customer_Home__Lifestyle_Concierge_.html',
  'FixNow_-_Customer_Service_Discovery.html'
];

for (const f of files) {
  const p = '.stitch_reference/' + f;
  if (!fs.existsSync(p)) continue;
  const html = fs.readFileSync(p, 'utf8');
  console.log('====================================');
  console.log(f);
  console.log('====================================');
  
  // Extract all text inside <header>, <section>, <div> that have titles/labels
  const lines = html.split('\n');
  const interesting = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.match(/<(h[1-6]|header|section|nav|button|p)\b/i) && line.length < 150) {
      interesting.push(line.replace(/<[^>]+>/g, '').trim());
    }
  }
  const filtered = interesting.filter(t => t.length > 0).slice(0, 30);
  console.log(filtered.join('\n'));
}

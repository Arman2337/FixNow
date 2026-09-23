import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const inputPath = 'C:/Users/patel/.gemini/antigravity-ide/brain/eb4f2676-9a20-44e6-a81b-e0c57d001c86/.system_generated/steps/17/output.txt';
  const raw = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const outDir = path.join(process.cwd(), '.stitch_reference');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  console.log(`Processing ${raw.screens.length} screens...`);

  for (const screen of raw.screens) {
    const id = screen.name.split('/').pop();
    const cleanTitle = screen.title.replace(/[^a-zA-Z0-9_-]/g, '_');
    const meta = {
      id,
      title: screen.title,
      width: screen.width,
      height: screen.height,
      deviceType: screen.deviceType,
      screenshotUrl: screen.screenshot?.downloadUrl,
    };
    fs.writeFileSync(path.join(outDir, `${cleanTitle}.json`), JSON.stringify(meta, null, 2));

    if (screen.htmlCode?.downloadUrl) {
      try {
        const res = await fetch(screen.htmlCode.downloadUrl);
        if (res.ok) {
          const html = await res.text();
          fs.writeFileSync(path.join(outDir, `${cleanTitle}.html`), html);
          console.log(`Saved HTML: ${screen.title}`);
        } else {
          console.warn(`HTTP ${res.status} for ${screen.title}`);
        }
      } catch (err: any) {
        console.error(`Failed ${screen.title}: ${err.message}`);
      }
    }
  }
  console.log('All screens processed.');
}

main().catch(console.error);

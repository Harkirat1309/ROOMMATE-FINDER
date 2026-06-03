const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
    const browser = await puppeteer.launch({ headless: 'new' });
    const page = await browser.newPage();
    
    const htmlPath = path.resolve(__dirname, 'viva_print.html');
    await page.goto('file:///' + htmlPath.replace(/\\/g, '/'), { 
        waitUntil: 'domcontentloaded', 
        timeout: 60000 
    });
    
    // Wait a bit for fonts to attempt loading
    await new Promise(r => setTimeout(r, 3000));
    
    await page.pdf({
        path: path.resolve(__dirname, 'ROOOMIE_Viva_Preparation.pdf'),
        format: 'A4',
        printBackground: true,
        margin: { top: '20mm', bottom: '20mm', left: '15mm', right: '15mm' }
    });
    
    await browser.close();
    console.log('PDF created successfully!');
})();

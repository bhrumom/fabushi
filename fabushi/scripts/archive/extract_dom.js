const fs = require('fs');
module.exports = async (page) => {
  const html = await page.content();
  fs.writeFileSync('dom.html', html);
  console.log('DOM written to dom.html');
};

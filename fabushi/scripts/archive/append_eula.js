async function updateDescription(page) {
  const textareas = await page.$$('textarea');
  for (const ta of textareas) {
    const text = await ta.inputValue();
    // Usually the description is the longest text or it is inside a form field labeled "描述"
    // Let's just find the one that has length > 10 and doesn't already have EULA
    const boundingBox = await ta.boundingBox();
    if (boundingBox && boundingBox.height > 100) { 
       if (!text.includes('stdeula')) {
          await ta.fill(text + "\n\nStandard Apple Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/");
          await ta.dispatchEvent('change');
          console.log("Appended EULA to a textbox.");
       }
    }
  }
}

module.exports = async (page) => {
  await updateDescription(page);
};

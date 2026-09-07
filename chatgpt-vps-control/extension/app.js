const sections = {
  Chats: "Open conversations and continue your Fabushi work.",
  "Mini Apps": "Run focused Fabushi mini apps from one consistent application shell.",
  Marketplace: "Discover mini apps and integrations for Fabushi.",
};

const title = document.querySelector("#section-title");
const description = document.querySelector("#section-description");
const buttons = [...document.querySelectorAll("[data-section]")];
const search = document.querySelector("#marketplace-search");

for (const button of buttons) {
  button.addEventListener("click", () => {
    const section = button.dataset.section;
    for (const item of buttons) item.removeAttribute("aria-current");
    button.setAttribute("aria-current", "page");
    title.textContent = section;
    description.textContent = sections[section] ?? "";
    if (section === "Marketplace") search.focus();
  });
}

search.addEventListener("input", () => {
  if (search.value.trim()) {
    title.textContent = "Marketplace";
    description.textContent = `Searching for “${search.value.trim()}”`;
  }
});

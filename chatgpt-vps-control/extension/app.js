const sections = {
  Chats: "Open conversations and continue your Fabushi work.",
  "Mini Apps": "Run focused Fabushi mini apps from one consistent application shell.",
  Marketplace: "Discover mini apps and integrations for Fabushi.",
};

const MARKETPLACE_SECTION = "Marketplace";

const marketplaceCatalog = [
  {
    id: "userscript-chatgpt-control",
    name: "ChatGPT Control Userscript",
    description: "Run Fabushi browser-control automation directly in supported ChatGPT tabs.",
    kind: "userscript",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["chrome-extension"],
    tags: ["ChatGPT", "automation", "userscript"],
  },
  {
    id: "desktop-device-control",
    name: "Device Control",
    description: "Manage Fabushi devices from desktop application builds.",
    kind: "mini-app",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["desktop"],
    tags: ["device", "desktop"],
  },
  {
    id: "mobile-companion",
    name: "Mobile Companion",
    description: "Mobile-only companion mini app.",
    kind: "mini-app",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["ios", "android"],
    tags: ["mobile"],
  },
];

const title = document.querySelector("#section-title");
const description = document.querySelector("#section-description");
const buttons = [...document.querySelectorAll("[data-section]")];
const search = document.querySelector("#marketplace-search");
const marketplaceView = document.querySelector("#marketplace-view");
const marketplaceList = document.querySelector("#marketplace-list");
const marketplaceCount = document.querySelector("#marketplace-count");
const marketplacePlatform = document.querySelector("#marketplace-platform");
const currentPlatform = document.body.dataset.platform || "unknown";

marketplacePlatform.textContent = currentPlatform;

function normalizedSearchText(item) {
  return [item.name, item.description, item.kind, ...item.platforms, ...item.tags].join(" ").toLowerCase();
}

function isVisibleInMarketplace(item) {
  if (!item.surfaces.includes(MARKETPLACE_SECTION)) return false;
  if (!item.platforms.includes(currentPlatform)) return false;
  if (item.kind === "userscript") {
    return currentPlatform === "chrome-extension" && item.surfaces.length === 1;
  }
  return true;
}

function getVisibleMarketplaceItems(query = "") {
  const normalizedQuery = query.trim().toLowerCase();
  return marketplaceCatalog.filter((item) => {
    const queryMatches = !normalizedQuery || normalizedSearchText(item).includes(normalizedQuery);
    return isVisibleInMarketplace(item) && queryMatches;
  });
}

function renderMarketplace(query = "") {
  const visibleItems = getVisibleMarketplaceItems(query);
  marketplaceList.replaceChildren();

  for (const item of visibleItems) {
    const card = document.createElement("article");
    card.className = "marketplace-card";
    card.dataset.kind = item.kind;
    card.dataset.platforms = item.platforms.join(",");

    const heading = document.createElement("h3");
    heading.textContent = item.name;

    const body = document.createElement("p");
    body.textContent = item.description;

    const badges = document.createElement("div");
    badges.className = "badges";
    for (const badgeText of [item.kind, ...item.tags]) {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = badgeText;
      badges.append(badge);
    }

    card.append(heading, body, badges);
    marketplaceList.append(card);
  }

  if (visibleItems.length === 0) {
    const empty = document.createElement("p");
    empty.className = "marketplace-empty";
    empty.textContent = "No Marketplace items match this search on this platform.";
    marketplaceList.append(empty);
  }

  marketplaceCount.textContent = `${visibleItems.length} ${visibleItems.length === 1 ? "result" : "results"}`;
}

function activateSection(section) {
  for (const item of buttons) {
    if (item.dataset.section === section) item.setAttribute("aria-current", "page");
    else item.removeAttribute("aria-current");
  }

  title.textContent = section;
  description.textContent = sections[section] ?? "";
  const isMarketplace = section === MARKETPLACE_SECTION;
  marketplaceView.hidden = !isMarketplace;
  if (isMarketplace) {
    renderMarketplace(search.value);
    search.focus();
  }
}

for (const button of buttons) {
  button.addEventListener("click", () => activateSection(button.dataset.section));
}

search.addEventListener("input", () => {
  activateSection(MARKETPLACE_SECTION);
  const query = search.value.trim();
  description.textContent = query
    ? `Searching Marketplace for “${query}” on ${currentPlatform}.`
    : sections.Marketplace;
});

renderMarketplace();

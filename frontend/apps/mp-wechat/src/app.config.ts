export default defineAppConfig({
  pages: [
    "pages/index/index",
    "pages/sutra/index",
    "pages/practice/index",
    "pages/ai/index",
    "pages/me/index",
  ],
  window: {
    backgroundTextStyle: "light",
    navigationBarBackgroundColor: "#101419",
    navigationBarTitleText: "法布施",
    navigationBarTextStyle: "white",
    backgroundColor: "#080b10",
  },
  tabBar: {
    color: "#8f9a9a",
    selectedColor: "#e8bd6b",
    backgroundColor: "#101419",
    borderStyle: "black",
    list: [
      { pagePath: "pages/index/index", text: "首页" },
      { pagePath: "pages/sutra/index", text: "经文" },
      { pagePath: "pages/practice/index", text: "修行" },
      { pagePath: "pages/ai/index", text: "AI" },
      { pagePath: "pages/me/index", text: "我的" },
    ],
  },
});

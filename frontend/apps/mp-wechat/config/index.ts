import type { UserConfigExport } from "@tarojs/cli";

export default {
  projectName: "fabushi-mp-wechat",
  date: "2026-05-06",
  designWidth: 375,
  deviceRatio: {
    375: 2,
    750: 1,
  },
  sourceRoot: "src",
  outputRoot: "dist",
  framework: "react",
  compiler: {
    type: "webpack5",
  },
  plugins: [],
  mini: {
    postcss: {
      pxtransform: {
        enable: true,
        config: {},
      },
      cssModules: {
        enable: false,
      },
    },
  },
  h5: {
    publicPath: "/",
    staticDirectory: "static",
  },
} satisfies UserConfigExport;

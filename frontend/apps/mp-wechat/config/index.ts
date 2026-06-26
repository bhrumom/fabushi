import type { UserConfigExport } from "@tarojs/cli";
import path from "node:path";

const workspaceSourcePaths = [
  path.resolve(__dirname, "../../../packages/shared/src"),
  path.resolve(__dirname, "../../../packages/api-client/src"),
  path.resolve(__dirname, "../node_modules/@fabushi/shared/src"),
  path.resolve(__dirname, "../node_modules/@fabushi/api-client/src"),
];

export default {
  projectName: "fabushi-mp-wechat",
  date: "2026-05-06",
  designWidth: 750,
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
    compile: {
      include: workspaceSourcePaths,
    },
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

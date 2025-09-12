// Webpack 配置用于优化桌面应用性能

const path = require('path');

module.exports = {
  mode: 'production',
  entry: './main.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'main.bundle.js',
  },
  target: 'electron-main',
  optimization: {
    // 代码分割
    splitChunks: {
      chunks: 'all',
    },
    // 压缩代码
    minimize: true,
  },
  resolve: {
    extensions: ['.js', '.json'],
  },
  performance: {
    maxAssetSize: 1000000, // 1MB
    maxEntrypointSize: 1000000, // 1MB
  },
};
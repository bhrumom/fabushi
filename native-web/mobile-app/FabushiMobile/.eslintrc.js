module.exports = {
  root: true,
  extends: '@react-native',
  rules: {
    // 性能优化规则
    'no-console': ['warn', { allow: ['warn', 'error'] }],
    'no-unused-vars': 'error',
    'no-duplicate-imports': 'error',
    'prefer-const': 'error',
    
    // React Native 特定规则
    'react-native/no-unused-styles': 'error',
    'react-native/no-inline-styles': 'warn',
    'react-native/no-color-literals': 'warn',
    'react-native/sort-styles': 'off',
    
    // 代码质量规则
    'complexity': ['warn', 10],
    'max-lines-per-function': ['warn', 50],
    'max-depth': ['warn', 4],
    'max-params': ['warn', 4],
  },
};
module.exports = {
  root: true,
  extends: '@react-native',
  ignorePatterns: [
    'lib/',
    '.test-dist/',
    'coverage/',
    'example/',
    'android/generated/',
    'ios/generated/',
    'appletvos/generated/',
    'macos/generated/',
    'windows/FFmpegKitExtended/codegen/',
  ],
  overrides: [
    {
      files: [
        '*.config.js',
        '.eslintrc.js',
        'react-native.config.js',
        'scripts/**/*.js',
        'tests/**/*.js',
      ],
      parser: 'espree',
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'script',
      },
      env: {
        node: true,
      },
    },
  ],
};

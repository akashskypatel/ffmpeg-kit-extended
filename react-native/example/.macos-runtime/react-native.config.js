const path = require('path');

module.exports = {
  project: {
    ios: {
      sourceDir: path.resolve(__dirname, '../macos'),
    },
    macos: {
      sourceDir: path.resolve(__dirname, '../macos'),
    },
  },
};

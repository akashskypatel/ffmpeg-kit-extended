const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'ios', 'generated');
const destination = path.join(root, 'appletvos', 'generated');

if (!fs.existsSync(source)) {
  throw new Error(`iOS Codegen output was not found: ${source}`);
}

fs.rmSync(destination, {recursive: true, force: true});
fs.cpSync(source, destination, {recursive: true});

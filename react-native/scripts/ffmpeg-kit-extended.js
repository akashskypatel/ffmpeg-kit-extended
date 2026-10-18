#!/usr/bin/env node
'use strict';

const command = process.argv[2];

if (command === 'prepare-web') {
  const {main} = require('./prepare-web.js');
  main(process.argv.slice(3)).catch(error => {
    console.error(error.message || String(error));
    process.exitCode = 1;
  });
} else {
  console.error('Usage: ffmpeg-kit-extended prepare-web [options]');
  process.exitCode = 1;
}

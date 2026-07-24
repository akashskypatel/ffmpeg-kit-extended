'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  ReturnCode,
  isCancelReturnCode,
  isSuccessReturnCode,
} = require('../.test-dist/types.js');

test('return-code helpers recognize success and cancellation only', () => {
  assert.equal(isSuccessReturnCode(ReturnCode.Success), true);
  assert.equal(isSuccessReturnCode(ReturnCode.Cancel), false);
  assert.equal(isCancelReturnCode(ReturnCode.Cancel), true);
  assert.equal(isCancelReturnCode(ReturnCode.Success), false);
  assert.equal(isSuccessReturnCode(1), false);
  assert.equal(isCancelReturnCode(1), false);
});

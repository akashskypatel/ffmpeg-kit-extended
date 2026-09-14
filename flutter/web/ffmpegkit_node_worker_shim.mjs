import {isMainThread, parentPort} from 'node:worker_threads';

if (!isMainThread) {
  globalThis.WorkerGlobalScope = class WorkerGlobalScope {};
  globalThis.self = globalThis;
  globalThis.name = 'em-pthread';
  globalThis.postMessage = (value, transferList) =>
    parentPort.postMessage(value, transferList);
  parentPort.on('message', (data) => {
    globalThis.onmessage?.({data});
  });
}

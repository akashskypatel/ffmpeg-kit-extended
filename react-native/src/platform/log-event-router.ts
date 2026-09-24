import {getBackend} from './backend-registry';
import type {
  LogEvent,
  LogEventHandler,
  LogEventSubscription,
} from './backend-registry';

type SessionHandlers = Set<LogEventHandler>;

const handlersBySession = new Map<number, SessionHandlers>();
let backendSubscription: LogEventSubscription | undefined;
let subscribedBackend: ReturnType<typeof getBackend> | undefined;

function route(event: LogEvent): void {
  const handlers = handlersBySession.get(event.sessionId);
  if (!handlers) return;

  // A native event emitter must never receive a user callback exception back
  // across the bridge. Session handlers normally record the error themselves;
  // this guard also protects the transport if a future handler fails before it
  // reaches the session's first-error authority.
  for (const handler of [...handlers]) {
    try {
      handler(event);
    } catch {
      // The session monitor remains the lifecycle/error authority.
    }
  }
}

function ensureBackendSubscription(): boolean {
  const backend = getBackend();
  if (typeof backend.onLogEvent !== 'function') return false;
  if (subscribedBackend === backend && backendSubscription) return true;

  backendSubscription?.remove();
  backendSubscription = backend.onLogEvent(route);
  subscribedBackend = backend;
  return true;
}

/** Registers one session sink on the process-wide v2 log event stream. */
export function subscribeLogEvents(
  sessionId: number,
  handler: LogEventHandler,
): LogEventSubscription {
  if (!ensureBackendSubscription()) return {remove: () => {}};

  let handlers = handlersBySession.get(sessionId);
  if (!handlers) {
    handlers = new Set<LogEventHandler>();
    handlersBySession.set(sessionId, handlers);
  }
  handlers.add(handler);

  let removed = false;
  return {
    remove: () => {
      if (removed) return;
      removed = true;
      const current = handlersBySession.get(sessionId);
      if (!current) return;
      current.delete(handler);
      if (current.size === 0) handlersBySession.delete(sessionId);
    },
  };
}

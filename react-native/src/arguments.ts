/**
 * Formats an argv-style array as a command string accepted by FFmpegKit.
 * This intentionally performs only shell-style quoting; the native FFmpegKit
 * parser remains the authority when the command is executed.
 */
export function argumentsToString(arguments_: readonly string[]): string {
  return arguments_.map(quoteArgument).join(' ');
}

/**
 * Parses the common quoting/escaping forms used in FFmpegKit command strings.
 * It is deliberately small and deterministic rather than trying to emulate a
 * platform shell.
 */
export function parseArguments(command: string): string[] {
  const result: string[] = [];
  let current = '';
  let quote: '"' | "'" | undefined;
  let escaped = false;
  let tokenStarted = false;

  for (const char of command) {
    if (escaped) {
      current += char;
      escaped = false;
      tokenStarted = true;
      continue;
    }

    if (char === '\\' && quote !== "'") {
      escaped = true;
      tokenStarted = true;
      continue;
    }

    if (quote) {
      if (char === quote) {
        quote = undefined;
      } else {
        current += char;
      }
      tokenStarted = true;
      continue;
    }

    if (char === '"' || char === "'") {
      quote = char;
      tokenStarted = true;
      continue;
    }

    if (/\s/.test(char)) {
      if (tokenStarted) {
        result.push(current);
        current = '';
        tokenStarted = false;
      }
      continue;
    }

    current += char;
    tokenStarted = true;
  }

  if (escaped) current += '\\';
  if (tokenStarted) result.push(current);
  return result;
}

function quoteArgument(value: string): string {
  if (value.length === 0) return '""';
  if (!/[\s"'\\]/.test(value)) return value;
  return `"${value.replace(/(["\\])/g, '\\$1')}"`;
}

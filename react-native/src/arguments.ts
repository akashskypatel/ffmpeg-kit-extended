/**
 * Formats an argv-style array as one FFmpegKit command string.
 *
 * This representation is intended for display and compatibility string APIs.
 * Prefer argument-array session constructors when arguments are already
 * tokenized. Values requiring grouping are single-quoted so backslashes and
 * double quotes remain literal. Embedded single quotes are emitted as adjacent
 * quoted/unquoted segments that the native compatibility parser round-trips.
 */
export function argumentsToString(arguments_: readonly string[]): string {
  return arguments_.map(quoteArgument).join(' ');
}

/**
 * Splits an FFmpegKit compatibility command string into argument tokens.
 *
 * Single and double quotes group whitespace. Ordinary backslashes are literal
 * so Windows drive and UNC paths survive unchanged. A backslash only escapes a
 * quote, or unquoted whitespace. Empty quoted arguments are preserved.
 */
export function parseArguments(command: string): string[] {
  const result: string[] = [];
  let current = '';
  let quote: '"' | "'" | undefined;
  let tokenStarted = false;

  for (let i = 0; i < command.length; i += 1) {
    const char = command[i];

    if (quote === "'") {
      if (char === "'") quote = undefined;
      else current += char;
      tokenStarted = true;
      continue;
    }

    if (char === '\\' && i + 1 < command.length) {
      const next = command[i + 1];
      const escapedQuote = next === '"' || (!quote && next === "'");
      const escapedWhitespace = !quote && /\s/.test(next);
      if (escapedQuote || escapedWhitespace) {
        current += next;
        tokenStarted = true;
        i += 1;
        continue;
      }
    }

    if (quote) {
      if (char === quote) quote = undefined;
      else current += char;
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

  if (tokenStarted) result.push(current);
  return result;
}

function quoteArgument(value: string): string {
  if (value.length === 0) return "''";
  if (!/[\s"']/.test(value)) return value;
  return `'${value.replace(/'/g, "'\\''")}'`;
}

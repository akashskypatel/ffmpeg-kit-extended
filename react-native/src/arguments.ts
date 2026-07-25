/**
 * Formats an argv-style array as one FFmpegKit command string.
 *
 * Use this when arguments are already separated by your application. Values
 * containing whitespace, quotes, or backslashes are quoted and escaped so they
 * remain one token when FFmpegKit parses the command. This does not invoke the
 * device shell and does not perform shell expansion, environment substitution,
 * globbing, pipes, or redirection.
 *
 * @param arguments_ Arguments in the same order they would appear in `argv`.
 * @returns A command string suitable for `FFmpegKit.createSession()` or
 * `FFmpegKit.executeAsync()`.
 *
 * @example
 * ```ts
 * argumentsToString(['-i', '/media/My Clip.mp4', '-c:v', 'libx264']);
 * // -i "/media/My Clip.mp4" -c:v libx264
 * ```
 */
export function argumentsToString(arguments_: readonly string[]): string {
  return arguments_.map(quoteArgument).join(' ');
}

/**
 * Splits an FFmpegKit command string into argument tokens.
 *
 * Single and double quotes group whitespace. Backslashes escape the following
 * character except inside single quotes. Quote characters are removed from the
 * returned values. The parser is intentionally platform-neutral and does not
 * attempt to emulate Bash, PowerShell, `cmd.exe`, or any other shell.
 *
 * @param command FFmpeg/FFprobe/FFplay command text without the executable name.
 * @returns Parsed arguments. Blank or whitespace-only input returns an empty
 * array.
 *
 * @example
 * ```ts
 * parseArguments('-i "My Clip.mp4" -map 0:v:0');
 * // ['-i', 'My Clip.mp4', '-map', '0:v:0']
 * ```
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

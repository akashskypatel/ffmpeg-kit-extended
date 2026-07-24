module.exports = {
  project: {
    // Avoid loading the React Native Windows CLI on macOS/Linux, where its
    // environment probes invoke Windows-only commands such as dotnet.exe/where.
    windows: process.platform === 'win32' ? {} : null,
  },
};

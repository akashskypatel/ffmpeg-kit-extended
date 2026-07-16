/** @type {import('@react-native-community/cli-types').UserDependencyConfig} */
module.exports = {
  dependency: {
    platforms: {
      android: {
        cmakeListsPath: 'generated/jni/CMakeLists.txt',
        cxxModuleCMakeListsModuleName: 'react_native_ffmpeg_kit_extended',
        cxxModuleCMakeListsPath: 'CMakeLists.txt',
        cxxModuleHeaderName: 'FFmpegKitExtendedImpl',
      },
    },
  },
};

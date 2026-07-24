/** @type {import('@react-native-community/cli-types').UserDependencyConfig} */
module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: 'android',
        packageImportPath:
          'import com.akashskypatel.ffmpegkitextended.FFmpegKitExtendedPackage;',
        packageInstance: 'new FFmpegKitExtendedPackage()',
        cxxModuleCMakeListsModuleName: 'react_native_ffmpeg_kit_extended',
        cxxModuleCMakeListsPath: 'CMakeLists.txt',
        cxxModuleHeaderName: 'FFmpegKitExtendedImpl',
      },
      windows: {
        sourceDir: 'windows',
        solutionFile: 'FFmpegKitExtended.sln',
        projects: [
          {
            projectFile: 'FFmpegKitExtended/FFmpegKitExtended.vcxproj',
            directDependency: true,
            cppHeaders: ['winrt/FFmpegKitExtended.h'],
            cppPackageProviders: ['FFmpegKitExtended::ReactPackageProvider'],
          },
        ],
      },
    },
  },
};

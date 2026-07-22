#!/usr/bin/env python3
"""Patch an isolated react-native-skia checkout for FFmpegKitExtended Linux."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


MARKER = "FFmpegKitExtended Linux integration"


def prepare_native_source(runtime_root: Path, project_root: Path) -> None:
    destination = runtime_root / "third_party" / "ffmpeg-kit-extended"
    if destination.is_symlink() or destination.is_file():
        destination.unlink()
    elif destination.exists():
        shutil.rmtree(destination)

    (destination / "cpp").mkdir(parents=True)
    (destination / "linux").mkdir(parents=True)

    for filename in ("FFmpegKitDynamicApi.cpp", "FFmpegKitDynamicApi.h"):
        shutil.copy2(project_root / "cpp" / filename, destination / "cpp" / filename)

    for source in (project_root / "linux").iterdir():
        if source.suffix in {".cpp", ".h"}:
            shutil.copy2(source, destination / "linux" / source.name)


def patch_build(runtime_root: Path) -> None:
    path = runtime_root / "ReactSkia" / "BUILD.gn"
    text = path.read_text()
    if f"# {MARKER} sources" not in text:
        needle = '    "pluginfactory/RnsPluginFactory.h",\n'
        replacement = needle + f'''\n    # {MARKER} sources\n    "//third_party/ffmpeg-kit-extended/cpp/FFmpegKitDynamicApi.cpp",\n    "//third_party/ffmpeg-kit-extended/linux/FFmpegKitExtendedTurboModule.cpp",\n    "//third_party/ffmpeg-kit-extended/linux/FFplayViewComponent.cpp",\n    "//third_party/ffmpeg-kit-extended/linux/FFplayViewComponentProvider.cpp",\n'''
        if needle not in text:
            raise RuntimeError(f"ReactSkia source-list anchor not found in {path}")
        text = text.replace(needle, replacement, 1)

    if f"# {MARKER} libdl" not in text:
        needle = '  if (is_linux) {\n    configs += ["//third_party/nopoll:nopoll_from_pkgconfig"]\n  }'
        replacement = f'''  if (is_linux) {{\n    configs += ["//third_party/nopoll:nopoll_from_pkgconfig"]\n    # {MARKER} libdl\n    libs = [ "dl" ]\n  }}'''
        if needle not in text:
            raise RuntimeError(f"ReactSkia Linux config anchor not found in {path}")
        text = text.replace(needle, replacement, 1)

    path.write_text(text)


def patch_turbo_module_registry(runtime_root: Path) -> None:
    path = runtime_root / "ReactSkia" / "JSITurboModuleManager.cpp"
    text = path.read_text()

    include = (
        '#include "third_party/ffmpeg-kit-extended/linux/'
        'FFmpegKitExtendedTurboModule.h"'
    )
    if include not in text:
        needle = '#include "JSITurboModuleManager.h"\n'
        if needle not in text:
            raise RuntimeError(f"TurboModule include anchor not found in {path}")
        text = text.replace(needle, needle + include + "\n", 1)

    registration = '''  // FFmpegKitExtended Linux integration TurboModule\n  modules_["FFmpegKitExtended"] =\n      std::make_shared<FFmpegKitExtendedTurboModule>(\n          "FFmpegKitExtended", jsInvoker);\n\n'''
    if registration not in text:
        needle = '  modules_["DevSettings"] =\n'
        if needle not in text:
            raise RuntimeError(f"TurboModule registration anchor not found in {path}")
        text = text.replace(needle, registration + needle, 1)

    path.write_text(text)


def patch_component_registry(runtime_root: Path) -> None:
    path = runtime_root / "ReactSkia" / "RNInstance.cpp"
    text = path.read_text()

    include = (
        '#include "third_party/ffmpeg-kit-extended/linux/'
        'FFplayViewComponentProvider.h"'
    )
    if include not in text:
        needle = '#include "ReactSkia/platform/common/RuntimeEventBeat.h"\n'
        if needle not in text:
            raise RuntimeError(f"Component include anchor not found in {path}")
        text = text.replace(needle, needle + include + "\n", 1)

    registration = '''  // FFmpegKitExtended Linux integration Fabric component\n  componentViewRegistry_->Register(\n      std::make_unique<FFplayViewComponentProvider>());\n'''
    if registration not in text:
        needle = '''  componentViewRegistry_->Register(\n      std::make_unique<RSkComponentProviderActivityIndicator>());\n'''
        if needle not in text:
            raise RuntimeError(f"Component registration anchor not found in {path}")
        text = text.replace(needle, needle + registration, 1)

    path.write_text(text)


def prepare_example_source(runtime_root: Path, project_root: Path) -> None:
    package_root = runtime_root / "packages" / "react-native-skia"
    generated = package_root / "ffmpeg-kit-extended-example"
    if generated.exists():
        shutil.rmtree(generated)
    (generated / "src").mkdir(parents=True)

    shutil.copy2(project_root / "example" / "App.linux.tsx", generated / "App.linux.tsx")
    shutil.copy2(
        project_root / "example" / "src" / "ExampleApp.tsx",
        generated / "src" / "ExampleApp.tsx",
    )
    shutil.copy2(
        project_root / "example" / "src" / "ExamplePlatform.linux.ts",
        generated / "src" / "ExamplePlatform.linux.ts",
    )

    entry = package_root / "FFmpegKitExtendedExample.js"
    entry.write_text(
        "import {AppRegistry} from 'react-native';\n"
        "import App from './ffmpeg-kit-extended-example/App.linux';\n\n"
        "AppRegistry.registerComponent('SimpleViewApp', () => App);\n"
    )


def install_local_package(runtime_root: Path, package_archive: Path) -> None:
    package_dir = runtime_root / "node_modules" / "ffmpeg-kit-extended"
    if package_dir.exists() or package_dir.is_symlink():
        if package_dir.is_symlink() or package_dir.is_file():
            package_dir.unlink()
        else:
            shutil.rmtree(package_dir)
    package_dir.mkdir(parents=True)

    shutil.unpack_archive(str(package_archive), str(package_dir), format="gztar")
    nested = package_dir / "package"
    if nested.is_dir():
        for child in nested.iterdir():
            shutil.move(str(child), package_dir / child.name)
        nested.rmdir()

    # React Native 0.71 does not expose codegenNativeComponent as a top-level
    # react-native named export. Keep this compatibility edit isolated to the
    # generated Linux runtime package rather than changing the package source
    # used by the newer Android/Apple/Windows runtimes.
    native_component = package_dir / "src" / "FFplayViewNativeComponent.ts"
    text = native_component.read_text()
    old = "import {\n  codegenNativeComponent,\n} from 'react-native';\n"
    new = (
        "import codegenNativeComponent from "
        "'react-native/Libraries/Utilities/codegenNativeComponent';\n"
    )
    if old not in text:
        raise RuntimeError(
            "Expected FFplayViewNativeComponent codegen import was not found in local package"
        )
    native_component.write_text(text.replace(old, new, 1))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("runtime_root", type=Path)
    parser.add_argument("project_root", type=Path)
    parser.add_argument("package_archive", type=Path)
    args = parser.parse_args()

    runtime_root = args.runtime_root.resolve()
    project_root = args.project_root.resolve()
    package_archive = args.package_archive.resolve()

    prepare_native_source(runtime_root, project_root)
    patch_build(runtime_root)
    patch_turbo_module_registry(runtime_root)
    patch_component_registry(runtime_root)
    prepare_example_source(runtime_root, project_root)
    install_local_package(runtime_root, package_archive)


if __name__ == "__main__":
    main()

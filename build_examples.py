#!/usr/bin/env python3
"""Build and archive the supported Flutter and React Native examples."""

from __future__ import annotations

import argparse
import itertools
import json
import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid
import zipfile
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
FRAMEWORKS = ("flutter", "react-native")
PLATFORMS = ("windows", "linux", "ios", "android", "macos", "appletvos", "web")
BUNDLES = ("audio", "video", "video_hw", "debug", "base", "full")
LICENSES = ("gpl", "lgpl")
SIZES = ("small", "standard")
RELEASE_TYPES = ("release", "debug")
BUNDLE_SIZE_EXCLUSIONS = {
    ("debug", "small"): "debug bundle with small size is unsupported on all platforms",
}
PLATFORM_BUNDLE_EXCLUSIONS = {
    ("web", "debug"): "the prebuilt Web/Wasm debug bundle is not browser-compatible",
}

FRAMEWORK_PLATFORMS = {
    "flutter": frozenset({"windows", "linux", "ios", "android", "macos", "web"}),
    "react-native": frozenset({"windows", "ios", "android", "macos", "appletvos", "web"}),
}
PLATFORM_HOSTS = {
    "windows": "win32",
    "linux": "linux",
    "ios": "darwin",
    "macos": "darwin",
    "appletvos": "darwin",
}


class AppendCsv(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        current = getattr(namespace, self.dest, None) or []
        setattr(namespace, self.dest, [*current, values])


class BuildHelpFormatter(argparse.RawDescriptionHelpFormatter):
    def __init__(self, prog: str):
        super().__init__(prog, width=100, max_help_position=32)


def selections(values: list[str], flags: list[str], allowed: tuple[str, ...], name: str) -> list[str]:
    selected: list[str] = []
    for value in [*values, *flags]:
        for item in value.split(","):
            item = item.strip().lower()
            if name == "platform" and item == "wasm":
                item = "web"
            if not item:
                raise ValueError(f"Empty value in {name} selection {value!r}.")
            if item not in allowed:
                raise ValueError(f"Unsupported {name} {item!r}; choose from: {', '.join(allowed)}.")
            if item not in selected:
                selected.append(item)
    return selected or list(allowed)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        usage="%(prog)s [selectors] [--output-dir DIR] [--zip] [--dry-run]",
        description=(
            "Build Flutter and React Native example apps from temporary copies.\n"
            "Each successful combination is staged as an output directory; use --zip to archive it."
        ),
        formatter_class=BuildHelpFormatter,
        epilog="""\
Defaults when a selector is omitted:
  frameworks: flutter and react-native     platforms: all listed platforms
  bundles: all listed bundles              licenses: gpl and lgpl
  sizes: small and standard                app build mode: release

Framework/platform support:
  flutter       windows, linux, ios, android, macos, web (WASM)
  react-native  windows, ios, android, macos, appletvos, web (WASM)

Host requirements: Windows builds run on Windows, Linux builds on Linux, and Apple builds on
macOS. Web/WASM builds run on any host. Unsupported framework/platform pairs and targets
requiring another host are skipped.

The debug bundle cannot be combined with small size on any platform; those variants are skipped.
The prebuilt debug bundle is not browser-compatible and is skipped for Web/WASM builds.
--debug selects both the debug bundle and debug app mode. Use --bundle=debug or
--release_type=debug when only one should be selected.

With --zip, each archive is named:
  <framework>-<platform>-<bundle>-<size>-<license>-<release_type>.zip
Without --zip, each staged output directory uses the same name without the .zip suffix.

Examples:
  python build_examples.py --flutter --android --bundle=base --lgpl --small --zip
  python build_examples.py --framework=flutter,react-native --platform=android,web --dry-run
""",
    )
    framework_group = parser.add_argument_group("Framework")
    framework_group.add_argument("--framework", action=AppendCsv, default=[], metavar="CSV", help="Comma-separated: flutter, react-native (default: both).")
    framework_group.add_argument("--flutter", action="store_true", help="Shortcut to select Flutter.")
    framework_group.add_argument("--react-native", dest="react_native", action="store_true", help="Shortcut to select React Native.")

    platform_group = parser.add_argument_group("Platform")
    platform_group.add_argument("--platform", action=AppendCsv, default=[], metavar="CSV", help="Comma-separated: windows, linux, ios, android, macos, appletvos, web/wasm (default: all).")
    platform_group.add_argument("--windows", dest="platform_flags", action="append_const", const="windows", default=[], help="Select Windows.")
    platform_group.add_argument("--linux", dest="platform_flags", action="append_const", const="linux", help="Select Linux.")
    platform_group.add_argument("--ios", dest="platform_flags", action="append_const", const="ios", help="Select iOS.")
    platform_group.add_argument("--android", dest="platform_flags", action="append_const", const="android", help="Select Android.")
    platform_group.add_argument("--macos", dest="platform_flags", action="append_const", const="macos", help="Select macOS.")
    platform_group.add_argument("--appletvos", dest="platform_flags", action="append_const", const="appletvos", help="Select Apple tvOS.")
    platform_group.add_argument("--web", "--wasm", dest="platform_flags", action="append_const", const="web", help="Select Web/WASM.")

    bundle_group = parser.add_argument_group("Bundle type")
    bundle_group.add_argument("--bundle", action=AppendCsv, default=[], metavar="CSV", help="Comma-separated: audio, video, video_hw, debug, base, full (default: all).")
    for bundle in BUNDLES:
        if bundle != "debug":
            aliases = [f"--{bundle}"]
            if "_" in bundle:
                aliases.append(f"--{bundle.replace('_', '-')}")
            bundle_group.add_argument(*aliases, dest="bundle_flags", action="append_const", const=bundle, help=f"Select the {bundle} bundle.")

    license_group = parser.add_argument_group("License")
    license_group.add_argument("--license", action=AppendCsv, default=[], metavar="CSV", help="Comma-separated: gpl, lgpl (default: both).")
    license_group.add_argument("--gpl", dest="license_flags", action="append_const", const="gpl", default=[], help="Select GPL.")
    license_group.add_argument("--lgpl", dest="license_flags", action="append_const", const="lgpl", help="Select LGPL.")

    size_group = parser.add_argument_group("Bundle size")
    size_group.add_argument("--size", action=AppendCsv, default=[], metavar="CSV", help="Comma-separated: small, standard (default: both).")
    size_group.add_argument("--small", dest="size_flags", action="append_const", const="small", default=[], help="Select small.")
    size_group.add_argument("--standard", dest="size_flags", action="append_const", const="standard", help="Select standard size.")

    mode_group = parser.add_argument_group("App build mode")
    mode_group.add_argument("--release_type", "--release-type", dest="release_type", action=AppendCsv, default=[], metavar="CSV", help="Comma-separated: release, debug (default: release).")
    mode_group.add_argument("--release", dest="release_flags", action="append_const", const="release", default=[], help="Select release app builds.")
    mode_group.add_argument(
        "--debug",
        dest="debug_alias",
        action="store_true",
        help="Select both the debug bundle and debug app builds.",
    )

    output_group = parser.add_argument_group("Output")
    output_group.add_argument("--output-dir", type=Path, default=ROOT / "builds", metavar="DIR", help="Directory for staged outputs (default: builds/ beside this script).")
    output_group.add_argument("--zip", dest="zip_output", action="store_true", help="Package each build output as a ZIP archive instead of a directory.")
    output_group.add_argument("--dry-run", action="store_true", help="List compatible build commands without running them.")
    args = parser.parse_args()
    try:
        args.frameworks = selections(args.framework, [*(["flutter"] if args.flutter else []), *(["react-native"] if args.react_native else [])], FRAMEWORKS, "framework")
        args.platforms = selections(args.platform, args.platform_flags, PLATFORMS, "platform")
        args.bundles = selections(args.bundle, (args.bundle_flags or []) + (["debug"] if args.debug_alias else []), BUNDLES, "bundle")
        args.licenses = selections(args.license, args.license_flags, LICENSES, "license")
        args.sizes = selections(args.size, args.size_flags, SIZES, "size")
        release_values = args.release_type + args.release_flags + (["debug"] if args.debug_alias else [])
        args.release_types = selections(release_values, [], RELEASE_TYPES, "release_type") if release_values else ["release"]
    except ValueError as error:
        parser.error(str(error))
    return args


@dataclass(frozen=True)
class Build:
    framework: str
    platform: str
    bundle: str
    size: str
    license: str
    release_type: str

    @property
    def filename(self) -> str:
        return (
            f"{self.framework}-{self.platform}-{self.bundle}-{self.size}-"
            f"{self.license}-{self.release_type}.zip"
        )


def output_name(build: Build, zip_output: bool) -> str:
    return build.filename if zip_output else build.filename.removesuffix(".zip")


@dataclass(frozen=True)
class Artifact:
    path: Path
    archive_path: str


def host_matches(platform: str) -> bool:
    required = PLATFORM_HOSTS.get(platform)
    return required is None or sys.platform == required or (required == "linux" and sys.platform.startswith("linux"))


def build_matrix(args: argparse.Namespace) -> tuple[list[Build], dict[str, int]]:
    builds: list[Build] = []
    skipped: dict[str, int] = {}
    for framework, platform in itertools.product(args.frameworks, args.platforms):
        if platform not in FRAMEWORK_PLATFORMS[framework]:
            reason = f"{framework}/{platform}: unsupported by this example"
        elif not host_matches(platform):
            reason = f"{framework}/{platform}: requires a {PLATFORM_HOSTS[platform]} host"
        else:
            reason = ""
        variants = len(args.bundles) * len(args.sizes) * len(args.licenses) * len(args.release_types)
        if reason:
            skipped[reason] = skipped.get(reason, 0) + variants
            continue
        for bundle, size in itertools.product(args.bundles, args.sizes):
            exclusion = BUNDLE_SIZE_EXCLUSIONS.get((bundle, size))
            if exclusion is None:
                exclusion = PLATFORM_BUNDLE_EXCLUSIONS.get((platform, bundle))
            if exclusion:
                skipped[exclusion] = skipped.get(exclusion, 0) + len(args.licenses) * len(args.release_types)
                continue
            builds.extend(
                Build(framework, platform, bundle, size, license_name, release_type)
                for license_name, release_type in itertools.product(args.licenses, args.release_types)
            )
    return builds, skipped


def stage_example(framework: str, staging_root: Path) -> Path:
    """Copy an example app to a temporary tree without copying generated caches."""
    source = ROOT / framework / "example"
    staged = staging_root / "example"
    generated = {
        ".dart_tool", ".gradle", ".kotlin", ".pub", ".pub-cache", ".swiftpm",
        ".symlinks", ".build", ".cxx", ".externalNativeBuild", "DerivedData",
        "Pods", "build", "coverage", "node_modules", "test_output",
        ".appletvos-runtime", ".macos-runtime", ".windows-runtime",
    }
    shutil.copytree(source, staged, symlinks=True, ignore=shutil.ignore_patterns(*generated))
    package_path = os.path.relpath(ROOT / framework, staged).replace(os.sep, "/")
    if framework == "flutter":
        update_flutter_pubspec(staged / "pubspec.yaml", package_path)
    else:
        update_react_native_manifests(staged, package_path)
        update_react_native_metro_config(staged / "metro.config.js", package_path)
    return staged


def write_text_file(path: Path, content: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as output:
        output.write(content)


def update_flutter_pubspec(path: Path, package_path: str) -> None:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    dependency = next((i for i, line in enumerate(lines) if re.fullmatch(r"dependencies:\s*(?:#.*)?(?:\r?\n)?", line)), None)
    if dependency is None:
        raise RuntimeError(f"Could not find dependencies in staged Flutter pubspec: {path}")
    plugin = next((i for i in range(dependency + 1, len(lines)) if re.fullmatch(r"  ffmpeg_kit_extended_flutter:\s*(?:#.*)?(?:\r?\n)?", lines[i])), None)
    if plugin is None:
        raise RuntimeError(f"Could not find the Flutter plugin dependency in staged pubspec: {path}")
    dependency_end = next((i for i in range(plugin + 1, len(lines)) if re.match(r"^\S", lines[i]) or re.match(r"^  \S", lines[i])), len(lines))
    paths = [i for i in range(plugin + 1, dependency_end) if re.match(r"^    path:\s*", lines[i])]
    if len(paths) != 1:
        raise RuntimeError(f"Expected one Flutter plugin path in staged pubspec: {path}")
    replace_yaml_line(lines, paths[0], "path", json.dumps(package_path))

    user_defines = next((i for i, line in enumerate(lines) if re.fullmatch(r"\s{2}user_defines:\s*(?:#.*)?(?:\r?\n)?", line)), None)
    if user_defines is None:
        raise RuntimeError(f"Could not find hooks.user_defines in staged Flutter pubspec: {path}")
    package = next((i for i in range(user_defines + 1, len(lines)) if re.fullmatch(r"\s{4}ffmpeg_kit_extended_flutter:\s*(?:#.*)?(?:\r?\n)?", lines[i])), None)
    if package is None:
        raise RuntimeError(f"Could not find hooks.user_defines.ffmpeg_kit_extended_flutter in staged Flutter pubspec: {path}")
    end = next((i for i in range(package + 1, len(lines)) if re.match(r"^\S", lines[i]) or re.match(r"^ {1,4}\S", lines[i])), len(lines))
    for key in ("type", "gpl", "small"):
        if len([i for i in range(package + 1, end) if re.match(rf"\s{{6}}{key}:\s*", lines[i])]) != 1:
            raise RuntimeError(f"Expected one hooks.user_defines.ffmpeg_kit_extended_flutter.{key} setting in {path}")
    write_text_file(path, "".join(lines))


def replace_yaml_line(lines: list[str], index: int, key: str, value: str) -> None:
    ending = "\r\n" if lines[index].endswith("\r\n") else "\n" if lines[index].endswith("\n") else ""
    indentation = lines[index][: len(lines[index]) - len(lines[index].lstrip())]
    lines[index] = f"{indentation}{key}: {value}{ending}"


def configure_staged_example(build: Build, staged: Path) -> None:
    if build.framework == "flutter":
        path = staged / "pubspec.yaml"
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        user_defines = next(i for i, line in enumerate(lines) if re.fullmatch(r"\s{2}user_defines:\s*(?:#.*)?(?:\r?\n)?", line))
        package = next(i for i in range(user_defines + 1, len(lines)) if re.fullmatch(r"\s{4}ffmpeg_kit_extended_flutter:\s*(?:#.*)?(?:\r?\n)?", lines[i]))
        end = next((i for i in range(package + 1, len(lines)) if re.match(r"^\S", lines[i]) or re.match(r"^ {1,4}\S", lines[i])), len(lines))
        if build.platform == "web":
            overrides = [i for i in range(package + 1, end) if re.match(r"^ {6}(?:web|wasm):\s*", lines[i])]
            for index in reversed(overrides):
                del lines[index]
            end -= len(overrides)
        values = {"type": json.dumps(build.bundle), "gpl": str(build.license == "gpl").lower(), "small": str(build.size == "small").lower()}
        for key, value in values.items():
            matches = [i for i in range(package + 1, end) if re.match(rf"\s{{6}}{key}:\s*", lines[i])]
            if len(matches) != 1:
                raise RuntimeError(f"Expected one hooks.user_defines.ffmpeg_kit_extended_flutter.{key} setting in {path}")
            replace_yaml_line(lines, matches[0], key, value)
        write_text_file(path, "".join(lines))
    else:
        path = staged / "ffmpeg-kit-extended.config.json"
        config = json.loads(path.read_text(encoding="utf-8"))
        config.update(type=build.bundle, gpl=build.license == "gpl", small=build.size == "small")
        if build.platform == "web":
            config.pop("web", None)
            config.pop("wasm", None)
        path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def update_react_native_manifests(staged: Path, package_path: str) -> None:
    manifest_path = staged / "package.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["dependencies"]["ffmpeg-kit-extended"] = f"file:{package_path}"
    if "prepare-web" in manifest.get("scripts", {}):
        manifest["scripts"]["prepare-web"] = f"node {package_path}/scripts/prepare-web.js --app-root ."
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lock_path = staged / "package-lock.json"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    lock["packages"][""]["dependencies"]["ffmpeg-kit-extended"] = f"file:{package_path}"
    package_entry = lock["packages"].pop("..", None)
    if package_entry is not None:
        lock["packages"][package_path] = package_entry
    linked = lock["packages"].get("node_modules/ffmpeg-kit-extended")
    if linked is not None:
        linked["resolved"] = package_path
    lock_path.write_text(json.dumps(lock, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def update_react_native_metro_config(path: Path, package_path: str) -> None:
    text = path.read_text(encoding="utf-8")
    library_root = "const libraryRoot = path.resolve(__dirname, '..');"
    resolver = "  extraNodeModules: {\n    react:"
    if text.count(library_root) != 1 or text.count(resolver) != 1:
        raise RuntimeError(f"Could not update expected React Native Metro config in {path}")
    text = text.replace(
        library_root,
        f"const libraryRoot = path.resolve(__dirname, {json.dumps(package_path)});",
        1,
    )
    text = text.replace(
        resolver,
        "  extraNodeModules: {\n    'ffmpeg-kit-extended': libraryRoot,\n    react:",
        1,
    )
    write_text_file(path, text)


def tagged_environment(run_id: str) -> dict[str, str]:
    environment = os.environ.copy()
    environment["FKE_BUILD_MATRIX_RUN"] = run_id
    environment["FKE_BUILD_MATRIX_ROOT"] = str(ROOT)
    return environment


def run_command(command: list[str], cwd: Path, environment: dict[str, str], dry_run: bool) -> None:
    display = subprocess.list2cmdline(command) if os.name == "nt" else " ".join(shlex_quote(arg) for arg in command)
    if dry_run:
        print(f"DRY RUN [{cwd}]: {display}")
        return
    print(f"\n[{cwd}] {display}", flush=True)
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    process = subprocess.Popen(
        command,
        cwd=cwd,
        env=environment,
        creationflags=creationflags,
        start_new_session=os.name != "nt",
    )
    try:
        code = process.wait()
    except BaseException:
        stop_process_tree(process, environment)
        raise
    if code:
        raise subprocess.CalledProcessError(code, command)


def shlex_quote(value: str) -> str:
    import shlex

    return shlex.quote(value)


def stop_process_tree(process: subprocess.Popen[bytes], environment: dict[str, str]) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=environment,
            check=False,
        )
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=10)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


def flutter_command(build: Build) -> list[str]:
    executable = shutil.which("flutter")
    if executable is None:
        raise RuntimeError("Flutter was not found on PATH. Add the Flutter SDK bin directory to PATH and rerun this script.")
    target = {"android": "apk"}.get(build.platform, build.platform)
    command = [executable, "build", target, f"--{build.release_type}"]
    if build.platform == "web":
        command.append("--wasm")
    if sys.platform == "win32" and Path(executable).suffix.lower() in {".bat", ".cmd"}:
        command = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", *command]
    if build.platform == "ios":
        command.append("--simulator")
    return command


def flutter_artifacts(build: Build, staged: Path) -> list[Artifact]:
    build_dir = staged / "build"
    platform = build.platform
    mode = build.release_type.capitalize()
    if platform == "web":
        output = build_dir / "web"
        return [Artifact(output, "web")] if output.is_dir() else []
    if platform == "android":
        candidates = list((build_dir / "app" / "outputs" / "flutter-apk").glob("*.apk"))
        candidates = [item for item in candidates if build.release_type in item.name.lower()]
        return [Artifact(item, item.relative_to(build_dir).as_posix()) for item in candidates]
    if platform == "linux":
        bundle = build_dir / "linux" / "x64" / build.release_type / "bundle"
        return [Artifact(bundle, f"linux/{build.release_type}/bundle")] if bundle.is_dir() else []
    if platform == "windows":
        output = build_dir / "windows" / "x64" / "runner" / mode
        if output.is_dir():
            return [Artifact(output, f"windows/x64/runner/{mode}")]
        executables = list((build_dir / "windows").rglob("*.exe"))
        return [Artifact(item.parent, f"windows/{item.parent.relative_to(build_dir / 'windows').as_posix()}") for item in executables]
    if platform in {"ios", "macos"}:
        root = build_dir / platform
        apps = [item for item in root.rglob("*.app") if item.is_dir()]
        if platform == "macos":
            apps = [item for item in apps if mode in item.parts]
        return [Artifact(item, item.relative_to(build_dir).as_posix()) for item in apps]
    return []


def windows_bash() -> str:
    path_entries = [Path(entry.strip('"')) for entry in os.environ.get("PATH", "").split(os.pathsep) if entry.strip()]
    roots = [os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)")]
    git_bins = [Path(root) / "Git" / "bin" for root in roots if root]
    git_bins += [Path(root) / "Git" / "usr" / "bin" for root in roots if root]
    directories = git_bins + path_entries
    for matcher in (
        lambda path: path.endswith(("/git/bin", "/git/usr/bin")),
        lambda path: bool(re.search(r"/msys\d*/usr/bin$", path)),
        lambda path: bool(re.search(r"/cygwin\d*/bin$", path)),
    ):
        for directory in directories:
            normalized = directory.as_posix().rstrip("/").casefold()
            candidate = directory / "bash.exe"
            if matcher(normalized) and candidate.is_file():
                return str(candidate)
    raise RuntimeError("React Native Bash-based builds on Windows require Git Bash, MSYS2, or Cygwin; WSL Bash is unsupported.")


def npm_command(arguments: list[str]) -> list[str]:
    npm = shutil.which("npm")
    if npm is None:
        raise RuntimeError("npm was not found on PATH for the React Native Web build.")
    command = [npm, *arguments]
    if sys.platform == "win32" and Path(npm).suffix.lower() in {".bat", ".cmd"}:
        return [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "call", *command]
    return command


def rn_library_command() -> list[str]:
    if sys.platform == "win32":
        return [windows_bash(), "--noprofile", "--norc", "./build.sh", "library"]
    return ["bash", str(ROOT / "react-native" / "build.sh"), "library"]


def rn_command(build: Build, staged: Path | None = None) -> list[str]:
    if build.platform == "windows" and sys.platform == "win32":
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell is None:
            raise RuntimeError("PowerShell was not found on PATH for the React Native Windows build.")
        return [
            powershell,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "react-native" / "scripts" / "build-windows.ps1"),
            "-PackageRoot",
            str(ROOT / "react-native"),
            "-ExampleRoot",
            str(staged or (ROOT / "react-native" / "example")),
            "-BuildType",
            build.release_type,
        ]
    if build.platform == "web":
        arguments = ["run", "web:build"]
        if build.release_type == "debug":
            arguments.extend(["--", "--mode=development"])
        return npm_command(arguments)
    if sys.platform == "win32":
        command = [windows_bash(), "--noprofile", "--norc", "./build.sh", build.platform]
    else:
        command = ["bash", str(ROOT / "react-native" / "build.sh"), build.platform]
    if build.release_type == "release":
        command.append("--release")
    return command


def newest_app(root: Path, mode_directory: str) -> Path | None:
    if not root.is_dir():
        return None
    apps = [
        item for item in root.rglob("*.app")
        if item.is_dir()
        and mode_directory in item.parts
        and "ffmpegkitextendedexample" in item.name.lower()
    ]
    return max(apps, key=lambda item: item.stat().st_mtime) if apps else None


def rn_artifacts(build: Build, example: Path) -> list[Artifact]:
    mode = build.release_type.capitalize()
    if build.platform == "web":
        output = example / "build" / "web"
        return [Artifact(output, "web")] if output.is_dir() else []
    if build.platform == "android":
        apk = example / "android" / "app" / "build" / "outputs" / "apk" / build.release_type / f"app-{build.release_type}.apk"
        return [Artifact(apk, f"android/app-{build.release_type}.apk")] if apk.is_file() else []
    if build.platform == "ios":
        root = example / "ios" / "build" / "DerivedData" / "Build" / "Products"
        app = newest_app(root, f"{mode}-iphonesimulator")
        return [Artifact(app, f"ios/{app.name}")] if app else []
    if build.platform in {"appletvos", "macos"}:
        product_dir = "macos" if build.platform == "macos" else "appletvos"
        suffix = "" if build.platform == "macos" else "-appletvsimulator"
        root = example / product_dir / "build" / "DerivedData" / "Build" / "Products"
        app = newest_app(root, f"{mode}{suffix}")
        return [Artifact(app, f"{build.platform}/{app.name}")] if app else []
    if build.platform == "windows":
        root = example / "windows"
        executables = [
            item for item in root.rglob("FFmpegKitExtendedExample.exe")
            if mode.lower() in (part.lower() for part in item.parts)
        ]
        if not executables:
            return []
        exe = max(executables, key=lambda item: item.stat().st_mtime)
        return [Artifact(exe.parent, f"windows/{exe.parent.relative_to(root).as_posix()}")]
    return []


def write_zip(destination: Path, artifacts: list[Artifact]) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix="FKE_", suffix=".zip", dir=destination.parent)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for artifact in artifacts:
                source = artifact.path
                if source.is_symlink() or source.is_file():
                    add_file(archive, source, artifact.archive_path)
                elif source.is_dir():
                    for item in sorted(source.rglob("*")):
                        relative = Path(artifact.archive_path) / item.relative_to(source)
                        if item.is_symlink() or item.is_file():
                            add_file(archive, item, relative.as_posix())
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def copy_artifact(destination: Path, artifact: Artifact) -> None:
    source = artifact.path
    target = destination / artifact.archive_path
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        if os.name != "nt":
            target.symlink_to(os.readlink(source), target_is_directory=source.is_dir())
            return
        source = source.resolve()
    if source.is_file():
        shutil.copy2(source, target)
    elif source.is_dir():
        shutil.copytree(source, target, symlinks=os.name != "nt")
    else:
        raise FileNotFoundError(f"Build artifact does not exist: {source}")


def remove_output_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def write_directory(destination: Path, artifacts: list[Artifact]) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix="FKE_", dir=destination.parent))
    backup: Path | None = None
    installed = False
    try:
        for artifact in artifacts:
            copy_artifact(temporary, artifact)
        if destination.exists() or destination.is_symlink():
            backup = Path(tempfile.mkdtemp(prefix="FKE_", dir=destination.parent))
            backup.rmdir()
            os.replace(destination, backup)
        try:
            os.replace(temporary, destination)
            installed = True
        except BaseException:
            if backup is not None:
                os.replace(backup, destination)
                backup = None
            raise
        if backup is not None:
            remove_output_path(backup)
            backup = None
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)
        if installed and backup is not None and (backup.exists() or backup.is_symlink()):
            remove_output_path(backup)


def add_file(archive: zipfile.ZipFile, path: Path, archive_path: str) -> None:
    if path.is_symlink():
        info = zipfile.ZipInfo(archive_path)
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(info, os.readlink(path))
    else:
        archive.write(path, archive_path)


def install_signal_handlers() -> None:
    def terminate(signum, _frame):
        raise KeyboardInterrupt(f"Received signal {signum}.")

    signal.signal(signal.SIGTERM, terminate)
    if hasattr(signal, "SIGBREAK"):
        signal.signal(signal.SIGBREAK, terminate)


def main() -> int:
    args = parse_args()
    builds, skipped = build_matrix(args)
    if not builds:
        print("No selected build variants remain after applying compatibility rules.", file=sys.stderr)
        for reason, count in skipped.items():
            print(f"Skipped {count} variants: {reason}", file=sys.stderr)
        return 2

    for reason, count in skipped.items():
        print(f"Skipped {count} variants: {reason}")
    output_kind = "ZIP output" if args.zip_output else "staged output"
    print(f"Selected {len(builds)} build variants; {output_kind}: {args.output_dir}")
    if args.dry_run:
        for build in builds:
            if build.framework == "react-native" and build.platform == "web":
                commands = [
                    (ROOT / "react-native", rn_library_command()),
                    ("<temporary React Native example>", npm_command(["install", "--no-audit", "--no-fund"])),
                    ("<temporary React Native example>", rn_command(build)),
                ]
                print(f"{output_name(build, args.zip_output)}:")
                for cwd, command in commands:
                    display = subprocess.list2cmdline(command) if os.name == "nt" else " ".join(shlex_quote(arg) for arg in command)
                    print(f"  [{cwd}] {display}")
                continue
            command = flutter_command(build) if build.framework == "flutter" else rn_command(build)
            display = subprocess.list2cmdline(command) if os.name == "nt" else " ".join(shlex_quote(arg) for arg in command)
            print(f"{output_name(build, args.zip_output)}: {display}")
        return 0

    install_signal_handlers()
    run_id = f"{time.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:8]}"
    environment = tagged_environment(run_id)
    completed = 0
    for framework in args.frameworks:
        framework_builds = [build for build in builds if build.framework == framework]
        if not framework_builds:
            continue
        with tempfile.TemporaryDirectory(prefix=".FKE_example_build_", dir=ROOT / framework) as directory:
            staged = stage_example(framework, Path(directory))
            rn_web_library_built = False
            rn_web_dependencies_installed = (staged / "node_modules").is_dir()
            for build in framework_builds:
                index = completed + 1
                print(f"\n[{index}/{len(builds)}] {build.filename}", flush=True)
                configure_staged_example(build, staged)
                build_environment = environment.copy()
                if framework == "react-native":
                    build_environment["FFMPEG_KIT_EXAMPLE_DIR"] = str(staged)
                    build_environment["FFMPEG_KIT_IOS_DERIVED_DATA_PATH"] = str(staged / "ios" / "build" / "DerivedData")
                    if build.platform == "web":
                        if not rn_web_library_built:
                            run_command(rn_library_command(), ROOT / "react-native", build_environment, False)
                            rn_web_library_built = True
                        if not rn_web_dependencies_installed:
                            run_command(npm_command(["install", "--no-audit", "--no-fund"]), staged, build_environment, False)
                            rn_web_dependencies_installed = True
                        command = rn_command(build, staged)
                        cwd = staged
                    else:
                        command = rn_command(build, staged)
                        cwd = ROOT / "react-native"
                else:
                    command = flutter_command(build)
                    cwd = staged
                run_command(command, cwd, build_environment, False)
                artifacts = flutter_artifacts(build, staged) if framework == "flutter" else rn_artifacts(build, staged)
                if not artifacts:
                    raise RuntimeError(f"{framework} build succeeded but no {build.platform} output was found.")
                filename = output_name(build, args.zip_output)
                destination = args.output_dir / filename
                if args.zip_output:
                    write_zip(destination, artifacts)
                else:
                    write_directory(destination, artifacts)
                completed += 1
                print(f"{'Packaged' if args.zip_output else 'Staged'} {destination}")

    print(f"Completed {completed} builds; skipped {sum(skipped.values())} unsupported variants.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt as error:
        print(f"Build interrupted: {error or 'user requested stop'}; temporary example copy removed.", file=sys.stderr)
        sys.exit(130)
    except subprocess.CalledProcessError as error:
        print(f"Build command failed with exit code {error.returncode}: {error.cmd}", file=sys.stderr)
        sys.exit(error.returncode or 1)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(f"Build matrix failed: {error}", file=sys.stderr)
        sys.exit(1)

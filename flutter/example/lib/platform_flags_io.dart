import 'dart:io';

bool get isAndroid => Platform.isAndroid;
bool get isWindows => Platform.isWindows;
bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

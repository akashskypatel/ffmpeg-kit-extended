#include "third_party/ffmpeg-kit-extended/linux/FFmpegKitExtendedTurboModule.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>

#include "third_party/ffmpeg-kit-extended/cpp/FFmpegKitDynamicApi.h"

namespace facebook::react {
namespace {

namespace bridge = ffmpegkit::bridge;

std::string StringArgument(
    jsi::Runtime &runtime,
    const jsi::Value *args,
    std::size_t index) {
  return args[index].asString(runtime).utf8(runtime);
}

double NumberArgument(const jsi::Value *args, std::size_t index) {
  return args[index].asNumber();
}

std::int32_t IntArgument(const jsi::Value *args, std::size_t index) {
  return static_cast<std::int32_t>(args[index].asNumber());
}

jsi::Value StringValue(jsi::Runtime &runtime, const std::string &value) {
  return jsi::String::createFromUtf8(runtime, value);
}

#define ADD_VOID_0(jsName, nativeName)                                         \
  methodMap_[jsName] = MethodMetadata{                                         \
      0,                                                                        \
      [](jsi::Runtime &, TurboModule &, const jsi::Value *, std::size_t) {      \
        bridge::nativeName();                                                   \
        return jsi::Value::undefined();                                         \
      }}

#define ADD_STRING_0(jsName, nativeName)                                       \
  methodMap_[jsName] = MethodMetadata{                                         \
      0,                                                                        \
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *, std::size_t) \
          -> jsi::Value {                                                       \
        return StringValue(runtime, bridge::nativeName());                      \
      }}

#define ADD_NUMBER_0(jsName, nativeName)                                       \
  methodMap_[jsName] = MethodMetadata{                                         \
      0,                                                                        \
      [](jsi::Runtime &, TurboModule &, const jsi::Value *, std::size_t) {      \
        return jsi::Value(static_cast<double>(bridge::nativeName()));           \
      }}

#define ADD_BOOL_0(jsName, nativeName)                                         \
  methodMap_[jsName] = MethodMetadata{                                         \
      0,                                                                        \
      [](jsi::Runtime &, TurboModule &, const jsi::Value *, std::size_t) {      \
        return jsi::Value(bridge::nativeName());                                \
      }}

#define ADD_STRING_FROM_STRING(jsName, nativeName)                             \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,          \
         std::size_t) -> jsi::Value {                                           \
        return StringValue(runtime, bridge::nativeName(StringArgument(runtime, args, 0))); \
      }}

#define ADD_NUMBER_FROM_STRING(jsName, nativeName)                             \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,          \
         std::size_t) {                                                         \
        return jsi::Value(static_cast<double>(                               \
            bridge::nativeName(StringArgument(runtime, args, 0))));             \
      }}

#define ADD_BOOL_FROM_STRING(jsName, nativeName)                               \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,          \
         std::size_t) {                                                         \
        return jsi::Value(bridge::nativeName(StringArgument(runtime, args, 0))); \
      }}

#define ADD_VOID_FROM_NUMBER(jsName, nativeName)                               \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {  \
        bridge::nativeName(NumberArgument(args, 0));                            \
        return jsi::Value::undefined();                                         \
      }}

#define ADD_NUMBER_FROM_NUMBER(jsName, nativeName)                             \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {  \
        return jsi::Value(static_cast<double>(                               \
            bridge::nativeName(NumberArgument(args, 0))));                      \
      }}

#define ADD_BOOL_FROM_NUMBER(jsName, nativeName)                               \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {  \
        return jsi::Value(bridge::nativeName(NumberArgument(args, 0)));         \
      }}

#define ADD_STRING_FROM_NUMBER(jsName, nativeName)                             \
  methodMap_[jsName] = MethodMetadata{                                         \
      1,                                                                        \
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,          \
         std::size_t) -> jsi::Value {                                           \
        return StringValue(runtime, bridge::nativeName(NumberArgument(args, 0))); \
      }}

} // namespace

FFmpegKitExtendedTurboModule::FFmpegKitExtendedTurboModule(
    const std::string &name,
    std::shared_ptr<CallInvoker> jsInvoker)
    : TurboModule(name, std::move(jsInvoker)) {
  ADD_VOID_0("initialize", initialize);
  ADD_STRING_0("getBuildStamp", getBuildStamp);

  ADD_NUMBER_FROM_STRING("createFFmpegSession", createFFmpegSession);
  ADD_NUMBER_FROM_STRING("createFFprobeSession", createFFprobeSession);
  ADD_NUMBER_FROM_STRING("createFFplaySession", createFFplaySession);
  ADD_NUMBER_FROM_STRING("createMediaInformationSession", createMediaInformationSession);

  methodMap_["executeSessionAsync"] = MethodMetadata{
      2,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {
        bridge::executeSessionAsync(
            NumberArgument(args, 0), NumberArgument(args, 1));
        return jsi::Value::undefined();
      }};
  ADD_VOID_FROM_NUMBER("cancelSession", cancelSession);

  ADD_STRING_FROM_NUMBER("getSessionJson", getSessionJson);
  ADD_VOID_FROM_NUMBER("releaseSessionHandle", releaseSessionHandle);
  ADD_STRING_FROM_STRING("getSessionsJson", getSessionsJson);
  ADD_STRING_FROM_STRING("getLastSessionJson", getLastSessionJson);

  methodMap_["getLogsJson"] = MethodMetadata{
      2,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) -> jsi::Value {
        return StringValue(
            runtime,
            bridge::getLogsJson(
                NumberArgument(args, 0), NumberArgument(args, 1)));
      }};
  methodMap_["getStatisticsJson"] = MethodMetadata{
      2,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) -> jsi::Value {
        return StringValue(
            runtime,
            bridge::getStatisticsJson(
                NumberArgument(args, 0), NumberArgument(args, 1)));
      }};
  ADD_STRING_FROM_NUMBER("getMediaInformationJson", getMediaInformationJson);

  ADD_VOID_FROM_NUMBER("ffplayStart", ffplayStart);
  ADD_VOID_FROM_NUMBER("ffplayPause", ffplayPause);
  ADD_VOID_FROM_NUMBER("ffplayResume", ffplayResume);
  ADD_VOID_FROM_NUMBER("ffplayStop", ffplayStop);

  methodMap_["ffplaySeek"] = MethodMetadata{
      2,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {
        bridge::ffplaySeek(NumberArgument(args, 0), NumberArgument(args, 1));
        return jsi::Value::undefined();
      }};
  ADD_NUMBER_FROM_NUMBER("ffplayGetPosition", ffplayGetPosition);
  methodMap_["ffplaySetPosition"] = MethodMetadata{
      2,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {
        bridge::ffplaySetPosition(
            NumberArgument(args, 0), NumberArgument(args, 1));
        return jsi::Value::undefined();
      }};
  ADD_NUMBER_FROM_NUMBER("ffplayGetDuration", ffplayGetDuration);
  ADD_NUMBER_FROM_NUMBER("ffplayGetVideoWidth", ffplayGetVideoWidth);
  ADD_NUMBER_FROM_NUMBER("ffplayGetVideoHeight", ffplayGetVideoHeight);
  ADD_BOOL_FROM_NUMBER("ffplayIsPlaying", ffplayIsPlaying);
  ADD_BOOL_FROM_NUMBER("ffplayIsPaused", ffplayIsPaused);
  methodMap_["ffplaySetVolume"] = MethodMetadata{
      2,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {
        bridge::ffplaySetVolume(
            NumberArgument(args, 0), NumberArgument(args, 1));
        return jsi::Value::undefined();
      }};
  ADD_NUMBER_FROM_NUMBER("ffplayGetVolume", ffplayGetVolume);
  ADD_BOOL_FROM_STRING("ffplayHasVideoStream", ffplayHasVideoStream);

  ADD_VOID_0("enableRedirection", enableRedirection);
  ADD_VOID_0("disableRedirection", disableRedirection);
  methodMap_["setLogLevel"] = MethodMetadata{
      1,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {
        bridge::setLogLevel(IntArgument(args, 0));
        return jsi::Value::undefined();
      }};
  methodMap_["getLogLevel"] = MethodMetadata{
      0,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *, std::size_t) {
        return jsi::Value(static_cast<double>(bridge::getLogLevel()));
      }};
  methodMap_["logLevelToString"] = MethodMetadata{
      1,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) -> jsi::Value {
        return StringValue(runtime, bridge::logLevelToString(IntArgument(args, 0)));
      }};
  methodMap_["setFontDirectory"] = MethodMetadata{
      2,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) {
        bridge::setFontDirectory(
            StringArgument(runtime, args, 0),
            StringArgument(runtime, args, 1));
        return jsi::Value::undefined();
      }};
  methodMap_["setEnvironmentVariable"] = MethodMetadata{
      2,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) {
        bridge::setEnvironmentVariable(
            StringArgument(runtime, args, 0),
            StringArgument(runtime, args, 1));
        return jsi::Value::undefined();
      }};
  methodMap_["ignoreSignal"] = MethodMetadata{
      1,
      [](jsi::Runtime &, TurboModule &, const jsi::Value *args, std::size_t) {
        bridge::ignoreSignal(IntArgument(args, 0));
        return jsi::Value::undefined();
      }};
  methodMap_["setAudioOutputDevice"] = MethodMetadata{
      1,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) {
        bridge::setAudioOutputDevice(StringArgument(runtime, args, 0));
        return jsi::Value::undefined();
      }};
  ADD_STRING_0("listAudioOutputDevices", listAudioOutputDevices);

  ADD_STRING_0("getFFmpegVersion", getFFmpegVersion);
  ADD_STRING_0("getFFmpegArchitecture", getFFmpegArchitecture);
  ADD_STRING_0("getVersion", getVersion);
  ADD_STRING_0("getPackageName", getPackageName);
  ADD_STRING_0("getExternalLibraries", getExternalLibraries);
  ADD_STRING_0("getBundleType", getBundleType);
  ADD_BOOL_0("isGpl", isGpl);
  ADD_BOOL_0("isNonfree", isNonfree);
  ADD_STRING_0("getRegisteredCodecs", getRegisteredCodecs);
  ADD_STRING_0("getRegisteredEncoders", getRegisteredEncoders);
  ADD_STRING_0("getRegisteredDecoders", getRegisteredDecoders);
  ADD_STRING_0("getRegisteredMuxers", getRegisteredMuxers);
  ADD_STRING_0("getRegisteredDemuxers", getRegisteredDemuxers);
  ADD_STRING_0("getRegisteredFilters", getRegisteredFilters);
  ADD_STRING_0("getRegisteredProtocols", getRegisteredProtocols);
  ADD_STRING_0("getRegisteredBitstreamFilters", getRegisteredBitstreamFilters);
  ADD_STRING_0("getBuildConfiguration", getBuildConfiguration);
  ADD_STRING_0("getBuildDate", getBuildDate);

  ADD_VOID_FROM_NUMBER("setSessionHistorySize", setSessionHistorySize);
  ADD_NUMBER_0("getSessionHistorySize", getSessionHistorySize);
  ADD_VOID_0("clearSessions", clearSessions);
  ADD_STRING_0("registerNewFFmpegPipe", registerNewFFmpegPipe);
  methodMap_["closeFFmpegPipe"] = MethodMetadata{
      1,
      [](jsi::Runtime &runtime, TurboModule &, const jsi::Value *args,
         std::size_t) {
        bridge::closeFFmpegPipe(StringArgument(runtime, args, 0));
        return jsi::Value::undefined();
      }};
  ADD_NUMBER_FROM_NUMBER("messagesInTransmit", messagesInTransmit);

  ADD_VOID_FROM_NUMBER("enableDebugLog", enableDebugLog);
  ADD_VOID_FROM_NUMBER("disableDebugLog", disableDebugLog);
  ADD_BOOL_FROM_NUMBER("isDebugLogEnabled", isDebugLogEnabled);
  ADD_STRING_FROM_NUMBER("getDebugLog", getDebugLog);
  ADD_VOID_FROM_NUMBER("clearDebugLog", clearDebugLog);
}

#undef ADD_VOID_0
#undef ADD_STRING_0
#undef ADD_NUMBER_0
#undef ADD_BOOL_0
#undef ADD_STRING_FROM_STRING
#undef ADD_NUMBER_FROM_STRING
#undef ADD_BOOL_FROM_STRING
#undef ADD_VOID_FROM_NUMBER
#undef ADD_NUMBER_FROM_NUMBER
#undef ADD_BOOL_FROM_NUMBER
#undef ADD_STRING_FROM_NUMBER

} // namespace facebook::react

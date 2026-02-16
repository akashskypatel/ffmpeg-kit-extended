// ignore_for_file: non_constant_identifier_names

class MockStreamInformation {
  final int index;
  final String type;
  final String codec;
  final String codecLong;
  final String format;
  final int width;
  final int height;
  final String bitrate;
  final String sampleRate;
  final String sampleFormat;
  final String channelLayout;
  final String sampleAspectRatio;
  final String displayAspectRatio;
  final String averageFrameRate;
  final String realFrameRate;
  final String timeBase;
  final String codecTimeBase;
  final String tagsJson;
  final String allPropertiesJson;

  MockStreamInformation({
    this.index = 0,
    this.type = "video",
    this.codec = "h264",
    this.codecLong = "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
    this.format = "yuv420p",
    this.width = 1920,
    this.height = 1080,
    this.bitrate = "5000000",
    this.sampleRate = "0",
    this.sampleFormat = "",
    this.channelLayout = "",
    this.sampleAspectRatio = "1:1",
    this.displayAspectRatio = "16:9",
    this.averageFrameRate = "30/1",
    this.realFrameRate = "30/1",
    this.timeBase = "1/90000",
    this.codecTimeBase = "1/60",
    this.tagsJson = "{\"language\": \"eng\"}",
    this.allPropertiesJson = "{}",
  });
}

class MockChapterInformation {
  final int id;
  final String timeBase;
  final int start;
  final String startTime;
  final int end;
  final String endTime;
  final String tagsJson;
  final String allPropertiesJson;

  MockChapterInformation({
    this.id = 0,
    this.timeBase = "1/1000",
    this.start = 0,
    this.startTime = "0.000",
    this.end = 10000,
    this.endTime = "10.000",
    this.tagsJson = "{\"title\": \"Chapter 1\"}",
    this.allPropertiesJson = "{}",
  });
}

class MockMediaInformation {
  final String filename;
  final String format;
  final String longFormat;
  final String duration;
  final String startTime;
  final String bitrate;
  final String size;
  final String tagsJson;
  final String allPropertiesJson;
  final List<MockStreamInformation> streams;
  final List<MockChapterInformation> chapters;

  MockMediaInformation({
    this.filename = "",
    this.format = "",
    this.longFormat = "",
    this.duration = "",
    this.startTime = "0.000",
    this.bitrate = "",
    this.size = "1024000",
    this.tagsJson = "{}",
    this.allPropertiesJson = "{}",
    this.streams = const [],
    this.chapters = const [],
  });
}

class MockSessionData {
  final int id;
  int state = 0;
  int returnCode = 0;
  String command = "";
  String output = "";
  List<String> logs = [];
  int createTime = 0;
  int startTime = 0;
  int endTime = 0;
  int duration = 0;

  bool isPlaying = false;
  bool isPaused = false;
  double position = 0.0;

  MockSessionData(this.id);
}

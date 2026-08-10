import 'package:package_info_plus/package_info_plus.dart';

/// Compile-time + runtime build identity shown on the owner debug panel.
///
/// IPA builds inject git SHA / branch / timestamp via `--dart-define`.
/// Version and build number come from the platform package metadata.
class ClarityBuildProvenance {
  const ClarityBuildProvenance({
    required this.gitSha,
    required this.gitBranch,
    required this.appVersion,
    required this.buildNumber,
    required this.buildTimestamp,
  });

  static const gitShaDefine = String.fromEnvironment(
    'CLARITY_GIT_SHA',
    defaultValue: 'local',
  );
  static const gitBranchDefine = String.fromEnvironment(
    'CLARITY_GIT_BRANCH',
    defaultValue: 'local',
  );
  static const buildTimestampDefine = String.fromEnvironment(
    'CLARITY_BUILD_TIMESTAMP',
    defaultValue: 'unknown',
  );

  final String gitSha;
  final String gitBranch;
  final String appVersion;
  final String buildNumber;
  final String buildTimestamp;

  String get shortSha {
    final sha = gitSha.trim();
    if (sha.length <= 8) {
      return sha;
    }
    return sha.substring(0, 8);
  }

  String get summaryLine =>
      '$appVersion+$buildNumber · $gitBranch@$shortSha · $buildTimestamp';

  Map<String, String> toMap() => {
    'git_sha': gitSha,
    'git_branch': gitBranch,
    'app_version': appVersion,
    'build_number': buildNumber,
    'build_timestamp': buildTimestamp,
  };

  static Future<ClarityBuildProvenance> load() async {
    final info = await PackageInfo.fromPlatform();
    return ClarityBuildProvenance(
      gitSha: gitShaDefine,
      gitBranch: gitBranchDefine,
      appVersion: info.version,
      buildNumber: info.buildNumber,
      buildTimestamp: buildTimestampDefine,
    );
  }
}

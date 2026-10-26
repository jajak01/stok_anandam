import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Label versi aplikasi yang dibaca dari `pubspec.yaml`.
///
/// Contoh: `version: 1.1.39+40` akan tampil sebagai `Versi 1.1.39 (40)`.
/// Dipakai di splash screen dan login page agar pengguna tahu build
/// mana yang sedang berjalan (penting saat lapor bug / cek update).
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.textStyle,
    this.prefix = 'Versi',
    this.showBuildNumber = true,
  });

  /// Gaya teks label. Default: abu-abu kecil yang cocok di background terang.
  final TextStyle? textStyle;

  /// Teks sebelum nomor versi, mis. `Versi`. Set `''` untuk tanpa prefix.
  final String prefix;

  /// Tampilkan build number (`versionCode`) dalam tanda kurung.
  final bool showBuildNumber;

  /// `PackageInfo.fromPlatform()` cukup dipanggil sekali per sesi.
  static Future<PackageInfo>? _packageInfo;

  static Future<PackageInfo> _load() {
    return _packageInfo ??= PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.3,
        );

    return FutureBuilder<PackageInfo>(
      future: _load(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) {
          // Placeholder kosong supaya tinggi layout tidak melompat saat data siap.
          return Text(' ', style: style);
        }

        final buildNumber = info.buildNumber;
        final showBuild = showBuildNumber && buildNumber.isNotEmpty;

        final text = [
          if (prefix.isNotEmpty) prefix,
          info.version,
          if (showBuild) '($buildNumber)',
        ].join(' ');

        return Text(text, style: style, textAlign: TextAlign.center);
      },
    );
  }
}

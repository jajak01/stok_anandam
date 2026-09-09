//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'user_response.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UserResponse {
  /// Returns a new [UserResponse] instance.
  UserResponse({
     this.id,
     this.nama,
     this.username,
     this.role,
     this.isOnline,
     this.deviceCount,
     this.active,
     this.noHp,
     this.permissions,
  });

  @JsonKey(
    name: r'id',
    required: false,
    includeIfNull: false
  )
  final Object? id;

  @JsonKey(
    name: r'nama',
    required: false,
    includeIfNull: false
  )
  final Object? nama;

  @JsonKey(
    name: r'username',
    required: false,
    includeIfNull: false
  )
  final Object? username;

  @JsonKey(
    name: r'role',
    required: false,
    includeIfNull: false
  )
  final UserResponseRoleEnum? role;

  @JsonKey(
    name: r'isOnline',
    required: false,
    includeIfNull: false
  )
  final bool? isOnline;

  @JsonKey(
    name: r'deviceCount',
    required: false,
    includeIfNull: false
  )
  final int? deviceCount;

  @JsonKey(
    name: r'active',
    required: false,
    includeIfNull: false
  )
  final bool? active;

  @JsonKey(
    name: r'noHp',
    required: false,
    includeIfNull: false
  )
  final String? noHp;

  @JsonKey(
    name: r'permissions',
    required: false,
    includeIfNull: false
  )
  final List<String>? permissions;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserResponse &&
     other.id == id &&
     other.nama == nama &&
     other.username == username &&
     other.role == role &&
     other.isOnline == isOnline &&
     other.deviceCount == deviceCount &&
     other.active == active &&
     other.permissions == permissions;

  @override
  int get hashCode =>
    (id == null ? 0 : id.hashCode) +
    (nama == null ? 0 : nama.hashCode) +
    (username == null ? 0 : username.hashCode) +
    (role == null ? 0 : role.hashCode) +
    (isOnline == null ? 0 : isOnline.hashCode) +
    (deviceCount == null ? 0 : deviceCount.hashCode) +
    (active == null ? 0 : active.hashCode) +
    (permissions == null ? 0 : permissions.hashCode);

  factory UserResponse.fromJson(Map<String, dynamic> json) => _$UserResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}


enum UserResponseRoleEnum {
  @JsonValue('MANAGER')
  MANAGER,
  @JsonValue('ADMIN')
  ADMIN,
  @JsonValue('SPV_MARKETING')
  SPV_MARKETING,
  @JsonValue('SPV_GUDANG')
  SPV_GUDANG,
  @JsonValue('SPV_TEKNISI')
  SPV_TEKNISI,
  @JsonValue('MARKETING')
  MARKETING,
  @JsonValue('MARKETING_TOKO')
  MARKETING_TOKO,
  @JsonValue('MARKETING_PROJECT')
  MARKETING_PROJECT,
  @JsonValue('MARKETING_DISTRIBUSI')
  MARKETING_DISTRIBUSI,
  @JsonValue('MARKETING_ONLINE')
  MARKETING_ONLINE,
  @JsonValue('GUDANG')
  GUDANG,
  @JsonValue('NOTA')
  NOTA,
  @JsonValue('DELIVERY')
  DELIVERY,
  @JsonValue('TEKNISI')
  TEKNISI,
}

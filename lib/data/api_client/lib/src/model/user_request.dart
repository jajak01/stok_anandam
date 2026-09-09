//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'user_request.g.dart';


@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UserRequest {
  /// Returns a new [UserRequest] instance.
  UserRequest({

    required  this.nama,

    required  this.username,

     this.password,

    required  this.role,

     this.permissions,
  });

  @JsonKey(
    
    name: r'nama',
    required: true,
    includeIfNull: true
  )


  final Object? nama;



  @JsonKey(
    
    name: r'username',
    required: true,
    includeIfNull: true
  )


  final Object? username;



  @JsonKey(
    
    name: r'password',
    required: false,
    includeIfNull: false
  )


  final Object? password;



  @JsonKey(
    
    name: r'role',
    required: true,
    includeIfNull: true
  )


  final UserRequestRoleEnum? role;

  @JsonKey(
    name: r'permissions',
    required: false,
    includeIfNull: false
  )
  final List<String>? permissions;



  @override
  bool operator ==(Object other) => identical(this, other) || other is UserRequest &&
     other.nama == nama &&
     other.username == username &&
     other.password == password &&
     other.role == role;

  @override
  int get hashCode =>
    (nama == null ? 0 : nama.hashCode) +
    (username == null ? 0 : username.hashCode) +
    (password == null ? 0 : password.hashCode) +
    (role == null ? 0 : role.hashCode);

  factory UserRequest.fromJson(Map<String, dynamic> json) => _$UserRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UserRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }

}


enum UserRequestRoleEnum {
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



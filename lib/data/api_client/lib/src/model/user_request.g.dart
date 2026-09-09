// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRequest _$UserRequestFromJson(Map<String, dynamic> json) => $checkedCreate(
      'UserRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['nama', 'username', 'role'],
        );
        final val = UserRequest(
          nama: $checkedConvert('nama', (v) => v),
          username: $checkedConvert('username', (v) => v),
          password: $checkedConvert('password', (v) => v),
          role: $checkedConvert('role',
              (v) => $enumDecodeNullable(_$UserRequestRoleEnumEnumMap, v)),
          permissions: $checkedConvert('permissions',
              (v) => (v as List<dynamic>?)?.map((e) => e as String).toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$UserRequestToJson(UserRequest instance) =>
    <String, dynamic>{
      'nama': instance.nama,
      'username': instance.username,
      if (instance.password case final value?) 'password': value,
      'role': _$UserRequestRoleEnumEnumMap[instance.role],
      if (instance.permissions case final value?) 'permissions': value,
    };

const _$UserRequestRoleEnumEnumMap = {
  UserRequestRoleEnum.MANAGER: 'MANAGER',
  UserRequestRoleEnum.ADMIN: 'ADMIN',
  UserRequestRoleEnum.SPV_MARKETING: 'SPV_MARKETING',
  UserRequestRoleEnum.SPV_GUDANG: 'SPV_GUDANG',
  UserRequestRoleEnum.SPV_TEKNISI: 'SPV_TEKNISI',
  UserRequestRoleEnum.MARKETING: 'MARKETING',
  UserRequestRoleEnum.MARKETING_TOKO: 'MARKETING_TOKO',
  UserRequestRoleEnum.MARKETING_PROJECT: 'MARKETING_PROJECT',
  UserRequestRoleEnum.MARKETING_DISTRIBUSI: 'MARKETING_DISTRIBUSI',
  UserRequestRoleEnum.MARKETING_ONLINE: 'MARKETING_ONLINE',
  UserRequestRoleEnum.GUDANG: 'GUDANG',
  UserRequestRoleEnum.NOTA: 'NOTA',
  UserRequestRoleEnum.DELIVERY: 'DELIVERY',
  UserRequestRoleEnum.TEKNISI: 'TEKNISI',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserResponse _$UserResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'UserResponse',
      json,
      ($checkedConvert) {
        final val = UserResponse(
          id: $checkedConvert('id', (v) => v),
          nama: $checkedConvert('nama', (v) => v),
          username: $checkedConvert('username', (v) => v),
          role: $checkedConvert('role',
              (v) => $enumDecodeNullable(_$UserResponseRoleEnumEnumMap, v)),
          isOnline: $checkedConvert('isOnline', (v) => v as bool?),
          deviceCount: $checkedConvert('deviceCount', (v) => v as int?),
          active: $checkedConvert('active', (v) => v as bool?),
          noHp: $checkedConvert('noHp', (v) => v as String?),
          permissions: $checkedConvert('permissions',
              (v) => (v as List<dynamic>?)?.map((e) => e as String).toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$UserResponseToJson(UserResponse instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      if (instance.nama case final value?) 'nama': value,
      if (instance.username case final value?) 'username': value,
      if (_$UserResponseRoleEnumEnumMap[instance.role] case final value?)
        'role': value,
      if (instance.isOnline case final value?) 'isOnline': value,
      if (instance.deviceCount case final value?) 'deviceCount': value,
      if (instance.active case final value?) 'active': value,
      if (instance.noHp case final value?) 'noHp': value,
      if (instance.permissions case final value?) 'permissions': value,
    };

const _$UserResponseRoleEnumEnumMap = {
  UserResponseRoleEnum.MANAGER: 'MANAGER',
  UserResponseRoleEnum.ADMIN: 'ADMIN',
  UserResponseRoleEnum.SPV_MARKETING: 'SPV_MARKETING',
  UserResponseRoleEnum.SPV_GUDANG: 'SPV_GUDANG',
  UserResponseRoleEnum.SPV_TEKNISI: 'SPV_TEKNISI',
  UserResponseRoleEnum.MARKETING: 'MARKETING',
  UserResponseRoleEnum.MARKETING_TOKO: 'MARKETING_TOKO',
  UserResponseRoleEnum.MARKETING_PROJECT: 'MARKETING_PROJECT',
  UserResponseRoleEnum.MARKETING_DISTRIBUSI: 'MARKETING_DISTRIBUSI',
  UserResponseRoleEnum.MARKETING_ONLINE: 'MARKETING_ONLINE',
  UserResponseRoleEnum.GUDANG: 'GUDANG',
  UserResponseRoleEnum.NOTA: 'NOTA',
  UserResponseRoleEnum.DELIVERY: 'DELIVERY',
  UserResponseRoleEnum.TEKNISI: 'TEKNISI',
};

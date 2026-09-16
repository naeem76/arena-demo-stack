// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participant.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Participant extends Participant {
  @override
  final String id;
  @override
  final String displayName;

  factory _$Participant([void Function(ParticipantBuilder)? updates]) =>
      (ParticipantBuilder()..update(updates))._build();

  _$Participant._({required this.id, required this.displayName}) : super._();
  @override
  Participant rebuild(void Function(ParticipantBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ParticipantBuilder toBuilder() => ParticipantBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Participant &&
        id == other.id &&
        displayName == other.displayName;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Participant')
          ..add('id', id)
          ..add('displayName', displayName))
        .toString();
  }
}

class ParticipantBuilder implements Builder<Participant, ParticipantBuilder> {
  _$Participant? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  ParticipantBuilder() {
    Participant._defaults(this);
  }

  ParticipantBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _displayName = $v.displayName;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Participant other) {
    _$v = other as _$Participant;
  }

  @override
  void update(void Function(ParticipantBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Participant build() => _build();

  _$Participant _build() {
    final _$result = _$v ??
        _$Participant._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'Participant', 'id'),
          displayName: BuiltValueNullFieldError.checkNotNull(
              displayName, r'Participant', 'displayName'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

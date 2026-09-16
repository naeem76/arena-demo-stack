// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem_detail.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ProblemDetail extends ProblemDetail {
  @override
  final String? type;
  @override
  final String? title;
  @override
  final int? status;
  @override
  final String? detail;
  @override
  final String? instance;
  @override
  final BuiltMap<String, JsonObject?>? properties;

  factory _$ProblemDetail([void Function(ProblemDetailBuilder)? updates]) =>
      (ProblemDetailBuilder()..update(updates))._build();

  _$ProblemDetail._(
      {this.type,
      this.title,
      this.status,
      this.detail,
      this.instance,
      this.properties})
      : super._();
  @override
  ProblemDetail rebuild(void Function(ProblemDetailBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ProblemDetailBuilder toBuilder() => ProblemDetailBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ProblemDetail &&
        type == other.type &&
        title == other.title &&
        status == other.status &&
        detail == other.detail &&
        instance == other.instance &&
        properties == other.properties;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, detail.hashCode);
    _$hash = $jc(_$hash, instance.hashCode);
    _$hash = $jc(_$hash, properties.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ProblemDetail')
          ..add('type', type)
          ..add('title', title)
          ..add('status', status)
          ..add('detail', detail)
          ..add('instance', instance)
          ..add('properties', properties))
        .toString();
  }
}

class ProblemDetailBuilder
    implements Builder<ProblemDetail, ProblemDetailBuilder> {
  _$ProblemDetail? _$v;

  String? _type;
  String? get type => _$this._type;
  set type(String? type) => _$this._type = type;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  int? _status;
  int? get status => _$this._status;
  set status(int? status) => _$this._status = status;

  String? _detail;
  String? get detail => _$this._detail;
  set detail(String? detail) => _$this._detail = detail;

  String? _instance;
  String? get instance => _$this._instance;
  set instance(String? instance) => _$this._instance = instance;

  MapBuilder<String, JsonObject?>? _properties;
  MapBuilder<String, JsonObject?> get properties =>
      _$this._properties ??= MapBuilder<String, JsonObject?>();
  set properties(MapBuilder<String, JsonObject?>? properties) =>
      _$this._properties = properties;

  ProblemDetailBuilder() {
    ProblemDetail._defaults(this);
  }

  ProblemDetailBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _title = $v.title;
      _status = $v.status;
      _detail = $v.detail;
      _instance = $v.instance;
      _properties = $v.properties?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ProblemDetail other) {
    _$v = other as _$ProblemDetail;
  }

  @override
  void update(void Function(ProblemDetailBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ProblemDetail build() => _build();

  _$ProblemDetail _build() {
    _$ProblemDetail _$result;
    try {
      _$result = _$v ??
          _$ProblemDetail._(
            type: type,
            title: title,
            status: status,
            detail: detail,
            instance: instance,
            properties: _properties?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'properties';
        _properties?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ProblemDetail', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

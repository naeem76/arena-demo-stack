// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ValidationRequest extends ValidationRequest {
  @override
  final String name;
  @override
  final int quantity;

  factory _$ValidationRequest(
          [void Function(ValidationRequestBuilder)? updates]) =>
      (ValidationRequestBuilder()..update(updates))._build();

  _$ValidationRequest._({required this.name, required this.quantity})
      : super._();
  @override
  ValidationRequest rebuild(void Function(ValidationRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ValidationRequestBuilder toBuilder() =>
      ValidationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ValidationRequest &&
        name == other.name &&
        quantity == other.quantity;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, quantity.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ValidationRequest')
          ..add('name', name)
          ..add('quantity', quantity))
        .toString();
  }
}

class ValidationRequestBuilder
    implements Builder<ValidationRequest, ValidationRequestBuilder> {
  _$ValidationRequest? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _quantity;
  int? get quantity => _$this._quantity;
  set quantity(int? quantity) => _$this._quantity = quantity;

  ValidationRequestBuilder() {
    ValidationRequest._defaults(this);
  }

  ValidationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _quantity = $v.quantity;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ValidationRequest other) {
    _$v = other as _$ValidationRequest;
  }

  @override
  void update(void Function(ValidationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ValidationRequest build() => _build();

  _$ValidationRequest _build() {
    final _$result = _$v ??
        _$ValidationRequest._(
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'ValidationRequest', 'name'),
          quantity: BuiltValueNullFieldError.checkNotNull(
              quantity, r'ValidationRequest', 'quantity'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

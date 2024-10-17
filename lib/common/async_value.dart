///
/// Sealed Class AsyncValue which can either be loading, value or error
///

sealed class AsyncValue<T> {
  const AsyncValue();

  bool get isLoading => this is AsyncLoading;

  bool get hasValue => this is Value;

  bool get hasError => this is AsyncError;

  Object? get errorOrNull =>
      this is AsyncError ? (this as AsyncError).error : null;

  T? get valueOrNull => this is Value ? (this as Value).value : null;

  factory AsyncValue.loading() => const AsyncLoading();

  factory AsyncValue.value(T value) => Value(value);

  factory AsyncValue.error(Object error) => AsyncError(error);

  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function(Object error) error,
  }) {
    return switch (this) {
      AsyncLoading() => loading(),
      Value v => data(v.value),
      AsyncError e => error(e.error),
    };
  }

  @override
  String toString() {
    return when(
      loading: () => 'Loading',
      data: (value) => 'Value($value)',
      error: (error) => 'Error($error)',
    );
  }
}

class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading();
}

class Value<T> extends AsyncValue<T> {
  final T value;

  const Value(this.value);
}

class AsyncError<T> extends AsyncValue<T> {
  final Object error;

  const AsyncError(this.error);
}

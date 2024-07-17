///
/// Sealed Class AsyncValue which can either be loading, value or error
///

sealed class AsyncValue<T> {
  const AsyncValue();

  bool get isLoading => this is Loading;

  bool get hasValue => this is Value;

  bool get hasError => this is Error;

  T? get valueOrNull => this is Value ? (this as Value).value : null;

  factory AsyncValue.loading() => const Loading();

  factory AsyncValue.value(T value) => Value(value);

  factory AsyncValue.error(Object error) => Error(error);

  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function(Object error) error,
  }) {
    return switch (this) {
      Loading() => loading(),
      Value v => data(v.value),
      Error e => error(e.error),
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

class Loading<T> extends AsyncValue<T> {
  const Loading();
}

class Value<T> extends AsyncValue<T> {
  final T value;

  const Value(this.value);
}

class Error<T> extends AsyncValue<T> {
  final Object error;

  const Error(this.error);
}

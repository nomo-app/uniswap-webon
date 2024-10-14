import 'package:flutter/widgets.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';

typedef DiffCallback<T> = void Function(T? old, T next);
typedef ValueCallback<T> = void Function(T value);

class ValueDiffNotifier<T> extends ValueNotifier<T> {
  final List<ValueCallback<T>> _valueListeners = [];
  final List<DiffCallback<T>> _diffListeners = [];

  T? _lastValue;

  ValueDiffNotifier(T initialValue) : super(initialValue) {
    addListener(onChanged);
  }

  void dispose() {
    removeListener(onChanged);
    super.dispose();
  }

  void onChanged() {
    for (final listener in _valueListeners) {
      listener(value);
    }
    for (final listener in _diffListeners) {
      listener(_lastValue, value);
    }
    _lastValue = value;
  }

  void addValueListener(ValueCallback<T> listener) {
    _valueListeners.add(listener);
  }

  void removeValueListener(ValueCallback<T> listener) {
    _valueListeners.remove(listener);
  }

  void addDiffListener(DiffCallback<T> listener) {
    _diffListeners.add(listener);
  }

  void removeDiffListener(DiffCallback<T> listener) {
    _diffListeners.remove(listener);
  }
}

class AsyncNotifier<T> extends ValueNotifier<AsyncValue<T>> {
  AsyncNotifier([T? initialValue])
      : super(
          initialValue == null
              ? AsyncLoading()
              : AsyncValue.value(initialValue),
        );

  void setLoading() {
    value = AsyncLoading();
  }

  void setError(Object error) {
    value = AsyncError(error);
  }

  void setValue(T value) {
    this.value = AsyncValue.value(value);
  }
}

class AsyncDiffNotifier<T> extends ValueDiffNotifier<AsyncValue<T>> {
  AsyncDiffNotifier([T? initialValue])
      : super(
          initialValue == null
              ? AsyncLoading()
              : AsyncValue.value(initialValue),
        );

  void setLoading() {
    value = AsyncLoading();
  }

  void setError(Object error) {
    value = AsyncError(error);
  }

  void setValue(T value) {
    this.value = AsyncValue.value(value);
  }
}

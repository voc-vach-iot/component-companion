import 'package:hooks_riverpod/hooks_riverpod.dart';

extension AsyncValueCombine on AsyncValue {
  static AsyncValue<(T1, T2)> combine2<T1, T2>(
    AsyncValue<T1> a,
    AsyncValue<T2> b,
  ) {
    if (a is AsyncError) {
      return AsyncError(a.hashCode, a.stackTrace ?? StackTrace.empty);
    }
    if (b is AsyncError) {
      return AsyncError(b.hashCode, b.stackTrace ?? StackTrace.empty);
    }
    if (a is AsyncLoading || b is AsyncLoading) return const AsyncLoading();
    return AsyncData((a.requireValue, b.requireValue));
  }
}

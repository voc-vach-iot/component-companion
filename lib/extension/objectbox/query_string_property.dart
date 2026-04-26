import 'package:component_companion/objectbox.g.dart';

extension QueryStringPropertyExtension<T> on QueryStringProperty<T> {
  Condition<T> containsIgnorecase(String p, {String? alias}) {
    return contains(p, alias: alias, caseSensitive: false);
  }
}

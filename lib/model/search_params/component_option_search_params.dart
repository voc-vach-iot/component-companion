import 'package:dart_mappable/dart_mappable.dart';

part 'component_option_search_params.mapper.dart';

@MappableClass()
class ComponentOptionSearchParams with ComponentOptionSearchParamsMappable {
  final int? componentId;
  final String name;

  ComponentOptionSearchParams({this.componentId, this.name = ""});
}

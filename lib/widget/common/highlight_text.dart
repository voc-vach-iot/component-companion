import 'package:component_companion/util/text_search.dart';
import 'package:flutter/material.dart';

/// Text có tô sáng các phần khớp với [search].
class HighlightText extends StatelessWidget {
  final String text;
  final TextSearch? search;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const HighlightText(
    this.text, {
    super.key,
    this.search,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  static const highlightColor = Color(0xFFFFE58F);

  @override
  Widget build(BuildContext context) {
    final ranges = search?.highlights(text) ?? const [];
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    final spans = <TextSpan>[];
    var last = 0;
    for (final (start, end) in ranges) {
      if (start > last) spans.add(TextSpan(text: text.substring(last, start)));
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      last = end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

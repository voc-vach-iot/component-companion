import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/catalog_assistant.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nhờ AI tìm / tạo danh mục + loại cho 1 linh kiện. Trả về id danh mục / loại
/// đã chọn (0 = không đổi), null nếu huỷ.
class AiCatalogDialog extends HookConsumerWidget {
  final String name;
  final String description;
  final List<String> attributes;
  final List<Category> categories;
  final List<ComponentType> types;

  const AiCatalogDialog({
    super.key,
    required this.name,
    this.description = "",
    this.attributes = const [],
    required this.categories,
    required this.types,
  });

  static Future<({int categoryId, int typeId})?> show(
    BuildContext context, {
    required String name,
    String description = "",
    List<String> attributes = const [],
    required List<Category> categories,
    required List<ComponentType> types,
  }) => showDialog<({int categoryId, int typeId})>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AiCatalogDialog(
      name: name,
      description: description,
      attributes: attributes,
      categories: categories,
      types: types,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = useMemoized(
      () => AiSettings.load(ref.read(appSettingRepositoryProvider)),
    );
    final assistant = useMemoized(
      () => CatalogAssistant(categories: categories, types: types),
    );
    final prompt = useMemoized(
      () => assistant.buildPrompt(
        name: name,
        description: description,
        attributes: attributes,
      ),
    );

    // Chế độ hỏi tay (sao chép prompt) hay đang / đã gọi API
    final manual = useState(
      settings.mode == AiMode.copyPrompt || !settings.canCallApi,
    );
    final running = useState(false);
    final trying = useState<String?>(null);
    final failure = useState<AiFailedException?>(null);
    final result = useState<CatalogSuggestion?>(null);
    final answerCtrl = useTextEditingController();
    final parseError = useState<String?>(null);
    final useCategory = useState(true);
    final useType = useState(true);
    final categoryName = useTextEditingController();
    final typeName = useTextEditingController();
    final applying = useState(false);

    void showResult(CatalogSuggestion s) {
      result.value = s;
      categoryName.text = s.category.name;
      typeName.text = s.type.name;
      useCategory.value = !s.category.isEmpty;
      useType.value = !s.type.isEmpty;
    }

    Future<void> callApi() async {
      running.value = true;
      failure.value = null;
      try {
        final s = await assistant.ask(
          prompt,
          settings,
          onTry: (m) => trying.value = m,
        );
        if (context.mounted) showResult(s);
      } on AiFailedException catch (e) {
        if (!context.mounted) return;
        failure.value = e;
        manual.value = true;
      } finally {
        if (context.mounted) {
          running.value = false;
          trying.value = null;
        }
      }
    }

    // Chế độ API => hỏi ngay khi mở
    useEffect(() {
      if (!manual.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callApi());
      }
      return null;
    }, const []);

    void readAnswer() {
      try {
        showResult(assistant.parse(answerCtrl.text));
        parseError.value = null;
      } on AppException catch (e) {
        parseError.value = e.message;
      }
    }

    Future<void> apply() async {
      final s = result.value!;
      final edited = CatalogSuggestion(
        category: s.category.isNew
            ? CategorySuggestion(
                name: categoryName.text,
                description: s.category.description,
                color: s.category.color,
                keywords: s.category.keywords,
                iconSvg: s.category.iconSvg,
              )
            : s.category,
        type: s.type.isNew
            ? TypeSuggestion(
                name: typeName.text,
                keywords: s.type.keywords,
                attributes: s.type.attributes,
                iconSvg: s.type.iconSvg,
              )
            : s.type,
        note: s.note,
        model: s.model,
      );
      applying.value = true;
      final ids = await CatalogAssistant.apply(
        edited,
        useCategory: useCategory.value,
        useType: useType.value,
      ).withToast(context);
      if (!context.mounted) return;
      applying.value = false;
      if (ids != null) Navigator.pop(context, ids);
    }

    Widget body() {
      if (running.value) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              "Đang hỏi ${trying.value ?? "..."}",
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        );
      }
      if (result.value case final s?) {
        return _ResultView(
          suggestion: s,
          useCategory: useCategory,
          useType: useType,
          categoryName: categoryName,
          typeName: typeName,
        );
      }
      // Hỏi tay: sao chép prompt -> dán câu trả lời
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failure.value case final f?)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${f.fatal ? "Không gọi được API" : "Không model nào trả lời được"} — "
                "hãy sao chép prompt để hỏi tay.\n${f.summary}",
                style: const TextStyle(fontSize: 12),
              ),
            )
          else if (!settings.canCallApi)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                "Chưa nhập API key Gemini (trang Dữ liệu > Trợ lý AI) — "
                "sao chép prompt để hỏi tay.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          const Text(
            "1. Sao chép prompt, dán vào Gemini / ChatGPT.  "
            "2. Dán câu trả lời (JSON) vào ô dưới rồi bấm \"Đọc câu trả lời\".",
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: "Sao chép prompt",
                icon: Icons.copy_rounded,
                size: ButtonSize.small,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: prompt));
                  if (context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: "Đã sao chép prompt",
                      type: SnackBarType.success,
                    );
                  }
                },
              ),
              AppButton(
                label: "Mở Gemini",
                icon: Icons.open_in_new,
                size: ButtonSize.small,
                variant: ButtonVariant.secondary,
                onPressed: () => launchUrl(
                  Uri.parse("https://gemini.google.com/app"),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              if (settings.canCallApi)
                AppButton(
                  label: "Thử gọi API lại",
                  icon: Icons.refresh_rounded,
                  size: ButtonSize.small,
                  variant: ButtonVariant.secondary,
                  onPressed: callApi,
                ),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text("Xem prompt", style: TextStyle(fontSize: 13)),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: SelectableText(
                    prompt,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          TextField(
            controller: answerCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: "Dán câu trả lời của AI vào đây",
              errorText: parseError.value,
            ),
          ),
        ],
      );
    }

    final hasResult = result.value != null;
    return AppAlertDialog(
      title: "Nhờ AI gợi ý danh mục / loại",
      // Đang gọi AI: đóng = bỏ lượt gọi; có kết quả: đóng = không dùng
      cancelLabel: running.value
          ? "Dừng & đóng"
          : hasResult
          ? "Bỏ kết quả"
          : "Đóng",
      size: AlertDialogSize.big,
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(child: body()),
      ),
      actions: [
        if (hasResult)
          AppButton(
            label: "Hỏi lại",
            size: ButtonSize.small,
            variant: ButtonVariant.secondary,
            onPressed: () {
              result.value = null;
              if (!manual.value) callApi();
            },
          ),
        if (hasResult)
          AppButton(
            label: "Áp dụng",
            size: ButtonSize.small,
            variant: ButtonVariant.primary,
            isDisabled:
                applying.value || (!useCategory.value && !useType.value),
            onPressed: apply,
          )
        else if (manual.value && !running.value)
          AppButton(
            label: "Đọc câu trả lời",
            size: ButtonSize.small,
            variant: ButtonVariant.primary,
            onPressed: readAnswer,
          ),
      ],
    );
  }
}

class _ResultView extends HookWidget {
  final CatalogSuggestion suggestion;
  final ValueNotifier<bool> useCategory;
  final ValueNotifier<bool> useType;
  final TextEditingController categoryName;
  final TextEditingController typeName;

  const _ResultView({
    required this.suggestion,
    required this.useCategory,
    required this.useType,
    required this.categoryName,
    required this.typeName,
  });

  @override
  Widget build(BuildContext context) {
    useListenable(Listenable.merge([useCategory, useType]));
    final c = suggestion.category;
    final t = suggestion.type;

    Widget card({
      required ValueNotifier<bool> enabled,
      required String heading,
      required bool empty,
      required bool isNew,
      required String existingName,
      required TextEditingController nameCtrl,
      required String svg,
      Color? color,
      required List<String> keywords,
      required List<String> addKeywords,
      List<String> attributes = const [],
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: enabled.value && !empty,
              onChanged: empty ? null : (v) => enabled.value = v ?? false,
            ),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (color ?? AppColors.surfaceVariant).withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppSvgIcon(svg: svg, fallbackSvg: AppSvgs.chip, size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (empty)
                    const Text("AI không gợi ý")
                  else if (isNew)
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "Tạo mới với tên",
                      ),
                    )
                  else
                    Text(
                      "Dùng có sẵn: $existingName",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (isNew && keywords.isNotEmpty)
                    Text(
                      "Từ khoá: ${keywords.join(", ")}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (!isNew && addKeywords.isNotEmpty)
                    Text(
                      "Thêm từ khoá: ${addKeywords.join(", ")}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (attributes.isNotEmpty)
                    Text(
                      "Thuộc tính gợi ý: ${attributes.join(", ")}",
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suggestion.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(suggestion.note, style: const TextStyle(fontSize: 13)),
          ),
        card(
          enabled: useCategory,
          heading: c.isNew ? "DANH MỤC MỚI" : "DANH MỤC",
          empty: c.isEmpty,
          isNew: c.isNew,
          existingName: c.existing?.name ?? "",
          nameCtrl: categoryName,
          svg: c.existing?.iconSvg ?? c.iconSvg,
          color: c.existing?.color ?? (c.isNew ? c.color.color : null),
          keywords: c.keywords,
          addKeywords: c.addKeywords,
        ),
        card(
          enabled: useType,
          heading: t.isNew ? "LOẠI MỚI" : "LOẠI LINH KIỆN",
          empty: t.isEmpty,
          isNew: t.isNew,
          existingName: t.existing?.name ?? "",
          nameCtrl: typeName,
          svg: t.existing?.defaultIconSvg ?? t.iconSvg,
          keywords: t.keywords,
          addKeywords: t.addKeywords,
          attributes: t.isNew ? t.attributes : const [],
        ),
        if (suggestion.model.isNotEmpty)
          Text(
            "Trả lời bởi ${suggestion.model}",
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

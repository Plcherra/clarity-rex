import '../../../../l10n/app_localizations.dart';
import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';

/// Hard display/storage cap for chat titles in the sidebar and rename flow.
const int kConversationTitleMaxLength = 48;

String clampConversationTitle(
  String value, {
  int maxLength = kConversationTitleMaxLength,
}) {
  final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty || cleaned.length <= maxLength) {
    return cleaned;
  }

  final hard = cleaned.substring(0, maxLength - 1);
  final breakAt = hard.lastIndexOf(' ');
  final truncated = breakAt > maxLength ~/ 2
      ? hard.substring(0, breakAt)
      : hard;
  return '${truncated.replaceAll(RegExp(r'[.,;:\s]+$'), '')}…';
}

String conversationTitle(
  AppLocalizations l10n,
  Conversation conversation, {
  int maxLength = kConversationTitleMaxLength,
}) {
  final title = conversation.title?.trim();
  if (title != null && title.isNotEmpty) {
    return clampConversationTitle(title, maxLength: maxLength);
  }

  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return clampConversationTitle(preview, maxLength: maxLength);
  }

  return l10n.conversationHistoryNewConversation;
}

String conversationSearchResultTitle(
  AppLocalizations l10n,
  ConversationSearchResult result, {
  int maxLength = kConversationTitleMaxLength,
}) {
  final title = result.conversationTitle?.trim();
  if (title != null && title.isNotEmpty) {
    return clampConversationTitle(title, maxLength: maxLength);
  }

  final message = result.message?.content.trim();
  if (message != null && message.isNotEmpty) {
    return clampConversationTitle(message, maxLength: maxLength);
  }

  return l10n.commonConversation;
}

String conversationPreview(AppLocalizations l10n, Conversation conversation) {
  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }
  return l10n.conversationHistoryNoMessagesYet;
}

String timestampLabel(AppLocalizations l10n, DateTime? timestamp) {
  if (timestamp == null) {
    return '';
  }

  final local = timestamp.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (date == today) {
    return '$hour:$minute';
  }
  if (date.year == today.year) {
    return '${localizedShortMonthName(l10n, local.month)} ${local.day}';
  }
  return '${localizedShortMonthName(l10n, local.month)} ${local.day}, ${local.year}';
}

String conversationGroupLabel(
  AppLocalizations l10n,
  DateTime? timestamp,
  DateTime now,
) {
  if (timestamp == null) {
    return l10n.commonUndated;
  }

  final local = timestamp.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final dayDifference = today.difference(date).inDays;

  if (dayDifference < 0) {
    return l10n.commonUpcoming;
  }
  if (dayDifference == 0) {
    return l10n.commonToday;
  }
  if (dayDifference == 1) {
    return l10n.commonYesterday;
  }
  if (dayDifference < 7) {
    return l10n.commonThisWeek;
  }
  return l10n.commonMonthYear(
    localizedMonthName(l10n, local.month),
    local.year.toString(),
  );
}

String conversationDateFilterLabel(
  AppLocalizations l10n,
  ConversationDateFilter filter,
  DateTime now,
) {
  return switch (filter.type) {
    ConversationDateFilterType.all => l10n.commonAll,
    ConversationDateFilterType.today => l10n.commonToday,
    ConversationDateFilterType.thisWeek => l10n.commonThisWeek,
    ConversationDateFilterType.thisMonth => l10n.commonThisMonth,
    ConversationDateFilterType.custom => _customDateFilterChipLabel(l10n, filter),
  };
}

String _customDateFilterChipLabel(
  AppLocalizations l10n,
  ConversationDateFilter filter,
) {
  final startDate = filter.start;
  final endDate = filter.end;
  if (startDate == null || endDate == null) {
    return l10n.commonCustom;
  }

  final normalizedStart = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );
  final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
  if (normalizedStart == normalizedEnd) {
    return l10n.conversationDateFilterCustomSingle(
      '${normalizedStart.month}/${normalizedStart.day}/${normalizedStart.year}',
    );
  }
  return l10n.conversationDateFilterCustomRange(
    '${normalizedStart.month}/${normalizedStart.day}',
    '${normalizedEnd.month}/${normalizedEnd.day}',
  );
}

String localizedMonthName(AppLocalizations l10n, int month) {
  return switch (month) {
    DateTime.january => l10n.commonMonthJanuary,
    DateTime.february => l10n.commonMonthFebruary,
    DateTime.march => l10n.commonMonthMarch,
    DateTime.april => l10n.commonMonthApril,
    DateTime.may => l10n.commonMonthMay,
    DateTime.june => l10n.commonMonthJune,
    DateTime.july => l10n.commonMonthJuly,
    DateTime.august => l10n.commonMonthAugust,
    DateTime.september => l10n.commonMonthSeptember,
    DateTime.october => l10n.commonMonthOctober,
    DateTime.november => l10n.commonMonthNovember,
    DateTime.december => l10n.commonMonthDecember,
    _ => l10n.commonOlder,
  };
}

String localizedShortMonthName(AppLocalizations l10n, int month) {
  return switch (month) {
    DateTime.january => l10n.commonMonthShortJan,
    DateTime.february => l10n.commonMonthShortFeb,
    DateTime.march => l10n.commonMonthShortMar,
    DateTime.april => l10n.commonMonthShortApr,
    DateTime.may => l10n.commonMonthShortMay,
    DateTime.june => l10n.commonMonthShortJun,
    DateTime.july => l10n.commonMonthShortJul,
    DateTime.august => l10n.commonMonthShortAug,
    DateTime.september => l10n.commonMonthShortSep,
    DateTime.october => l10n.commonMonthShortOct,
    DateTime.november => l10n.commonMonthShortNov,
    DateTime.december => l10n.commonMonthShortDec,
    _ => l10n.commonMonthShortOld,
  };
}

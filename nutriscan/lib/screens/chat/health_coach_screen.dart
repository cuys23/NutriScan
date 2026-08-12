import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/chat_message.dart';
import 'package:nutriscan/providers/chat/chat_provider.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/food/meal_plan_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// ─────────────────────────────────────────────────────────────
/// Slow Kitchen — Health Coach View / Screen
/// Interactive AI Chat directly embedded into Coach Tab
/// ─────────────────────────────────────────────────────────────
class HealthCoachScreen extends StatefulWidget {
  final bool showAppBar;

  const HealthCoachScreen({super.key, this.showAppBar = true});

  @override
  State<HealthCoachScreen> createState() => _HealthCoachScreenState();
}

class _HealthCoachScreenState extends State<HealthCoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _buildUserContext(BuildContext context) {
    final foodProvider = context.read<FoodProvider>();
    final mealPlanProvider = context.read<MealPlanProvider>();

    final target = mealPlanProvider.calorieTarget;
    final dietStyle = mealPlanProvider.dietStyle;
    final restrictions = mealPlanProvider.restrictions;

    final allFoods = foodProvider.foods;
    final todayFoods = foodProvider.getTodayFoodsSync();
    final todayCals = foodProvider.getTodayCaloriesSync();

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentFoods =
        allFoods.where((f) => f.analyzedAt.isAfter(sevenDaysAgo)).toList();

    double avgCals = 0;
    double avgProtein = 0;
    double avgCarbs = 0;
    double avgFat = 0;

    if (recentFoods.isNotEmpty) {
      final daysWithData = recentFoods
          .map((f) =>
              "${f.analyzedAt.year}-${f.analyzedAt.month}-${f.analyzedAt.day}")
          .toSet()
          .length;
      final totalRecentCals =
          recentFoods.fold(0.0, (sum, f) => sum + f.calories);
      final totalRecentProtein =
          recentFoods.fold(0.0, (sum, f) => sum + f.protein);
      final totalRecentCarbs = recentFoods.fold(0.0, (sum, f) => sum + f.carbs);
      final totalRecentFat = recentFoods.fold(0.0, (sum, f) => sum + f.fat);

      avgCals = totalRecentCals / (daysWithData > 0 ? daysWithData : 1);
      avgProtein = totalRecentProtein / (daysWithData > 0 ? daysWithData : 1);
      avgCarbs = totalRecentCarbs / (daysWithData > 0 ? daysWithData : 1);
      avgFat = totalRecentFat / (daysWithData > 0 ? daysWithData : 1);
    }

    final foodCounts = <String, int>{};
    for (var f in allFoods) {
      foodCounts[f.name] = (foodCounts[f.name] ?? 0) + 1;
    }
    final topFoods = (foodCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => e.key)
        .toList();

    String contextStr = "USER PROFILE & GOALS:\n";
    contextStr += "- Calorie Target: ${target.round()} kcal/day\n";
    contextStr += "- Diet Style: $dietStyle\n";
    if (restrictions.isNotEmpty) {
      contextStr += "- Restrictions: ${restrictions.join(", ")}\n";
    }

    contextStr += "\nTODAY'S PROGRESS:\n";
    contextStr += "- Foods Logged: ${todayFoods.length}\n";
    contextStr += "- Calories Consumed: ${todayCals.round()} kcal\n";
    if (todayFoods.isNotEmpty) {
      contextStr +=
          "- Today's Items: ${todayFoods.map((f) => f.name).join(", ")}\n";
    }

    contextStr += "\n7-DAY AVERAGES:\n";
    contextStr += "- Avg Calories: ${avgCals.round()} kcal/day\n";
    contextStr +=
        "- Avg Protein: ${avgProtein.round()}g, Carbs: ${avgCarbs.round()}g, Fat: ${avgFat.round()}g\n";

    if (topFoods.isNotEmpty) {
      contextStr += "\nTOP FREQUENT FOODS: ${topFoods.join(", ")}\n";
    }

    return contextStr;
  }

  void _sendMessage([String? customText]) {
    final content = customText ?? _messageController.text.trim();
    if (content.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final userContext = _buildUserContext(context);

    chatProvider.sendMessage(
      content,
      userContext: userContext,
      language: languageProvider.currentLanguage,
    );

    if (customText == null) {
      _messageController.clear();
    }
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, ChatProvider>(
      builder: (context, tp, languageProvider, chatProvider, child) {
        final d = tp.isDarkMode;
        final lang = languageProvider.currentLanguage;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (chatProvider.messages.isNotEmpty) {
            _scrollToBottom();
          }
        });

        final bodyWidget = Column(
          children: [
            // Header for tab view
            if (!widget.showAppBar) _buildHeader(tp, d, lang, chatProvider),

            // Main chat content
            Expanded(
              child: chatProvider.messages.isEmpty
                  ? _buildQuickPromptsView(tp, d, lang)
                  : _buildChatList(chatProvider, tp, d, lang),
            ),

            // SK Input area
            _buildInputArea(tp, d, chatProvider, lang),
          ],
        );

        if (!widget.showAppBar) {
          return SafeArea(child: bodyWidget);
        }

        return Scaffold(
          backgroundColor: AppColors.skPaper(d),
          appBar: AppBar(
            backgroundColor: AppColors.skPaper(d),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.skInk(d)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              AppLocalizations.getString('health_coach_title', lang),
              style: tp.getSerifFont(
                fontSize: 22,
                color: AppColors.skInk(d),
              ),
            ),
            actions: [
              if (chatProvider.messages.isNotEmpty)
                IconButton(
                  icon: Icon(IconlyLight.delete, color: AppColors.skInk(d)),
                  onPressed: () =>
                      _showClearChatDialog(context, chatProvider, lang),
                  tooltip: AppLocalizations.getString('clear', lang),
                ),
            ],
          ),
          body: bodyWidget,
        );
      },
    );
  }

  Widget _buildHeader(
      ThemeProvider tp, bool d, String lang, ChatProvider chatProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR COACH',
                style: tp.getSkLabel(color: AppColors.skMuted(d)),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask me anything',
                style: tp.getSerifFont(
                  fontSize: 28,
                  color: AppColors.skInk(d),
                ),
              ),
            ],
          ),
          if (chatProvider.messages.isNotEmpty)
            IconButton(
              icon: Icon(IconlyLight.delete,
                  color: AppColors.skMuted(d), size: 22),
              onPressed: () =>
                  _showClearChatDialog(context, chatProvider, lang),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsView(ThemeProvider tp, bool d, String lang) {
    final prompts = [
      'How am I doing today?',
      'Are these numbers reliable?',
      'What should I change this week?',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK PROMPTS',
            style: tp.getSkLabel(fontSize: 11, color: AppColors.skMuted(d)),
          ),
          const SizedBox(height: 12),
          ...prompts.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _sendMessage(text),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.skSurface(d),
                    border: Border.all(color: AppColors.skRule(d)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: tp.getBodyFont(
                            fontSize: 15,
                            color: AppColors.skInk(d),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.skMuted(d),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Answers draw on your logged meals and nutrition data. This is not medical advice.',
            style: tp.getBodyFont(
              fontSize: 13,
              color: AppColors.skMuted(d),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(
      ChatProvider chat, ThemeProvider tp, bool d, String lang) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (chat.isLoading && index == chat.messages.length) {
          return _buildTypingIndicator(tp, d, lang);
        }
        final message = chat.messages[index];
        return _buildMessageBubble(message, tp, d);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeProvider tp, bool d) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(false, d),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.skInk(d) : AppColors.skSurface(d),
                    border: isUser
                        ? null
                        : Border.all(color: AppColors.skRule(d)),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser ? 16 : 2),
                      topRight: Radius.circular(isUser ? 2 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                  ),
                  child: isUser
                      ? SelectableText(
                          message.content,
                          style: tp.getBodyFont(
                            color: AppColors.skPaper(d),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: tp.getBodyFont(
                              color: AppColors.skInk(d),
                              fontSize: 15,
                              height: 1.4,
                            ),
                            strong: tp.getBodyFont(
                              color: AppColors.skInk(d),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            em: tp.getBodyFont(
                              color: AppColors.skInk(d),
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                            listBullet: tp.getBodyFont(
                              color: AppColors.skInk(d),
                              fontSize: 15,
                            ),
                            h1: tp.getSerifFont(
                              color: AppColors.skInk(d),
                              fontSize: 22,
                            ),
                            h2: tp.getSerifFont(
                              color: AppColors.skInk(d),
                              fontSize: 20,
                            ),
                            h3: tp.getSerifFont(
                              color: AppColors.skInk(d),
                              fontSize: 18,
                            ),
                            code: tp.getBodyFont(
                              color: AppColors.skInk(d),
                              fontSize: 14,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: AppColors.skPaper(d),
                              border: Border.all(color: AppColors.skRuleSoft(d)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            blockquote: tp.getBodyFont(
                              color: AppColors.skMuted(d),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('hh:mm a').format(message.timestamp),
                  style: tp.getBodyFont(
                    fontSize: 10,
                    color: AppColors.skMuted(d),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildAvatar(true, d),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser, bool d) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppColors.skInk(d) : AppColors.skSurface(d),
        border: isUser ? null : Border.all(color: AppColors.skRule(d)),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isUser ? IconlyBold.profile : Icons.smart_toy_outlined,
          size: 16,
          color: isUser ? AppColors.skPaper(d) : AppColors.skInk(d),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeProvider tp, bool d, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildAvatar(false, d),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.getString('typing', lang),
            style: tp.getBodyFont(
              fontSize: 13,
              color: AppColors.skMuted(d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
      ThemeProvider tp, bool d, ChatProvider chat, String lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.skPaper(d),
        border: Border(top: BorderSide(color: AppColors.skRuleSoft(d))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.skSurface(d),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.skRule(d)),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.getString('chat_placeholder', lang),
                  hintStyle: tp.getBodyFont(
                    color: AppColors.skMuted(d),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
                style: tp.getBodyFont(
                  color: AppColors.skInk(d),
                  fontSize: 14,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: chat.isLoading ? null : () => _sendMessage(),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.skInk(d),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: chat.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.skPaper(d),
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        IconlyBold.send,
                        color: AppColors.skPaper(d),
                        size: 18,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog(
      BuildContext context, ChatProvider chat, String lang) {
    final tp = context.read<ThemeProvider>();
    final d = tp.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.skPaper(d),
            border: Border.all(color: AppColors.skRule(d)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconlyLight.delete,
                size: 40,
                color: AppColors.skAccent(d),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.getString('chat_clear_confirm', lang),
                style: tp.getSerifFont(
                  fontSize: 22,
                  color: AppColors.skInk(d),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.getString('chat_clear_description', lang),
                style: tp.getBodyFont(
                  fontSize: 14,
                  color: AppColors.skBody(d),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.skRule(d)),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.getString('cancel', lang),
                            style: tp.getBodyFont(
                              fontSize: 14,
                              color: AppColors.skInk(d),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        chat.clearChat();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.skInk(d),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.getString('clear', lang),
                            style: tp.getBodyFont(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.skPaper(d),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

repo: cuys23/NutriScan
branch: main
path: nutriscan/lib

## Last sync
date: 2026-08-10T09:36:27Z

### Updated in this project
- Recreated Home (app bar, today's nutrition card, food detail cards, FAB, bottom nav) as an iOS-simulator demo
- Recreated History (search + sort + total pill + card list) and the scan bottom sheet
- Recreated Analysis in full: period/metric selectors + Overview (Total Nutrition, macronutrient donut, Top Foods), Trends (line chart, Trend Analysis) and Insights (health-score bars, insight cards)
- Recreated Settings: App Settings, Subscription, Ad for Rewards (coin card), Data & Privacy, About, disclaimer
- Recreated the Health Coach chat screen (welcome view, user/coach bubbles, typing indicator, rounded input + gradient send button)
- Added a new animated camera capture → scan → verified-result reveal flow

## Screen map
| Project screen | Repo files |
|---|---|
| Home tab | lib/screens/main/home_screen.dart, lib/widgets/food/nutrition_summary_card.dart, lib/widgets/food/food_list.dart, lib/widgets/food/food_detail_card.dart, lib/widgets/food/source_badge.dart |
| Scan sheet | lib/screens/main/home_screen.dart (_showImageSourceDialog), lib/widgets/home/image_source_button.dart |
| Scanning / loading states | lib/screens/main/home_screen.dart (_buildLoadingView, _buildMainContentWithLoading) |
| History tab | lib/screens/history/history_screen.dart, lib/widgets/food/food_detail_card.dart |
| Analysis tab | lib/screens/analysis/analysis_screen.dart, lib/widgets/analysis/period_selector.dart, metric_selector.dart, trend_chart.dart, trend_item.dart, health_score_chart.dart |
| Settings tab | lib/screens/settings/settings_screen.dart, lib/widgets/settings/settings_card.dart, lib/widgets/common/section_header.dart, lib/widgets/common/language_dropdown.dart |
| Tab bar / shell | lib/screens/main/main_navigation.dart, lib/providers/theme/theme_provider.dart, lib/config/app_colors.dart |
| Health Coach chat | lib/screens/chat/health_coach_screen.dart, lib/models/chat_message.dart, lib/providers/chat/chat_provider.dart |
| UI strings | lib/config/app_localizations.dart ('en' map) |

## Notes
- Icons are SVG approximations of Iconly / Material icons (both come from packages, no icon assets in the repo); food photos use the repo's own grey image fallback.
- Analysis sub-pages are a TabBarView (swipe-only) in the app; the demo adds tappable page dots so they are reachable with a mouse.
- Camera capture screen and scan-sweep motion are new design, not present in the current code.
- Dark mode, notification/cloud-backup/subscription sub-screens and the meal-plan generator are not recreated.

class AppLocalizations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Settings Screen
      'settings': 'Settings',
      'app_settings': 'App Settings',
      'dark_mode': 'Dark Mode',
      'dark_mode_subtitle': 'Switch between light and dark themes',
      'language': 'Language',
      'language_subtitle': 'Select your preferred language',
      'data_privacy': 'Data & Privacy',
      'cloud_backup_settings': 'Cloud Backup',
      'cloud_backup_settings_subtitle': 'Backup and restore your data',
      'clear_all_data': 'Clear All Data',
      'clear_all_data_subtitle': 'Delete all food history and settings',
      'clear_all_data_description':
          'This action cannot be undone. All your food history and settings will be permanently deleted.',
      'clear_all': 'Clear All',
      'logout': 'Logout',
      'logout_subtitle': 'Sign out from Google account',
      'logout_title': 'Logout',
      'logout_description':
          'Are you sure you want to sign out from your Google account? You will need to sign in again to use cloud backup features.',

      // Delete Account (App Store Guideline 5.1.1(v))
      'delete_account': 'Delete Account',
      'delete_account_subtitle':
          'Permanently delete your account and all data',
      'delete_account_title': 'Delete Account?',
      'delete_account_description':
          'This permanently deletes your account and all associated data: food history, cloud backups, saved images and settings. This cannot be undone.',
      'delete_account_confirm_hint': 'Type DELETE to confirm',
      'delete_account_confirm_word': 'DELETE',
      'delete_account_button': 'Delete Permanently',
      'delete_account_deleting': 'Deleting your account...',
      'delete_account_success': 'Your account and data have been deleted.',
      'delete_account_failed':
          'Could not delete your account. Please check your connection and try again.',
      'delete_account_requires_login':
          'For your security, please sign in again and then retry deleting your account.',
      'delete_account_purchase_note':
          'Active subscriptions are managed by the App Store and are not cancelled by deleting your account. Cancel them in your device Settings.',
      'about': 'About',
      'privacy_policy': 'Privacy Policy',
      'privacy_policy_subtitle': 'Read our privacy guidelines',
      'terms_of_service': 'Terms of Service',
      'terms_of_service_subtitle': 'Read our terms and conditions',
      'app_version': 'App Version',
      'app_version_subtitle': '1.0.0',

      // App Version Screen
      'version': 'Version',
      'build_number': 'Build Number',
      'developer': 'Developer',
      'platform_support': 'Platform Support',
      'app_details': 'App Details',
      'check_for_updates': 'Check for Updates',
      'checking_for_updates': 'Checking for updates...',

      // History Screen
      'food_history': 'Food History',
      'loading': 'Loading...',
      'loading_subtitle': 'Preparing your food history...',
      'refreshing': 'Refreshing...',
      'updating': 'Updating your food history...',
      'search_foods': 'Search foods...',
      'sort_by_date': 'Sort by Date',
      'sort_by_name': 'Sort by Name',
      'sort_by_calories': 'Sort by Calories',
      'total': 'Total',
      'no_food_history': 'No food history yet',
      'no_foods_found': 'No foods found',
      'no_history_subtitle': 'Start adding food to see your complete history',
      'no_foods_subtitle': 'Try adjusting your search terms',
      'clear_all_history': 'Clear All History',
      'clear_history_description':
          'Are you sure you want to delete all food history? This action cannot be undone.',
      'delete_all': 'Delete All',

      // FoodDetailCard
      'score': 'Score',
      'description': 'Description',
      'no_description_available': 'No description available',
      'nutrition': 'Nutrition',
      'source_verified': 'Verified',
      'source_estimated': 'AI estimate',
      'source_user_edited': 'Edited by you',
      'source_verified_subtitle': 'Based on verified food database data',
      'nutrition_disclaimer_short':
          'Nutrition values are estimates for informational purposes only, not medical advice.',

      // Multi-food review sheet (docs/plan.md Phase 7A)
      'multi_food_review_title': 'We found multiple foods',
      'multi_food_review_subtitle': 'Uncheck anything that isn\'t part of your meal',
      'multi_food_review_save': 'Save selected',
      'multi_food_review_cancel': 'Cancel',
      'multi_food_review_save_error': 'Couldn\'t save your selection. Please try again.',
      'pending_multi_food_review_message': 'Finish reviewing your last scan before starting a new one.',
      'calories': 'Calories',
      'protein': 'Protein',
      'carbs': 'Carbs',
      'fat': 'Fat',
      'fiber': 'Fiber',
      'sugar': 'Sugar',
      'sodium': 'Sodium',
      'health_benefits': 'Health Benefits',
      'health_warnings': 'Health Warnings',
      'serving_size': 'Serving Size',
      'date': 'Date',
      'delete_food': 'Delete Food',
      'delete_food_description': 'Are you sure you want to delete',
      'delete_confirmation': 'Are you sure you want to delete',

      // Home Screen
      'todays_food': 'Today\'s Food',
      'no_food_today': 'No food added today',
      'start_with_photo': 'Start by taking a food photo',
      'try_again': 'Try Again',
      'internet_check':
          'If the problem persists, please check your internet connection',

      // Home Screen Additional
      'choose_method': 'Choose Your Method',
      'select_scan_method': 'Select how you want to scan your food',
      'camera': 'Camera',
      'take_photo': 'Take a photo',
      'gallery': 'Gallery',
      'choose_existing': 'Choose existing',
      'camera_error': 'Camera error',
      'gallery_error': 'Gallery error',
      'clear_todays_data': 'Clear Today\'s Data',
      'clear_todays_data_description':
          'Are you sure you want to delete all food data for today?',
      'hello': 'Hello, 👋',
      'calorie_tracker': 'NutriSnap',
      'clear_todays_data_tooltip': 'Clear Today\'s Data',
      'app_info_tooltip': 'App Info',
      'app_information': 'App Information',
      'calorie_tracker_version': 'NutriSnap v1.0.0',
      'app_description':
          'An AI-powered nutrition analysis app that scans food images to provide detailed nutritional information.',
      'features': 'Features:',
      'camera_gallery_support': 'Camera and gallery image support',
      'ai_nutrition_analysis': 'AI-powered nutrition analysis',
      'daily_nutrition_tracking': 'Daily nutrition tracking',

      // Daily Progress Notification
      'daily_progress': 'Daily Progress',
      'daily_progress_subtitle': 'Get daily calorie summary at 21:00',
      'daily_progress_message': 'You have eaten {calories} calories today',

      // Inactivity Notification
      'inactivity_reminder': 'Inactivity Reminder',
      'inactivity_reminder_subtitle':
          'Get reminded at 10:00 if inactive for 24h',
      'inactivity_reminder_message':
          'We missed you! Would you like to register a meal today? 📸',

      // Weekly Summary Notification
      'weekly_summary': 'Weekly Summary',
      'weekly_summary_subtitle': 'Get weekly summary every Sunday at 18:00',
      'weekly_summary_message':
          'Weekly Summary: {foods} meals, avg {calories} cal/day. Keep it up! 🎉',

      // Monthly Summary Notification
      'monthly_summary': 'Monthly Summary',
      'monthly_summary_subtitle':
          'Get monthly summary on 1st of each month at 18:00',
      'monthly_summary_message':
          '{month} ended! {foods} meals registered. View full report.',

      // Premium Promotion Notification
      'premium_promotion': 'Premium Promotion',
      'premium_promotion_subtitle': 'Get premium offers every Tuesday at 11:00',
      'premium_promotion_message': 'Try Premium and get unlimited reports! 🚀',
      'upgrade_required': 'Upgrade Required',
      'upgrade_to_disable_promotion':
          'To disable promotional notifications, please upgrade to Premium. Premium users can customize all notification settings.',
      'upgrade_now': 'Upgrade Now',

      // Report Screens
      'last_7_days': 'Last 7 Days',
      'weekly_report': 'Weekly Report',
      'monthly_report': 'Monthly Report',
      'statistics': 'Statistics',
      'daily_breakdown': 'Daily Breakdown',
      'all_meals': 'All Meals',
      'avg_calories_per_day': 'Average Calories/Day',
      'total_meals': 'Total Meals',
      'total_calories': 'Total Calories',
      'meals': 'Meals',
      'avg_cal_day': 'Avg Cal/Day',
      'cal': 'cal',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'days_ago': '{days} days ago',
      'last_month': 'Last Month',
      'no_meals_recorded_week': 'No meals recorded in the last 7 days',
      'no_meals_recorded_month': 'No meals recorded this month',
      'no_data_available': 'No data available',
      'premium_feature': 'Premium Feature',
      'premium_reports_only':
          'Weekly and Monthly reports are available for Premium users only',
      'upgrade_to_premium': 'Upgrade to Premium',
      'unlock_detailed_reports':
          'Unlock detailed reports, advanced analytics, and exclusive features!',

      // Month Names
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',

      // Analysis Screen
      'analysis': 'Analysis',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
      'trends': 'Trends',
      'insights': 'Insights',
      'total_nutrition': 'Total Nutrition',
      'top_foods': 'Top Foods',
      'trend_analysis': 'Trend Analysis',
      'average_calories': 'Average Calories',
      'insufficient_data': 'Insufficient data for trend analysis',
      'no_data_for_analysis': 'No data for analysis',
      'start_adding_food_analysis': 'Start adding food to see your analysis',
      'macronutrient_distribution': 'Macronutrient Distribution',
      'health_score_distribution': 'Health Score Distribution',
      'analysis_info': 'Analysis Information',
      'analysis_info_description':
          'This analysis screen provides comprehensive insights into your food consumption patterns, nutrition trends, and health recommendations.',
      'meal_plan': 'Meal Plans',
      'meal_plan_settings_title': 'AI Meal Plans',
      'meal_plan_settings_subtitle':
          'Generate a personalized daily menu with AI guidance.',
      'meal_plan_result_title': 'Your Meal Plan',
      'meal_plan_generator_title': 'AI Meal Plan Generator',
      'meal_plan_generator_subtitle':
          'Blend your calorie goals, dietary style, and restrictions. We’ll design a delicious, balanced plan tailored for today.',
      'meal_plan_generator_prompt':
          'Set your preferences, hit generate, and receive a chef-curated nutrition roadmap in seconds.',
      'target_calories_label': 'Daily calorie target',
      'target_calories_helper':
          'Tip: adjust between 1,200 – 3,500 kcal to match your energy needs.',
      'diet_style_label': 'Preferred diet style',
      'diet_balanced': 'Balanced',
      'diet_high_protein': 'High Protein',
      'diet_low_carb': 'Low Carb',
      'diet_keto': 'Keto',
      'diet_vegetarian': 'Vegetarian',
      'diet_vegan': 'Vegan',
      'diet_mediterranean': 'Mediterranean',
      'meals_per_day_label': 'Meals & snacks per day',
      'avoid_foods_label': 'Foods to avoid or allergies',
      'avoid_foods_hint': 'e.g. peanuts, shellfish, red meat',
      'avoid_foods_helper':
          'Separate each item with a comma. We will never include these ingredients.',
      'generate_meal_plan': 'Generate plan',
      'meal_plan_generating': 'Designing your meal plan...',
      'meal_plan_generating_subtitle':
          'Balancing macros, flavors, and hydration reminders just for you.',
      'meal_plan_generating_button': 'Creating your meal plan...',
      'meal_plan_error_title': 'We could not build a plan',
      'meal_plan_empty_title': 'Ready for a personalized meal plan?',
      'meal_plan_empty_subtitle':
          'Choose your calorie goal, diet style, and restrictions, then tap generate to get started.',
      'meal_plan_suggested_for_you':
          'Suggested for you based on your food history',
      'active_meal_plan': 'Today\'s Meal Plan',
      'view_meal_plan': 'View Details',
      'hydration_and_tips': 'Hydration & lifestyle reminders',
      'grocery_list_label': 'Smart grocery list',
      'ingredients_label': 'Ingredients',
      'instructions_label': 'How to prepare',
      'meal_type_breakfast': 'Breakfast',
      'meal_type_lunch': 'Lunch',
      'meal_type_dinner': 'Dinner',
      'meal_type_snack': 'Snack',
      'meal_type_generic': '{meal}',
      'overview_tab': 'Overview Tab',
      'overview_description_1':
          'View your daily nutrition summary with macronutrient distribution',
      'overview_description_2':
          'See top consumed foods and their nutritional values',
      'overview_description_3': 'Get a quick health score assessment',
      'trends_tab': 'Trends Tab',
      'trends_description_1': 'Analyze your nutrition patterns over time',
      'trends_description_2': 'View calorie and nutrient consumption trends',
      'trends_description_3': 'Identify patterns in your eating habits',
      'insights_tab': 'Insights Tab',
      'insights_description_1': 'Get personalized health recommendations',
      'insights_description_2': 'View detailed nutrition analysis and scores',
      'insights_description_3': 'Understand your overall health metrics',
      'period_selector': 'Time Period Selection',
      'period_selector_description_1':
          'Choose between week, month, or year views',
      'period_selector_description_2':
          'Compare data across different time periods',
      'metric_selector': 'Nutrition Metrics',
      'metric_selector_description_1':
          'Focus on specific nutrients: calories, protein, carbs, or fat',
      'metric_selector_description_2':
          'Track your progress in different nutrition areas',
      'analysis_tip':
          'Tip: Use different time periods to spot long-term trends',
      'quick_navigation': 'Quick Navigation',
      'overview': 'Overview',
      'tools': 'Tools',
      'analysis_tools': 'Analysis Tools',
      'got_it': 'Got it!',
      'analyzing_data': 'Analyzing Data',
      'generating_insights': 'Generating personalized insights...',
      'excellent_health_choices': 'Excellent Health Choices',
      'excellent_health_description':
          'Your food choices have an average health score of {score}/10. Keep up the great work!',
      'good_health_choices': 'Good Health Choices',
      'good_health_description':
          'Your food choices have an average health score of {score}/10. Consider adding more nutritious options.',
      'health_improvement_needed': 'Health Improvement Needed',
      'health_improvement_description':
          'Your food choices have an average health score of {score}/10. Focus on more nutritious foods.',
      'great_food_variety': 'Great Food Variety',
      'great_variety_description':
          'You\'re eating a diverse range of foods. This helps ensure balanced nutrition.',
      'limited_food_variety': 'Limited Food Variety',
      'limited_variety_description':
          'Consider adding more variety to your diet for better nutritional balance.',
      'high_calorie_intake': 'High Calorie Intake',
      'high_calorie_description':
          'Your total calorie intake is {calories} kcal. Consider portion control.',
      'low_calorie_intake': 'Low Calorie Intake',
      'low_calorie_description':
          'Your total calorie intake is {calories} kcal. Ensure you\'re meeting your daily needs.',
      'food_history_management': 'Food history management',

      // Loading and Scanning Text
      'preparing_food_data': 'Preparing your food data...',
      'scanning': 'Scanning...',
      'scanning_food_image': 'Scanning your food image...',
      'loading_error_title':
          'We encountered an issue while loading your data. This might be due to:',
      'internet_connection_problem': 'Internet connection problem',
      'server_unavailable': 'Server temporarily unavailable',
      'app_configuration_issue': 'App configuration issue',

      // Bottom Navigation
      'home': 'Home',
      'history': 'History',

      // Error Messages
      'oops_something_went_wrong': 'Oops! Something went wrong',

      // Splash Screen
      'track_nutrition_journey': 'Track your nutrition journey',
      'preparing_app': 'Preparing your app...',

      // Splash Screen
      'powered_by_groq_ai': 'Powered by Groq AI',
      'splash_version': 'v1.0.0',

      // Login Screen
      'welcome_to_nutriscan': 'Welcome to NutriSnap',
      'login_description':
          'Sign in with your Google account to enable cloud backup and sync your data across all devices.',
      'sign_in_with_google': 'Sign in with Google',
      'sign_in_with_apple': 'Sign in with Apple',
      'signing_in': 'Signing in...',
      'skip_for_now': 'Skip for now',
      'login_failed': 'Login failed. Please try again.',
      'google': 'Google',
      'nutriscan': 'NutriSnap',

      // Cloud Backup Screen
      'cloud_backup': 'Cloud Backup',
      'signed_in': 'Signed In',
      'not_signed_in': 'Not Signed In',
      'last_backup_label': 'Last backup',
      'last_backup_items': '{date} · {count} items',
      'no_backup_yet': 'No backup yet',
      'backup_actions': 'Backup Actions',
      'premium_badge': 'PREMIUM',
      'premium': 'Premium',
      'backing_up': 'Backing up...',
      'backup_to_cloud': 'Backup to Cloud',
      'backup_to_cloud_premium': 'Backup to Cloud (Premium)',
      'restoring': 'Restoring...',
      'restore_from_cloud': 'Restore from Cloud',
      'restore_from_cloud_premium': 'Restore from Cloud (Premium)',
      'cloud_backup_premium_only':
          'Cloud backup is only available for premium users',
      'cloud_restore_premium_only':
          'Cloud restore is only available for premium users',
      'auto_backup': 'Auto Backup',
      'auto_backup_description':
          'Automatically backup your data when you add new food items',
      'enable_auto_backup': 'Enable Auto Backup',
      'restore_data': 'Restore Data',
      'restore_data_warning':
          'This will replace all your current data with the data from cloud backup. This action cannot be undone.',
      'restore': 'Restore',
      'cancel_btn': 'Cancel',

      // FoodList Widget
      'no_food_found': 'No food found',
      'start_adding_food': 'Start by adding some food items',

      // NutritionSummaryCard Widget
      'todays_nutrition': 'Today\'s Nutrition',

      // Language Names
      'english': 'English',
      'bangla': 'Bangla',
      'hindi': 'Hindi',
      'spanish': 'Spanish',
      'french': 'French',
      'german': 'German',
      'chinese': 'Chinese',
      'turkish': 'Turkish',
      'korean': 'Korean',
      'indonesian': 'Indonesian',
      'japanese': 'Japanese',
      'russian': 'Russian',
      'urdu': 'Urdu',
      'portuguese': 'Portuguese',
      'arabic': 'Arabic',
      'brazilian_portuguese': 'Brazilian Portuguese',
      'vietnamese': 'Vietnamese',

      // Subscription
      'subscription': 'Subscription',
      'premium_subscription': 'Premium Subscription',
      'unlock_premium': 'Unlock Premium',
      'premium_description': 'Remove ads and unlock all premium features',
      'choose_plan': 'Choose Your Plan',
      'popular': 'Popular',
      'premium_features': 'Premium Features',
      'unlimited_scans': 'Unlimited food scans',
      'no_ads': 'No advertisements',
      'advanced_insights': 'Advanced nutrition insights',
      'export_data': 'Export your data',
      'priority_support': 'Priority support',
      'subscribe_now': 'Subscribe Now',
      'subscription_terms':
          'Subscription subject to terms of service and privacy policy',
      'premium_active': 'Premium Active',
      'manage_subscription': 'Manage subscription',
      'remove_ads_unlock_features': 'Remove ads and unlock all features',
      'subscription_id': 'Subscription ID',
      'expires_on': 'Expires on',
      'days_remaining': 'Days remaining',
      'cancel_subscription': 'Cancel Subscription',
      'subscription_success': 'Subscription successful!',
      'subscription_error': 'Subscription failed, please try again',
      'subscription_cancelled': 'Subscription cancelled',
      'cancellation_error': 'Cancellation failed, please try again',

      // Additional Subscription Screen Translations
      'ad_free_experience': 'Ad-Free Experience',
      'ad_free_description': 'Enjoy the app without any interruptions',
      'unlimited_scans_description': 'Scan as many food items as you want',
      'advanced_analytics': 'Advanced Analytics',
      'advanced_analytics_description': 'Get detailed nutrition insights',
      'priority_support_description': 'Get help when you need it',
      'choose_your_plan': 'Choose Your Plan',
      'monthly_plan': 'Monthly Plan',
      'yearly_plan': 'Yearly Plan',
      'lifetime_plan': 'Lifetime Plan',
      'billed_monthly': 'Billed monthly • Cancel anytime',
      'billed_annually': 'Billed annually • Save 17% • Best value',
      'pay_once_forever': 'Pay once • Use forever • No recurring charges',
      'best_value': 'BEST VALUE',
      'save_percentage': 'Save 17%',
      'subscription_successful': 'Subscription successful! Welcome to Premium!',
      'subscription_terms_detailed':
          'Payment will be charged to your account at confirmation of purchase. Subscription automatically renews unless it is cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscription anytime in your App Store account settings. By subscribing, you agree to our Terms of Service and Privacy Policy.',
      'active_premium_subscription': 'Active Premium Subscription',
      'billed_monthly_desc': 'Billed monthly',
      'billed_annually_desc': 'Billed annually',
      'one_time_payment': 'One-time payment',
      'next_billing': 'Next billing:',
      'never_expires': 'Never expires - Lifetime access',
      'cancel_subscription_warning':
          'Canceling your subscription will remove access to premium features at the end of your current billing period.',
      'cancel_subscription_question': 'Cancel Subscription?',
      'cancel_subscription_description':
          'Are you sure you want to cancel your subscription? You will lose access to premium features at the end of your current billing period.',
      'resubscribe_info':
          'You can resubscribe anytime to regain access to premium features.',
      'keep_subscription': 'Keep Subscription',
      'subscription_cancelled_successfully':
          'Subscription cancelled successfully',

      // Free Trial
      'subscribe_now_button': 'Subscribe Now',
      'maybe_later_button': 'Maybe Later',

      // Notifications
      'notification_settings': 'Notification Settings',
      'notification_settings_subtitle':
          'Meal reminders, daily/weekly progress & alerts',
      'enable_notifications': 'Meal Reminders',
      'notification_description':
          'Get notified for breakfast, lunch, snack & dinner',
      'meal_reminders': 'Meal Reminders',
      'pause_category': 'Notification Control',
      'meal_reminders_category': 'Meal Reminders',
      'progress_category': 'Progress Notifications',
      'inactivity_category': 'Inactivity Notifications',
      'summary_category': 'Summary Notifications',
      'promotion_category': 'Promotion Notifications',
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'snack': 'Snack',
      'dinner': 'Dinner',
      'meal_reminder_message':
          'Time for {meal}! 🍽️ Don\'t forget to register.',
      'breakfast_notification':
          'Time for breakfast! 🍽️ Don\'t forget to register.',
      'lunch_notification': 'Time for lunch! 🍽️ Don\'t forget to register.',
      'snack_notification': 'Time for snack! 🍽️ Don\'t forget to register.',
      'dinner_notification': 'Time for dinner! 🍽️ Don\'t forget to register.',
      'test_notification': 'Test Notification',
      'send_test_notification': 'Send Test Notification',
      'test_notification_sent':
          'Test notification sent successfully! Check your notification bar.',
      'test_notification_failed':
          'Failed to send test notification. Please check permissions.',
      'push_notifications': 'Push Notifications',
      'fcm_token': 'FCM Device Token',
      'fcm_token_description':
          'This token is used to send push notifications to your device.',
      'copied_to_clipboard': 'Copied to clipboard!',
      'fcm_daily_limit': 'FCM Push Notification Limit (max 3/day)',
      'notifications_remaining': 'remaining today',
      'fcm_limit_note': 'Local notifications (meals, progress) are unlimited',
      'pause_notifications': '3 Days Notification Pause',
      'pause_subtitle': 'Pause all notifications for 7 days (Critical only)',
      'pause_7_days': 'Pause for 3 Days',
      'pause_active': 'Notifications Paused',
      'pause_days_remaining': 'Days Remaining',
      'resume_now': 'Resume Notifications',
      'pause_confirm_title': 'Pause Notifications?',
      'pause_confirm_message':
          'All notifications will be paused for 7 days. Critical system notifications will still be delivered.',
      'pause_confirm': 'Pause',
      'pause_info_message':
          'All notifications are currently paused. You will only receive critical system notifications during this period.',
      'remaining': 'remaining',
      'days': 'days',
      'instant_test': 'Instant Test',
      '1_min_test': '1 Min Test',
      'test_scheduled_1min':
          'Test notification scheduled for 1 minute later. Wait and check!',
      'scheduled_notifications': 'Scheduled Notifications',
      'notifications_active': 'notifications active',
      'no_notifications_scheduled':
          'No notifications scheduled. Enable reminders above.',
      'pending_notifications_info': 'Pending Notifications Info',
      'pending_notifications_count': 'Pending Notifications: {count}',
      'refresh': 'Refresh',
      'debug_info': 'Debug Info',
      'no_pending_notifications': 'No pending notifications',

      // Nutrient deficiency (after scan)
      'nutrient_deficiency_title': 'Nutrition Tip',
      'nutrient_deficiency_protein':
          'Your food is low in protein. Try to add more protein in your next meal.',
      'nutrient_deficiency_carbs':
          'Your food is low in carbs. Try to add more carbs in your next meal.',
      'nutrient_deficiency_fat':
          'Your food is low in fat. Try to add more healthy fats in your next meal.',
      'nutrient_deficiency_fiber':
          'Your food is low in fiber. Try to add more fiber in your next meal.',

      'free': 'free',

      // Common
      'delete': 'Delete',
      'clear': 'Clear',
      'close': 'Close',
      'ok': 'OK',
      'cancel': 'Cancel',
      'yes': 'Yes',
      'no': 'No',
      'watch_ad_for_rewards': 'Watch Ad for Rewards',
      'remaining_today': 'Remaining today',
      'available_in': 'Available in',
      'loading_ad': 'Loading ad...',
      'reward_earned': 'Reward Earned!',
      'reward_earned_description':
          'Thank you for watching! Your reward has been added.',
      'ad_not_available': 'Ad Not Available',
      'ad_not_available_description':
          'Please try again later. Ads may take a moment to load.',
      'ad_for_rewards': 'Ad for Rewards',
      'ad_for_rewards_subtitle': 'Watch ads to earn coins',
      'your_coins': 'Your Coins',
      'earn_coins': 'Earn Coins',
      'preferences': 'Preferences',
      'ai_meal_planner': 'AI Meal Planner',
      'meal_planner_description': 'Generate a weekly meal plan based on your eating habits',
      'watch_ad_earn_coins': 'Watch Ad',
      'coins_earned': 'Coins Earned!',
      'you_earned_coins': 'You earned {amount} coins!',
      'coin_balance': 'Coin Balance',
      'total_earned': 'Total Earned',
      'total_spent': 'Total Spent',
      'coins': 'Coins',
      'coin': 'Coin',
      'not_enough_coins': 'Not Enough Coins',
      'not_enough_coins_description':
          'Watch ads to earn more coins and continue scanning.',
      'scan_costs': 'Scan costs {amount} coin',
      'scan_costs_plural': 'Scan costs {amount} coins',
      'please_wait': 'Please wait',
      'health_coach_title': 'Health Coach',
      'chat_placeholder': 'Ask Health Coach...',
      'chat_clear_confirm': 'Clear Chat History',
      'chat_clear_description': 'Are you sure you want to clear the entire chat history? This action cannot be undone.',
      'coach_welcome': 'Hello! I am your AI Health Coach. How can I help you today?',
      'typing': 'Coach is typing...',
      'store_setup_required': 'Store Setup Required',
      'store_setup_unavailable_msg': 'Subscriptions are currently unavailable because the store configuration is incomplete. Please ensure:\n\n• The app is uploaded to Play Store / App Store Console.\n• Product IDs match your Console configuration.\n• You are using a real device with a valid test account.',
      'i_understand': 'I Understand',

      // Slow Kitchen Home Screen
      'sk_the_day_so_far': 'THE DAY SO FAR',
      'sk_kitchen_diary': 'KITCHEN DIARY',
      'sk_history': 'History',
      'sk_ledger': 'LEDGER',
      'sk_seven_days': 'SEVEN DAYS',
      'sk_trends': 'Trends',
      'sk_daily_average': 'daily average',
      'sk_up_delta': 'Up {delta} {unit} against the start of the week',
      'sk_down_delta': 'Down {delta} {unit} against the start of the week',
      'sk_last_week_avg': 'Last week, {avg} average',
      'sk_where_calories_from': 'Where the calories come from',
      'sk_protein_label': 'Protein',
      'sk_carbohydrate_label': 'Carbohydrate',
      'sk_fat_label': 'Fat',
      'sk_health_scores': 'Health scores',
      'sk_health_scores_subtitle': 'Average {score} out of 10 across {count} meals',
      'sk_note_from_coach': 'NOTE FROM THE COACH',
      'sk_coach_empty': 'Log a few meals and this is where the week gets read back to you.',
      'sk_coach_up': 'Your intake climbs through the week and dips at the weekend. Evening bowls are doing most of the work — keep one protein-forward meal before 8pm and the curve flattens.',
      'sk_coach_down': 'Your intake eases off through the week. The weekend is the lightest stretch by a wide margin; if you are training, a larger lunch would carry you better than a late snack.',
      'sk_open_weekly_review': 'Open weekly review',
      'sk_good_morning': 'Good morning',
      'sk_good_afternoon': 'Good afternoon',
      'sk_good_evening': 'Good evening',
      'sk_friend': 'friend',
      'sk_metric_protein': 'Protein',
      'sk_metric_carbs': 'Carbs',
      'sk_metric_fat': 'Fat',
      'sk_metric_calories': 'Calories',
      'sk_source_verified': 'Verified',
      'sk_source_user_edited': 'Edited by you',
      'sk_source_ai_estimate': 'AI estimate',
    },
  };

  static String getString(String key, String languageCode) {
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

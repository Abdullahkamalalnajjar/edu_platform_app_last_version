import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/notification_models.dart';
import 'package:edu_platform_app/data/services/user_notification_service.dart';
import 'package:edu_platform_app/data/services/notification_service.dart';
import 'package:edu_platform_app/data/services/notification_cache_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = UserNotificationService();
  bool _isLoading = true;
  String? _error;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _notificationService.getUserNotifications();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.succeeded && response.data != null) {
        _notifications = response.data!;
        // Sort by date descending (newest first)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    // Optimistic update
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] = NotificationItem(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          timestamp: notification.timestamp,
          isRead: true,
          type: notification.type,
          courseId: notification.courseId,
          examId: notification.examId,
          lectureId: notification.lectureId,
          status: notification.status,
          teacherId: notification.teacherId,
          lectureName: notification.lectureName,
          courseName: notification.courseName,
        );
      }
    });

    // Call API (silent fail handling mostly, or revert if needed)
    await _notificationService.markAsRead(notification.id);
  }

  Future<void> _deleteNotification(NotificationItem notification) async {
    // Optimistic update: remove from list immediately
    setState(() {
      _notifications.removeWhere((n) => n.id == notification.id);
    });

    final response = await _notificationService.deleteNotification(
      notification.id,
    );

    if (!response.succeeded) {
      if (mounted) {
        // Revert on failure (fetch again or add back)
        _fetchNotifications();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _notificationService.markAllAsRead();

    if (response.succeeded) {
      await _fetchNotifications();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    // Check if today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return DateFormat('h:mm a', 'ar').format(date);
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return 'أمس';
    } else {
      return DateFormat('yyyy/MM/dd', 'ar').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'الإشعارات',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              onSelected: (value) async {
                if (value == 'read_all') {
                  _markAllAsRead();
                } else if (value == 'delete_all') {
                  _deleteAllNotifications();
                }
              },
              itemBuilder: (context) => [
                if (_notifications.any((n) => !n.isRead))
                  PopupMenuItem(
                    value: 'read_all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.done_all_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تحديد الكل كمقروء',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حذف جميع الإشعارات',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإشعارات'),
        content: const Text('هل أنت متأكد من حذف جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final response = await _notificationService.deleteAll();

    if (response.succeeded) {
      _fetchNotifications();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
      }
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? AppColors.glassBorder : AppColors.primary.withOpacity(0.12)),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد إشعارات حالياً',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر جميع إشعاراتك وتنبيهاتك هنا',
              style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dismissible(
            key: Key('notification_${notification.id}'),
            background: Container(
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.startToEnd,
            onDismissed: (direction) {
              _deleteNotification(notification);
            },
            child: InkWell(
              onTap: () async {
                _markAsRead(notification);
                // First try navigation data from API
                if (notification.hasNavigationData) {
                  NotificationService.handleNotificationData(
                    notification.toNavigationData(),
                  );
                  return;
                }
                // Fallback: try cached FCM data
                final cachedData = await NotificationCacheService.findCachedData(
                  notification.title,
                  notification.body,
                );
                if (cachedData != null) {
                  print('📦 Found cached data for notification: $cachedData');
                  NotificationService.handleNotificationData(cachedData);
                } else {
                  print('⚠️ No navigation data found for: ${notification.title}');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? (isDark ? AppColors.surface.withOpacity(0.5) : Colors.white.withOpacity(0.6))
                      : (isDark ? AppColors.surface : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: notification.isRead
                        ? Colors.transparent
                        : AppColors.primary.withOpacity(0.3),
                    width: notification.isRead ? 0 : 1.5,
                  ),
                  boxShadow: notification.isRead
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        notification.isRead
                            ? Icons.notifications_outlined
                            : Icons.notifications_active_rounded,
                        color: notification.isRead
                            ? Theme.of(context).textTheme.bodyMedium?.color
                            : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: GoogleFonts.outfit(
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(notification.timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notification.body,
                            style: GoogleFonts.inter(
                              color: notification.isRead
                                  ? Theme.of(context).textTheme.bodyMedium?.color
                                  : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

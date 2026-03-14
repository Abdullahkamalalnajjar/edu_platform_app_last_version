import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/subscription_models.dart';
import 'package:edu_platform_app/data/services/subscription_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';

class TeacherSubscriptionsScreen extends StatefulWidget {
  final int? initialCourseId;
  final int? teacherId;

  const TeacherSubscriptionsScreen({
    super.key,
    this.initialCourseId,
    this.teacherId,
  });

  @override
  State<TeacherSubscriptionsScreen> createState() =>
      _TeacherSubscriptionsScreenState();
}

class _TeacherSubscriptionsScreenState
    extends State<TeacherSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _subscriptionService = SubscriptionService();
  final _tokenService = TokenService();

  List<CourseSubscription> _allSubscriptions = [];
  List<CourseSubscription> _filteredSubscriptions = [];
  bool _isLoading = false;

  // Track loading state per subscription item (optimistic UI)
  final Set<int> _loadingIds = {};

  String _selectedFilter = 'Pending';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchSubscriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'Pending';
            break;
          case 1:
            _selectedFilter = 'Approved';
            break;
          case 2:
            _selectedFilter = 'Rejected';
            break;
        }
        _applyFilter();
      });
    }
  }

  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoading = true);

    int? teacherId = widget.teacherId;
    if (teacherId == null) {
      teacherId = await _tokenService.getTeacherId();
    }

    if (teacherId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لم يتم العثور على معرف المعلم'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final response = await _subscriptionService.getTeacherSubscriptions(
      teacherId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _allSubscriptions = response.data!;
          _applyFilter();
        }
      });
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'All') {
      _filteredSubscriptions = List.from(_allSubscriptions);
    } else {
      _filteredSubscriptions = _allSubscriptions
          .where((sub) => sub.status == _selectedFilter)
          .toList();
    }
  }

  /// Optimistic update: updates locally first, then syncs with server.
  /// No full-page reload on success.
  Future<void> _updateSubscriptionStatus(
    CourseSubscription subscription,
    String newStatus,
  ) async {
    if (subscription.courseSubscriptionId == 0) return;
    if (_loadingIds.contains(subscription.courseSubscriptionId)) return;

    setState(() => _loadingIds.add(subscription.courseSubscriptionId));

    final response = await _subscriptionService.updateSubscriptionStatus(
      subscriptionId: subscription.courseSubscriptionId,
      status: newStatus,
    );

    if (!mounted) return;

    if (response.succeeded) {
      // Remove from loading set and update locally — no full reload
      setState(() {
        _loadingIds.remove(subscription.courseSubscriptionId);
        final idx = _allSubscriptions.indexWhere(
          (s) => s.courseSubscriptionId == subscription.courseSubscriptionId,
        );
        if (idx != -1) {
          // Replace with updated status copy
          final updated = CourseSubscription(
            courseSubscriptionId: subscription.courseSubscriptionId,
            studentId: subscription.studentId,
            studentName: subscription.studentName,
            courseId: subscription.courseId,
            courseName: subscription.courseName,
            teacherName: subscription.teacherName,
            educationStageId: subscription.educationStageId,
            educationStageName: subscription.educationStageName,
            status: newStatus,
            createdAt: subscription.createdAt,
            lectures: subscription.lectures,
          );
          _allSubscriptions[idx] = updated;
        }
        _applyFilter();
      });

      final label = newStatus == 'Approved'
          ? 'تم قبول الاشتراك ✓'
          : newStatus == 'Rejected'
          ? 'تم رفض الاشتراك'
          : 'تم إعادة الطلب للانتظار';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: newStatus == 'Approved'
              ? AppColors.success
              : newStatus == 'Rejected'
              ? AppColors.error
              : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _loadingIds.remove(subscription.courseSubscriptionId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ─────────────────────────── counts ────────────────────────────
  int get _pendingCount =>
      _allSubscriptions.where((s) => s.status == 'Pending').length;
  int get _approvedCount =>
      _allSubscriptions.where((s) => s.status == 'Approved').length;
  int get _rejectedCount =>
      _allSubscriptions.where((s) => s.status == 'Rejected').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'طلبات الاشتراك',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchSubscriptions,
            tooltip: 'تحديث',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? AppColors.surface : Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor:
                  Theme.of(context).textTheme.bodyMedium?.color,
              labelStyle:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              tabs: [
                Tab(text: 'انتظار ($_pendingCount)'),
                Tab(text: 'مقبولة ($_approvedCount)'),
                Tab(text: 'مرفوضة ($_rejectedCount)'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _filteredSubscriptions.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchSubscriptions,
              color: AppColors.primary,
              child: _buildGroupedList(),
            ),
    );
  }

  // Approve all pending subscriptions for a course at once
  Future<void> _approveAllForCourse(
      List<CourseSubscription> subscriptions) async {
    final pending =
        subscriptions.where((s) => s.status == 'Pending').toList();
    if (pending.isEmpty) return;

    // Mark all as loading
    setState(() {
      for (final s in pending) {
        _loadingIds.add(s.courseSubscriptionId);
      }
    });

    int successCount = 0;
    for (final sub in pending) {
      final response = await _subscriptionService.updateSubscriptionStatus(
        subscriptionId: sub.courseSubscriptionId,
        status: 'Approved',
      );
      if (response.succeeded) {
        successCount++;
        final idx = _allSubscriptions.indexWhere(
          (s) => s.courseSubscriptionId == sub.courseSubscriptionId,
        );
        if (idx != -1) {
          _allSubscriptions[idx] = CourseSubscription(
            courseSubscriptionId: sub.courseSubscriptionId,
            studentId: sub.studentId,
            studentName: sub.studentName,
            courseId: sub.courseId,
            courseName: sub.courseName,
            teacherName: sub.teacherName,
            educationStageId: sub.educationStageId,
            educationStageName: sub.educationStageName,
            status: 'Approved',
            createdAt: sub.createdAt,
            lectures: sub.lectures,
          );
        }
      }
      setState(() => _loadingIds.remove(sub.courseSubscriptionId));
    }

    if (mounted) {
      setState(() => _applyFilter());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم قبول $successCount من ${pending.length} طالب ✓',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildGroupedList() {
    final groupedMap = <int, List<CourseSubscription>>{};
    for (var sub in _filteredSubscriptions) {
      groupedMap.putIfAbsent(sub.courseId, () => []).add(sub);
    }
    final groupedList = groupedMap.values.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final courseSubs = groupedList[index];
        return FadeInUp(
          duration: const Duration(milliseconds: 350),
          delay: Duration(milliseconds: 60 * index),
          child: _buildCourseGroupCard(courseSubs),
        );
      },
    );
  }

  Widget _buildCourseGroupCard(List<CourseSubscription> subscriptions) {
    if (subscriptions.isEmpty) return const SizedBox.shrink();
    final course = subscriptions.first;
    final pendingCount =
        subscriptions.where((s) => s.status == 'Pending').length;
    final isApprovingAll = subscriptions
        .where((s) => s.status == 'Pending')
        .every((s) => _loadingIds.contains(s.courseSubscriptionId));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('course_${course.courseId}'),
          initiallyExpanded: widget.initialCourseId != null
              ? widget.initialCourseId == course.courseId
              : false,
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 22),
          ),
          title: Text(
            course.courseName,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined,
                    size: 13,
                    color: AppColors.primary.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text(
                  '${subscriptions.length} طالب',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // "Accept All" button shown only when there are pending subs
          trailing: pendingCount > 0
              ? Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: isApprovingAll
                        ? null
                        : () => _approveAllForCourse(subscriptions),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isApprovingAll
                            ? AppColors.success.withOpacity(0.08)
                            : AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.5)),
                      ),
                      child: isApprovingAll
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.success,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.done_all_rounded,
                                    size: 14, color: AppColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  'قبول الكل ($pendingCount)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                )
              : null,
          children: subscriptions
              .map((sub) => _buildStudentItem(sub))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStudentItem(CourseSubscription subscription) {
    final isLoading =
        _loadingIds.contains(subscription.courseSubscriptionId);
    final isPending = subscription.status == 'Pending';
    final isApproved = subscription.status == 'Approved';
    final isRejected = subscription.status == 'Rejected';

    final statusColor = isPending
        ? Colors.orange
        : isApproved
        ? AppColors.success
        : AppColors.error;
    final statusLabel =
        isPending ? 'انتظار' : isApproved ? 'مقبول' : 'مرفوض';
    final statusIcon = isPending
        ? Icons.hourglass_top_rounded
        : isApproved
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.7),
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      subscription.studentName.isNotEmpty
                          ? subscription.studentName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.studentName,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 11,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(subscription.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Action buttons
            if (isLoading)
              const Center(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!isApproved)
                    _actionButton(
                      label: 'قبول',
                      icon: Icons.check_rounded,
                      color: AppColors.success,
                      filled: true,
                      onTap: () => _updateSubscriptionStatus(
                          subscription, 'Approved'),
                    ),
                  if (!isRejected)
                    _actionButton(
                      label: 'رفض',
                      icon: Icons.close_rounded,
                      color: AppColors.error,
                      filled: false,
                      onTap: () => _updateSubscriptionStatus(
                          subscription, 'Rejected'),
                    ),
                  if (!isPending)
                    _actionButton(
                      label: 'إعادة للانتظار',
                      icon: Icons.replay_rounded,
                      color: Colors.orange,
                      filled: false,
                      onTap: () => _updateSubscriptionStatus(
                          subscription, 'Pending'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? color : color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    Color color;

    switch (_selectedFilter) {
      case 'Pending':
        message = 'لا توجد طلبات قيد الانتظار';
        icon = Icons.hourglass_empty_rounded;
        color = Colors.orange;
        break;
      case 'Approved':
        message = 'لا توجد طلبات مقبولة';
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.success;
        break;
      case 'Rejected':
        message = 'لا توجد طلبات مرفوضة';
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        break;
      default:
        message = 'لا توجد طلبات اشتراك';
        icon = Icons.inbox_rounded;
        color = AppColors.textSecondary;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color.withOpacity(0.7)),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'اسحب للأسفل لتحديث القائمة',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

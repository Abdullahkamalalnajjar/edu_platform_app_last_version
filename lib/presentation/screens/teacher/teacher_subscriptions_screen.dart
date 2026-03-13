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

class _TeacherSubscriptionsScreenState extends State<TeacherSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _subscriptionService = SubscriptionService();
  final _tokenService = TokenService();

  List<CourseSubscription> _allSubscriptions = [];
  List<CourseSubscription> _filteredSubscriptions = [];
  bool _isLoading = false;
  String _selectedFilter = 'Pending'; // Pending, Approved, Rejected, All
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

    // If teacherId is passed (Admin view), use it. Otherwise get from token (Teacher view)
    int? teacherId = widget.teacherId;
    if (teacherId == null) {
      teacherId = await _tokenService.getTeacherId();
    }

    if (teacherId == null) {
      if (mounted && context.mounted) {
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

  Future<void> _updateSubscriptionStatus(
    CourseSubscription subscription,
    String newStatus,
  ) async {
    // Validate subscription ID
    if (subscription.courseSubscriptionId == 0) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: معرف الاشتراك غير صالح'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final response = await _subscriptionService.updateSubscriptionStatus(
      subscriptionId: subscription.courseSubscriptionId,
      status: newStatus,
    );

    if (mounted && context.mounted) {
      if (response.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'Approved'
                  ? 'تم قبول الاشتراك بنجاح'
                  : newStatus == 'Rejected'
                  ? 'تم رفض الاشتراك'
                  : 'تم تعيين الطلب قيد الانتظار',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchSubscriptions(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          'طلبات الاشتراك',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'مقبولة'),
            Tab(text: 'مرفوضة'),
          ],
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

  Widget _buildGroupedList() {
    // Group subscriptions by course ID to handle duplicates
    final groupedMap = <int, List<CourseSubscription>>{};
    for (var sub in _filteredSubscriptions) {
      if (!groupedMap.containsKey(sub.courseId)) {
        groupedMap[sub.courseId] = [];
      }
      groupedMap[sub.courseId]!.add(sub);
    }

    final groupedList = groupedMap.values.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final courseSubs = groupedList[index];
        return FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: 100 * index),
          child: _buildCourseGroupCard(courseSubs),
        );
      },
    );
  }

  Widget _buildCourseGroupCard(List<CourseSubscription> subscriptions) {
    if (subscriptions.isEmpty) return const SizedBox.shrink();
    final course = subscriptions.first;

    // Determine status color based on the filter/first item
    final isPending = course.status == 'Pending';
    final isApproved = course.status == 'Approved';
    final statusColor = isPending
        ? Colors.orange
        : isApproved
        ? AppColors.success
        : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initialCourseId != null
              ? widget.initialCourseId == course.courseId
              : true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            course.courseName,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            '${subscriptions.length} طالب',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: subscriptions.map((sub) => _buildStudentItem(sub)).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentItem(CourseSubscription subscription) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 20,
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
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      _formatDate(subscription.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              if (subscription.status != 'Approved')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _updateSubscriptionStatus(subscription, 'Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('قبول'),
                  ),
                ),
              if (subscription.status == 'Pending') const SizedBox(width: 8),

              if (subscription.status != 'Rejected')
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _updateSubscriptionStatus(subscription, 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('رفض'),
                  ),
                ),
            ],
          ),
          // Set to Pending Action
          if (subscription.status != 'Pending') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    _updateSubscriptionStatus(subscription, 'Pending'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('إعادة للانتظار'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_selectedFilter) {
      case 'Pending':
        message = 'لا توجد طلبات قيد الانتظار';
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'Approved':
        message = 'لا توجد طلبات مقبولة';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Rejected':
        message = 'لا توجد طلبات مرفوضة';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'لا توجد طلبات اشتراك';
        icon = Icons.inbox_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
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

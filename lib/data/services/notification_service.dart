import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../presentation/screens/student/student_exam_screen.dart';
import '../../presentation/screens/teacher/teacher_subscriptions_screen.dart';
import '../../presentation/screens/teacher/exam_submissions_screen.dart';
import '../../presentation/screens/student/my_courses_page.dart';
import '../../presentation/screens/shared/course_details/course_details_screen.dart';

import '../../core/network/api_client.dart';
import 'course_service.dart';
import '../models/course_models.dart';

import 'token_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Background message received: ${message.messageId}');
  print('📩 Data: ${message.data}');

  // Check if notification is for this role even in background
  final tokenService = TokenService();
  final role = await tokenService.getRole();
  if (role != null && !_isNotificationForRole(message.data, role)) {
    print('🚫 Ignoring background notification for different role');
    return;
  }

  // Only show local notification for data-only messages in background
  // If message.notification is NOT null, the System (OS) already displayed it.
  if (message.notification == null) {
    await NotificationService._showLocalNotification(message);
  }
}

/// Helper to check if notification is relevant for current role
bool _isNotificationForRole(Map<String, dynamic> data, String role) {
  final type = data['type'] ?? '';

  // Teacher-only notifications
  if (type == 'new_subscription' || type == 'exam_submitted') {
    return role == 'Teacher' || role == 'Admin' || role == 'Assistant';
  }

  // Hide exam_created from everyone except students (specifically Teachers/Admins shouldn't see it)
  if (type == 'exam_created') {
    return role == 'Student';
  }

  // Student-only notifications
  final studentTypes = [
    'exam_graded',
    'new_exam',
    'subscription_status_changed',
    'deadline_exception_granted',
    'lecture_added',
    'material_added',
    'subscription_added_by_teacher',
    'exam_visibility_changed',
    'lecture_visibility_changed',
  ];

  if (studentTypes.contains(type)) {
    return role == 'Student' || role == 'Admin';
  }

  return true; // Default to showing other types
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final CourseService _courseService = CourseService();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel_v2', // Updated ID to force refresh settings
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Initialize notification handling
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Create Android notification channel
    await _createNotificationChannel();

    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Set foreground notification presentation options
    // Let the system show the notification from backend (alert: true)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages - only for logging and data processing
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from a notification (background state)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Subscribe to role-based topics
    final tokenService = TokenService();
    final role = await tokenService.getRole();
    if (role != null) {
      // Treat Assistant same as Teacher for notifications, or subscribe to assistant specific topic if exists.
      // Assuming Assistant needs to see Teacher notifications or specific ones.
      // If the backend sends to 'teachers' topic, Assistant should probably subscribe to it too OR backend sends individual notification.
      // Based on code below, we just check role for filtering.
      await subscribeToTopicBasedOnRole(role);
    }

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Delay navigation to allow app to fully initialize
      Future.delayed(const Duration(milliseconds: 1500), () {
        _handleNotificationTap(initialMessage);
      });
    }

    _isInitialized = true;
    print('🔔 NotificationService initialized');
  }

  /// Initialize local notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Create notification channel for Android 8+
  static Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      final platform =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (platform != null) {
        await platform.createNotificationChannel(_channel);
        await platform.requestNotificationsPermission();
      }
    }
  }

  /// Handle notification tap from local notifications
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationData(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  /// Show local notification (for background/terminated state)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // Ensure initialized (crucial for background isolate)
    if (!_isInitialized) {
      await _initializeLocalNotifications();
      _isInitialized = true;
    }

    final notification = message.notification;
    final data = message.data;

    // Use notification title/body or extract from data
    String title = notification?.title ?? data['title'] ?? 'إشعار جديد';
    String body = notification?.body ?? data['body'] ?? '';

    // Fix encoding issue for 'subscription_added_by_teacher'
    if (data['type'] == 'subscription_added_by_teacher') {
      title = 'Bosla';
      try {
        String? courseName = data['courseName'];
        // If courseName is missing or looks corrupted (contains '???'), try fallback or fetch
        if (courseName == null || courseName.contains('??')) {
          final courseIdStr = data['courseId']?.toString();
          final courseId = int.tryParse(courseIdStr ?? '');
          if (courseId != null) {
            // Attempt to fetch course details to get the real title
            // Note: This adds a delay before showing notification, but ensures correctness.
            // Ideally backend should send clean data.
            try {
              // Creating a temporary service instance since we can't easily rely on global state in background handler
              // assuming TokenService works with SharedPreferences in background (which it does on Android/iOS usually)
              final courseService = CourseService();
              final response = await courseService.getCourseById(courseId);
              if (response.succeeded && response.data != null) {
                courseName = response.data!.title;
              }
            } catch (e) {
              print('Failed to fetch course name significantly: $e');
            }
          }
        }

        if (courseName != null && !courseName.contains('??')) {
          body = 'تم إضافتك إلى $courseName';
        } else {
          // Fallback generic message if everything fails
          body = 'تم إضافتك إلى كورس جديد بنجاح';
        }
      } catch (e) {
        print('Error handling specific notification body: $e');
        body = 'تم إضافتك إلى كورس جديد';
      }
    }

    // Handle new_subscription notification text
    if (data['type'] == 'new_subscription') {
      title = 'طلب اشتراك جديد';
      final studentName = data['studentName'] ?? 'طالب';
      final courseName = data['courseName'] ?? 'كورس';
      body = '$studentName يريد الاشتراك في $courseName';
    }

    // Handle exam_submitted notification text
    if (data['type'] == 'exam_submitted') {
      title = 'تم تسليم اختبار جديد';
      final studentName = data['studentName'] ?? 'طالب';
      final examTitle = data['examTitle'] ?? data['lectureName'] ?? 'اختبار';
      body = 'قام $studentName بتسليم $examTitle';
    }

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v2', // Updated ID
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use messageId hashCode for deduplication if available, otherwise use timestamp
    final notificationId = message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  /// Handle foreground messages (app is open)
  /// Backend sends complete notification with title/body, system will display it.
  /// This handler is only for logging and any silent processing needed.
  static void _handleForegroundMessage(RemoteMessage message) async {
    print('📩 Foreground message: ${message.notification?.title}');
    print('📩 Data: ${message.data}');

    // Filter by role - ignore notifications not meant for this user type
    final tokenService = TokenService();
    final role = await tokenService.getRole();
    if (role != null && !_isNotificationForRole(message.data, role)) {
      print('🚫 Ignoring foreground notification for different role');
      return;
    }

    // Show local notification explicitly for foreground messages
    // This ensures heads-up notification appears even when app is open on Android
    if (Platform.isAndroid) {
      await _showLocalNotification(message);
    }

    print('✅ Foreground notification processed');
  }

  /// Handle notification tap from FCM
  static void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped!');
    print('🔔 Data: ${message.data}');
    _handleNotificationData(message.data);
  }

  /// Handle notification data and navigate
  static void _handleNotificationData(Map<String, dynamic> data) {
    print('🎯 _handleNotificationData called with data: $data');
    final type = data['type'] ?? '';
    print('🎯 Notification type: $type');

    // Handle different notification types
    switch (type) {
      case 'exam_graded':
        print('➡️ Handling exam_graded notification');
        _handleExamGradedNotification(data);
        break;
      case 'exam':
      case 'new_exam':
      case 'exam_created':
      case 'exam_visibility_changed':
        print(
          '➡️ Handling exam/new_exam/exam_created/exam_visibility_changed notification',
        );
        _handleExamNotification(data);
        break;
      case 'new_subscription':
        print('➡️ Handling new_subscription notification');
        _handleNewSubscriptionNotification(data);
        break;
      case 'subscription_status_changed':
        print('➡️ Handling subscription_status_changed notification');
        _handleSubscriptionStatusChangeNotification(data);
        break;
      case 'deadline_exception_granted':
        print('➡️ Handling deadline_exception_granted notification');
        _handleDeadlineExceptionNotification(data);
        break;
      case 'course':
        print('➡️ Handling course notification');
        _navigateToScreen(const MyCoursesPage());
        break;
      case 'lecture_added':
      case 'lecture_visibility_changed':
        print(
          '➡️ Handling lecture_added/lecture_visibility_changed notification',
        );
        _handleCourseContentNotification(data, isLecture: true);
        break;
      case 'material_added':
        print('➡️ Handling material_added notification');
        _handleCourseContentNotification(data, isLecture: false);
        break;
      case 'subscription_added_by_teacher':
        print('➡️ Handling subscription_added_by_teacher notification');
        _handleSubscriptionAddedByTeacherNotification(data);
        break;
      case 'exam_submitted':
        print('➡️ Handling exam_submitted notification');
        _handleExamSubmittedNotification(data);
        break;
      default:
        print('⚠️ Unknown notification type: $type');
        // Try to handle based on available data
        if (data.containsKey('lectureId')) {
          _handleExamNotification(data);
        } else if (data.containsKey('examId')) {
          _handleExamGradedNotification(data);
        }
        break;
    }
  }

  /// Handle new subscription notification (for teacher/assistant)
  /// Backend already sent notification with title/body - just navigate
  static Future<void> _handleNewSubscriptionNotification(
    Map<String, dynamic> data,
  ) async {
    print('Processing new subscription notification: $data');
    final courseId = int.tryParse(data['courseId']?.toString() ?? '');
    final teacherId = int.tryParse(data['teacherId']?.toString() ?? '');

    // Small delay then navigate to subscriptions screen
    await Future.delayed(const Duration(milliseconds: 300));
    _navigateToScreen(TeacherSubscriptionsScreen(
      initialCourseId: courseId,
      teacherId: teacherId,
    ));
  }

  /// Handle subscription status change (for student)
  /// Backend already sent notification - just navigate to appropriate tab
  static Future<void> _handleSubscriptionStatusChangeNotification(
    Map<String, dynamic> data,
  ) async {
    final status = data['status'];
    final courseIdStr = data['courseId']?.toString();
    final courseId = int.tryParse(courseIdStr ?? '');

    // If approved, try to go directly to course content
    if (status == 'Approved' && courseId != null) {
      print(
        '✅ Subscription approved. Fetching course details for $courseId...',
      );

      // Directly fetch the course details instead of getCoursesByTeacher
      // This is safer and more efficient
      final response = await _courseService.getCourseById(courseId);

      if (response.succeeded && response.data != null) {
        _navigateToScreen(CourseDetailsScreen(course: response.data!));
        return;
      } else {
        print(
          '❌ Failed to fetch course $courseId details: ${response.message}',
        );
      }
    }

    // Fallback or handle other statuses (Pending/Rejected)
    // Tabs: 0: Approved, 1: Pending, 2: Rejected
    int tabIndex = 0;
    if (status == 'Rejected') {
      tabIndex = 2;
    } else if (status == 'Pending') {
      tabIndex = 1;
    } else {
      tabIndex = 0; // Default/Approved (fallback if fetch fails)
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _navigateToScreen(MyCoursesPage(initialTabIndex: tabIndex));
  }

  /// Handle subscription added by teacher notification
  /// Backend already sent notification - just navigate to course
  static Future<void> _handleSubscriptionAddedByTeacherNotification(
    Map<String, dynamic> data,
  ) async {
    final courseIdStr = data['courseId']?.toString();
    final courseId = int.tryParse(courseIdStr ?? '');
    final status = data['status'];
    final courseName = data['courseName'];
    print('Teacher assigned course: $courseName ($courseId), Status: $status');

    if (courseId != null) {
      // Try to fetch specific course details to open it directly
      final response = await _courseService.getCourseById(courseId);
      if (response.succeeded && response.data != null) {
        _navigateToScreen(CourseDetailsScreen(course: response.data!));
        return;
      }
    }

    // Fallback to MyCoursesPage (Approved tab) if course fetch fails or ID missing
    await Future.delayed(const Duration(milliseconds: 300));
    _navigateToScreen(const MyCoursesPage(initialTabIndex: 0));
  }

  /// Handle course content (lecture/material) added
  /// Backend already sent notification - just navigate to course
  static Future<void> _handleCourseContentNotification(
    Map<String, dynamic> data, {
    required bool isLecture,
  }) async {
    print('Processing course content notification...');

    final courseIdStr = data['courseId']?.toString();
    var courseId = int.tryParse(courseIdStr ?? '');
    final lectureId = int.tryParse(data['lectureId']?.toString() ?? '');

    if (courseId == null) {
      if (lectureId != null) {
        print('⚠️ CourseId missing, trying to find by lectureId: $lectureId');
        final validLectureResponse = await _courseService.getLectureById(
          lectureId,
        );
        if (validLectureResponse.succeeded &&
            validLectureResponse.data != null) {
          courseId = validLectureResponse.data!.courseId;
          print('✅ Found courseId: $courseId from lecture');
        } else {
          print('❌ Could not find courseId from lecture ID $lectureId');
          return;
        }
      } else {
        print('❌ Invalid courseId and no lectureId in notification');
        return;
      }
    }

    // Fetch full course details and navigate
    print('Fetching course details for ID: $courseId');
    final response = await _courseService.getCourseById(courseId!);

    if (response.succeeded && response.data != null) {
      print('Course fetched successfully. Navigating to details.');

      _navigateToScreen(
        CourseDetailsScreen(
          course: response.data!,
          initialLectureId: lectureId,
        ),
      );
    } else {
      print('Failed to fetch course details: ${response.message}');
      // Fallback to MyCoursesPage
      _navigateToScreen(const MyCoursesPage(initialTabIndex: 0));
    }
  }

  /// Handle deadline exception notification (for student)
  /// Backend already sent notification - just navigate to exam
  static Future<void> _handleDeadlineExceptionNotification(
    Map<String, dynamic> data,
  ) async {
    print('🎓 _handleDeadlineExceptionNotification called');
    print('🎓 Data: $data');

    final examId = int.tryParse(data['examId']?.toString() ?? '');

    if (examId == null) {
      print('❌ Invalid examId in deadline exception notification');
      return;
    }

    // Small delay then navigate to the exam
    await Future.delayed(const Duration(milliseconds: 300));
    _handleExamGradedNotification(data);
  }

  /// Handle exam submitted notification (for teacher)
  /// Backend already sent notification - navigate to exam submissions screen
  static Future<void> _handleExamSubmittedNotification(
    Map<String, dynamic> data,
  ) async {
    print('📝 _handleExamSubmittedNotification called');
    print('📝 Data: $data');

    final lectureId = int.tryParse(data['lectureId']?.toString() ?? '');
    final examId = int.tryParse(data['examId']?.toString() ?? '');
    final lectureName = data['lectureName'] ?? data['examTitle'] ?? 'الاختبار';

    if (lectureId == null) {
      print('❌ Invalid lectureId in exam_submitted notification');
      return;
    }

    // Navigate to exam submissions screen
    await Future.delayed(const Duration(milliseconds: 300));
    _navigateToScreen(
      ExamSubmissionsScreen(
        lectureId: lectureId,
        lectureTitle: lectureName,
        examId: examId,
      ),
    );
  }

  /// Generic navigation helper
  static void _navigateToScreen(Widget screen) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      navigator.push(MaterialPageRoute(builder: (context) => screen));
    } else {
      print('❌ Navigator not available');
    }
  }

  /// Handle exam graded notification - fetch exam and navigate
  /// Backend already sent notification - just navigate to exam
  static Future<void> _handleExamGradedNotification(
    Map<String, dynamic> data,
  ) async {
    final examId = int.tryParse(data['examId']?.toString() ?? '');
    // Use examTitle as fallback if API doesn't return lecture name
    final fallbackTitle = data['examTitle'] ?? data['title'] ?? 'الاختبار';

    if (examId == null) {
      print('❌ Invalid examId in notification');
      return;
    }

    print('📋 Fetching exam details for examId: $examId');

    // Fetch exam details to get lectureId
    final response = await _courseService.getExamById(examId);

    if (response.succeeded && response.data != null) {
      final exam = response.data!;
      final title = exam.lectureName ??
          (exam.title.isNotEmpty ? exam.title : fallbackTitle);
      _navigateToExam(exam.lectureId, title, examId: exam.id);
    } else {
      print('❌ Could not fetch exam details: ${response.message}');
      // Fallback to MyCoursesPage
      _navigateToScreen(const MyCoursesPage(initialTabIndex: 0));
    }
  }

  /// Handle exam notification with lectureId
  static void _handleExamNotification(Map<String, dynamic> data) {
    final lectureId = int.tryParse(data['lectureId']?.toString() ?? '');
    final examId = int.tryParse(data['examId']?.toString() ?? '');
    final lectureTitle = data['lectureName'] ??
        data['lectureTitle'] ??
        data['title'] ??
        'الاختبار';

    if (lectureId != null) {
      _navigateToExam(lectureId, lectureTitle, examId: examId);
    } else {
      print('❌ Invalid lectureId in notification');
    }
  }

  /// Navigate to exam screen
  static void _navigateToExam(
    int lectureId,
    String lectureTitle, {
    int? examId,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => StudentExamScreen(
            lectureId: lectureId,
            examId: examId,
            lectureTitle: lectureTitle,
          ),
        ),
      );
      print('✅ Navigating to exam: lectureId=$lectureId, title=$lectureTitle');
    } else {
      print('❌ Navigator not available');
    }
  }

  /// Subscribe to a topic (e.g., course updates)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('📌 Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('📌 Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  /// Subscribe to topics based on role
  static Future<void> subscribeToTopicBasedOnRole(String role) async {
    print('🔔 Subscribing to topics for role: $role');
    try {
      // Always subscribe to general announcements
      await subscribeToTopic('all_users');

      if (role == 'Teacher' || role == 'Assistant') {
        // Assistants should also receive notifications meant for teachers (e.g. exam submissions)
        await subscribeToTopic('teachers');
      } else if (role == 'Student') {
        await subscribeToTopic('students');
      } else if (role == 'Parent') {
        await subscribeToTopic('parents');
      } else if (role == 'Admin') {
        await subscribeToTopic('admins');
      }
    } catch (e) {
      print('❌ Error subscribing to topics: $e');
    }
  }

  /// Unsubscribe from all possible topics (call on logout)
  static Future<void> unsubscribeFromAllTopics() async {
    print('🔕 Unsubscribing from all topics');
    final topics = ['all_users', 'teachers', 'students', 'parents', 'admins'];
    for (final topic in topics) {
      await unsubscribeFromTopic(topic);
    }
  }
}

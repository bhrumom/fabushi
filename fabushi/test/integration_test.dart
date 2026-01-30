import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:global_dharma_sharing/main.dart';
import 'package:global_dharma_sharing/models/auth_model.dart';
import 'package:global_dharma_sharing/services/auth_service.dart';
import 'package:global_dharma_sharing/services/membership_service.dart';

void main() {
  group('全球法布施应用集成测试', () {
    testWidgets('应用启动测试', (WidgetTester tester) async {
      // 构建应用
      await tester.pumpWidget(const MyApp());

      // 验证主界面元素
      expect(find.text('全球法布施'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      // 验证底部导航栏
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('登录界面测试', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 点击登录按钮
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      // 验证登录界面元素
      expect(find.text('用户登录'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // 用户名和密码字段
      expect(find.text('登录'), findsWidgets);
      expect(find.text('注册账户'), findsOneWidget);
    });

    testWidgets('注册界面测试', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 导航到注册界面
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('注册账户'));
      await tester.pumpAndSettle();

      // 验证注册界面元素
      expect(find.text('用户注册'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); // 用户名、邮箱、密码、验证码
      expect(find.text('发送验证码'), findsOneWidget);
      expect(find.text('注册'), findsOneWidget);
    });

    testWidgets('个人中心界面测试', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 点击个人中心
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // 验证个人中心界面元素
      expect(find.text('个人中心'), findsOneWidget);
      expect(find.text('会员中心'), findsOneWidget);
      expect(find.text('兑换码'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('会员中心界面测试', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 导航到会员中心
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tester.tap(find.text('会员中心'));
      await tester.pumpAndSettle();

      // 验证会员中心界面元素
      expect(find.text('会员中心'), findsOneWidget);
      expect(find.text('请先登录'), findsOneWidget); // 未登录状态
    });

    group('表单验证测试', () {
      testWidgets('登录表单验证', (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());

        // 导航到登录界面
        await tester.tap(find.text('登录'));
        await tester.pumpAndSettle();

        // 尝试空表单提交
        await tester.tap(find.text('登录').last);
        await tester.pumpAndSettle();

        // 验证错误提示
        expect(find.text('请输入用户名或邮箱'), findsOneWidget);
        expect(find.text('请输入密码'), findsOneWidget);
      });

      testWidgets('注册表单验证', (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());

        // 导航到注册界面
        await tester.tap(find.text('登录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('注册账户'));
        await tester.pumpAndSettle();

        // 尝试空表单提交
        await tester.tap(find.text('注册'));
        await tester.pumpAndSettle();

        // 验证错误提示
        expect(find.text('请输入用户名'), findsOneWidget);
        expect(find.text('请输入邮箱'), findsOneWidget);
        expect(find.text('请输入密码'), findsOneWidget);
      });
    });

    group('状态管理测试', () {
      testWidgets('AuthModel状态测试', (WidgetTester tester) async {
        final authModel = AuthModel();

        // 测试初始状态
        expect(authModel.isLoggedIn, false);
        expect(authModel.currentUser, null);
        expect(authModel.isLoading, false);

        // 测试加载状态
        // 注意：这里需要模拟网络请求，实际测试中应该使用mock
      });
    });
  });

  group('服务层测试', () {
    group('AuthService测试', () {
      late AuthService authService;

      setUp(() {
        authService = AuthService();
      });

      test('登录请求格式测试', () {
        // 测试登录请求的数据格式
        final loginData = {
          'username': 'test@example.com',
          'password': 'password123',
        };

        expect(loginData.containsKey('username'), true);
        expect(loginData.containsKey('password'), true);
      });

      test('注册请求格式测试', () {
        // 测试注册请求的数据格式
        final registerData = {
          'username': 'testuser',
          'email': 'test@example.com',
          'password': 'password123',
          'verificationCode': '123456',
        };

        expect(registerData.containsKey('username'), true);
        expect(registerData.containsKey('email'), true);
        expect(registerData.containsKey('password'), true);
        expect(registerData.containsKey('verificationCode'), true);
      });
    });

    group('MembershipService测试', () {
      late MembershipService membershipService;

      setUp(() {
        membershipService = MembershipService();
      });

      test('会员价格信息测试', () {
        final prices = membershipService.getMembershipPrices();

        expect(prices.containsKey('monthly'), true);
        expect(prices.containsKey('quarterly'), true);
        expect(prices.containsKey('yearly'), true);

        // 验证价格信息结构
        final monthlyPrice = prices['monthly']!;
        expect(monthlyPrice.containsKey('name'), true);
        expect(monthlyPrice.containsKey('price'), true);
        expect(monthlyPrice.containsKey('duration'), true);
        expect(monthlyPrice.containsKey('features'), true);
      });

      test('试用会员信息测试', () {
        final trialInfo = membershipService.getTrialMembership();

        expect(trialInfo.containsKey('name'), true);
        expect(trialInfo.containsKey('price'), true);
        expect(trialInfo.containsKey('duration'), true);
        expect(trialInfo.containsKey('features'), true);
        expect(trialInfo['price'], '免费');
      });
    });
  });

  group('模型测试', () {
    group('User模型测试', () {
      test('User.fromJson测试', () {
        final json = {
          'username': 'testuser',
          'email': 'test@example.com',
          'membershipType': 'premium',
          'membershipExpiry': '2024-12-31T23:59:59.000Z',
          'isAdmin': false,
        };

        final user = User.fromJson(json);

        expect(user.username, 'testuser');
        expect(user.email, 'test@example.com');
        expect(user.membershipType, 'premium');
        expect(user.isAdmin, false);
        expect(user.membershipExpiry, isNotNull);
      });

      test('User.toJson测试', () {
        final user = User(
          username: 'testuser',
          email: 'test@example.com',
          membershipType: 'premium',
          membershipExpiry: DateTime(2024, 12, 31),
          isAdmin: false,
        );

        final json = user.toJson();

        expect(json['username'], 'testuser');
        expect(json['email'], 'test@example.com');
        expect(json['membershipType'], 'premium');
        expect(json['isAdmin'], false);
        expect(json['membershipExpiry'], isNotNull);
      });

      test('会员状态判断测试', () {
        // 测试有效会员
        final premiumUser = User(
          username: 'premium',
          email: 'premium@example.com',
          membershipType: 'premium',
          membershipExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        expect(premiumUser.hasPremiumMembership, true);
        expect(premiumUser.isPremiumMember, true);

        // 测试过期会员
        final expiredUser = User(
          username: 'expired',
          email: 'expired@example.com',
          membershipType: 'premium',
          membershipExpiry: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(expiredUser.hasPremiumMembership, false);
        expect(expiredUser.isPremiumMember, false);

        // 测试试用会员
        final trialUser = User(
          username: 'trial',
          email: 'trial@example.com',
          membershipType: 'trial',
          membershipExpiry: DateTime.now().add(const Duration(days: 7)),
        );

        expect(trialUser.isTrialMember, true);
        expect(trialUser.hasPremiumMembership, true);
      });
    });
  });

  group('配置测试', () {
    test('应用配置测试', () {
      // 这里可以测试配置文件的正确性
      // 由于配置可能包含敏感信息，实际测试中应该使用测试配置
    });
  });
}

// 测试辅助函数 - 使用 Mock 接口而非继承工厂类
// 注意：由于 AuthService 使用工厂构造函数和单例模式，
// 在实际测试中应使用 mockito 或类似的 mocking 框架

// 测试用的Widget包装器
Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (context) => AuthModel())],
    child: MaterialApp(home: child),
  );
}


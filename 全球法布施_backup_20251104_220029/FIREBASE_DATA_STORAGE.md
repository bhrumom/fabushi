# Firebase 用户数据存储说明

## 📦 数据存储位置

### 1. Firebase Authentication（云端）
**存储内容：**
- ✅ 用户UID（唯一标识符）
- ✅ 邮箱地址
- ✅ 密码哈希（加密存储）
- ✅ 显示名称
- ✅ 邮箱验证状态
- ✅ 创建时间/最后登录时间
- ✅ OAuth提供商信息（Google等）

**访问方式：**
- Firebase Console > Authentication > Users
- 自动管理，无需手动操作

### 2. 本地设备存储（SharedPreferences）
**存储内容：**
```json
{
  "uid": "用户唯一ID",
  "email": "user@example.com",
  "displayName": "用户名",
  "emailVerified": true
}
```

**存储位置：**
- Android: `/data/data/包名/shared_prefs/`
- iOS: `Library/Preferences/`
- Web: LocalStorage
- macOS/Windows: 应用数据目录

### 3. 扩展数据存储（可选）

如需存储更多用户数据（会员信息、积分等），可使用：

#### Firestore（推荐）
```dart
// 添加依赖
cloud_firestore: ^5.0.0

// 保存用户资料
await FirebaseFirestore.instance
  .collection('users')
  .doc(user.uid)
  .set({
    'username': username,
    'membershipType': 'trial',
    'points': 0,
    'createdAt': FieldValue.serverTimestamp(),
  });
```

#### Realtime Database
```dart
// 添加依赖
firebase_database: ^11.0.0

// 保存数据
await FirebaseDatabase.instance
  .ref('users/${user.uid}')
  .set({
    'username': username,
    'email': email,
  });
```

## 🔒 数据安全

### Firebase Authentication 安全特性
- ✅ 密码使用 bcrypt 加密
- ✅ 支持多因素认证（MFA）
- ✅ 自动防暴力破解
- ✅ 邮箱验证机制
- ✅ 安全规则配置

### 本地存储安全
- ⚠️ SharedPreferences 未加密
- 建议：敏感数据使用 `flutter_secure_storage`

## 📊 数据查询

### 获取当前用户
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print('UID: ${user.uid}');
  print('Email: ${user.email}');
  print('Name: ${user.displayName}');
}
```

### 监听认证状态
```dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    print('用户已登出');
  } else {
    print('用户已登录: ${user.email}');
  }
});
```

## 🗑️ 数据删除

### 删除用户账户
```dart
await FirebaseAuth.instance.currentUser?.delete();
```

### 清除本地缓存
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.clear();
```

## 💡 最佳实践

1. **仅在Firebase存储认证信息**
2. **扩展数据使用Firestore**
3. **敏感数据使用加密存储**
4. **定期刷新用户token**
5. **实现离线缓存策略**

## 🔄 当前实现

本应用采用：
- ✅ Firebase Authentication（用户认证）
- ✅ SharedPreferences（本地缓存）
- ❌ 不同步Cloudflare后端
- ⚪ 可选：添加Firestore存储扩展数据

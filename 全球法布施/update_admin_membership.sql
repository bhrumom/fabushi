-- 更新管理员账号的会员状态
-- 将管理员账号的会员设置为1年有效期

-- 方法1：直接更新管理员账号（替换 'admin_username' 为实际的管理员用户名）
UPDATE users 
SET 
  membership_type = 'paid',
  membership_expires_at = datetime('now', '+365 days'),
  updated_at = datetime('now')
WHERE email = '1315518325@qq.com';

-- 查看更新结果
SELECT 
  username,
  email,
  membership_type,
  membership_expires_at,
  updated_at
FROM users 
WHERE email = '1315518325@qq.com';

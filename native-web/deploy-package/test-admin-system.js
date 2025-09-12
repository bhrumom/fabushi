// 管理员系统测试脚本
// 使用方法: node test-admin-system.js

const BASE_URL = 'http://localhost:8787';

// 测试用的管理员账号信息
const ADMIN_EMAIL = '1315518325@qq.com';
const ADMIN_USERNAME = 'admin_test';
const ADMIN_PASSWORD = 'AdminTest123';

// 普通用户账号信息
const USER_EMAIL = 'user@example.com';
const USER_USERNAME = 'normal_user';
const USER_PASSWORD = 'UserTest123';

let adminToken = '';
let userToken = '';

// HTTP 请求工具函数
async function request(method, path, data = null, token = null) {
    const headers = {
        'Content-Type': 'application/json'
    };
    
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    
    const options = {
        method,
        headers
    };
    
    if (data) {
        options.body = JSON.stringify(data);
    }
    
    try {
        const response = await fetch(`${BASE_URL}${path}`, options);
        const result = await response.json();
        return { status: response.status, data: result };
    } catch (error) {
        return { status: 0, error: error.message };
    }
}

// 测试函数
async function testAdminSystem() {
    console.log('🚀 开始测试管理员系统...\n');
    
    // 1. 注册管理员账号
    console.log('1. 注册管理员账号...');
    const adminRegister = await request('POST', '/api/auth/register', {
        username: ADMIN_USERNAME,
        email: ADMIN_EMAIL,
        password: ADMIN_PASSWORD,
        verificationCode: '123456' // 这里需要实际的验证码，测试时可能需要手动处理
    });
    console.log('管理员注册结果:', adminRegister);
    
    // 2. 管理员登录
    console.log('\n2. 管理员登录...');
    const adminLogin = await request('POST', '/api/auth/login', {
        username: ADMIN_USERNAME,
        password: ADMIN_PASSWORD
    });
    console.log('管理员登录结果:', adminLogin);
    
    if (adminLogin.status === 200) {
        adminToken = adminLogin.data.token;
        console.log('✅ 管理员登录成功');
    } else {
        console.log('❌ 管理员登录失败');
        return;
    }
    
    // 3. 检查管理员状态
    console.log('\n3. 检查管理员状态...');
    const adminStatus = await request('GET', '/api/admin/check-status', null, adminToken);
    console.log('管理员状态检查结果:', adminStatus);
    
    if (adminStatus.data?.isAdmin) {
        console.log('✅ 管理员权限验证成功');
    } else {
        console.log('❌ 管理员权限验证失败');
    }
    
    // 4. 生成兑换码
    console.log('\n4. 生成兑换码...');
    const createCode = await request('POST', '/api/admin/create-redeem-code', {
        type: 'monthly',
        quantity: 2,
        description: '测试兑换码'
    }, adminToken);
    console.log('生成兑换码结果:', createCode);
    
    let testCode = '';
    if (createCode.status === 200 && createCode.data.codes) {
        testCode = createCode.data.codes[0];
        console.log('✅ 兑换码生成成功:', testCode);
    } else {
        console.log('❌ 兑换码生成失败');
    }
    
    // 5. 查看兑换码列表
    console.log('\n5. 查看兑换码列表...');
    const listCodes = await request('GET', '/api/admin/redeem-codes?status=all&limit=10', null, adminToken);
    console.log('兑换码列表结果:', listCodes);
    
    // 6. 注册普通用户
    console.log('\n6. 注册普通用户...');
    const userRegister = await request('POST', '/api/auth/register', {
        username: USER_USERNAME,
        email: USER_EMAIL,
        password: USER_PASSWORD,
        verificationCode: '123456'
    });
    console.log('普通用户注册结果:', userRegister);
    
    // 7. 普通用户登录
    console.log('\n7. 普通用户登录...');
    const userLogin = await request('POST', '/api/auth/login', {
        username: USER_USERNAME,
        password: USER_PASSWORD
    });
    console.log('普通用户登录结果:', userLogin);
    
    if (userLogin.status === 200) {
        userToken = userLogin.data.token;
        console.log('✅ 普通用户登录成功');
    }
    
    // 8. 普通用户检查管理员状态（应该失败）
    console.log('\n8. 普通用户检查管理员状态...');
    const userAdminCheck = await request('GET', '/api/admin/check-status', null, userToken);
    console.log('普通用户管理员状态检查结果:', userAdminCheck);
    
    if (!userAdminCheck.data?.isAdmin) {
        console.log('✅ 普通用户权限验证正确');
    } else {
        console.log('❌ 普通用户权限验证失败');
    }
    
    // 9. 普通用户使用兑换码
    if (testCode && userToken) {
        console.log('\n9. 普通用户使用兑换码...');
        const useCode = await request('POST', '/api/admin/use-redeem-code', {
            code: testCode
        }, userToken);
        console.log('使用兑换码结果:', useCode);
        
        if (useCode.status === 200) {
            console.log('✅ 兑换码使用成功');
        } else {
            console.log('❌ 兑换码使用失败');
        }
    }
    
    // 10. 检查管理员价格
    console.log('\n10. 检查管理员价格...');
    const adminPrice = await request('POST', '/api/admin/get-price', {
        plan: 'monthly'
    }, adminToken);
    console.log('管理员价格检查结果:', adminPrice);
    
    if (adminPrice.data?.isAdmin && adminPrice.data?.adminPrice === '0.01') {
        console.log('✅ 管理员特殊价格验证成功');
    } else {
        console.log('❌ 管理员特殊价格验证失败');
    }
    
    // 11. 普通用户检查价格
    if (userToken) {
        console.log('\n11. 普通用户检查价格...');
        const userPrice = await request('POST', '/api/admin/get-price', {
            plan: 'monthly'
        }, userToken);
        console.log('普通用户价格检查结果:', userPrice);
        
        if (!userPrice.data?.isAdmin && userPrice.data?.price === '21') {
            console.log('✅ 普通用户价格验证成功');
        } else {
            console.log('❌ 普通用户价格验证失败');
        }
    }
    
    console.log('\n🎉 管理员系统测试完成！');
}

// 运行测试
if (typeof window === 'undefined') {
    // Node.js 环境
    const fetch = require('node-fetch');
    testAdminSystem().catch(console.error);
} else {
    // 浏览器环境
    window.testAdminSystem = testAdminSystem;
    console.log('测试函数已加载，请在控制台运行: testAdminSystem()');
}
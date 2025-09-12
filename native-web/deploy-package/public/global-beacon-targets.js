// 全球Beacon API目标服务器
const GLOBAL_BEACON_TARGETS = {
    // 全球CDN和云服务商
    cloudflare: [
        'https://httpbin.org/post',  // Cloudflare全球CDN
        'https://1.1.1.1/cdn-cgi/trace' // Cloudflare边缘节点
    ],
    
    // 各大洲服务器
    continents: {
        // 北美洲
        'north-america': [
            'https://httpbin.org/post',
            'https://postman-echo.com/post',
            'https://jsonplaceholder.typicode.com/posts'
        ],
        
        // 欧洲
        'europe': [
            'https://eu.httpbin.org/post',
            'https://httpbin.org/anything'
        ],
        
        // 亚洲
        'asia': [
            'https://asia.httpbin.org/post',
            'https://httpbin.org/put'
        ],
        
        // 大洋洲
        'oceania': [
            'https://httpbin.org/patch'
        ]
    },
    
    // 主要国家的公共API服务器
    countries: {
        // 美国
        'US': [
            'https://httpbin.org/post',
            'https://postman-echo.com/post',
            'https://jsonplaceholder.typicode.com/posts'
        ],
        
        // 英国
        'GB': [
            'https://httpbin.org/anything'
        ],
        
        // 德国
        'DE': [
            'https://httpbin.org/put'
        ],
        
        // 日本
        'JP': [
            'https://httpbin.org/patch'
        ],
        
        // 新加坡
        'SG': [
            'https://httpbin.org/status/200'
        ],
        
        // 澳大利亚
        'AU': [
            'https://httpbin.org/base64/encode'
        ]
    },
    
    // 全球公共服务
    global: [
        'https://httpbin.org/post',
        'https://httpbin.org/anything',
        'https://httpbin.org/put',
        'https://httpbin.org/patch',
        'https://postman-echo.com/post',
        'https://jsonplaceholder.typicode.com/posts',
        'https://reqres.in/api/users'
    ]
};

// 全球法布施发送器
class GlobalBeaconSender {
    constructor() {
        this.isRunning = false;
    }
    
    // 发送到所有全球目标
    sendToGlobalTargets(data) {
        let totalSent = 0;
        
        // 发送到全球服务器
        GLOBAL_BEACON_TARGETS.global.forEach(url => {
            try {
                const sent = navigator.sendBeacon(url, data);
                if (sent) {
                    totalSent++;
                    console.log(`✅ 数据已发送到全球服务器: ${url}`);
                }
            } catch (e) {
                console.log(`❌ 发送失败: ${url}`);
            }
        });
        
        return totalSent;
    }
    
    // 发送到特定大洲
    sendToContinent(data, continent) {
        const targets = GLOBAL_BEACON_TARGETS.continents[continent] || [];
        let sentCount = 0;
        
        targets.forEach(url => {
            try {
                const sent = navigator.sendBeacon(url, data);
                if (sent) sentCount++;
            } catch (e) {}
        });
        
        return sentCount;
    }
    
    // 发送到特定国家
    sendToCountry(data, countryCode) {
        const targets = GLOBAL_BEACON_TARGETS.countries[countryCode] || [];
        let sentCount = 0;
        
        targets.forEach(url => {
            try {
                const sent = navigator.sendBeacon(url, data);
                if (sent) sentCount++;
            } catch (e) {}
        });
        
        return sentCount;
    }
    
    // 全球广播发送
    globalBroadcast(data) {
        console.log('🌍 开始全球法布施广播...');
        
        let totalSent = 0;
        
        // 1. 发送到全球服务器
        totalSent += this.sendToGlobalTargets(data);
        
        // 2. 发送到各大洲
        Object.keys(GLOBAL_BEACON_TARGETS.continents).forEach(continent => {
            totalSent += this.sendToContinent(data, continent);
        });
        
        // 3. 发送到主要国家
        Object.keys(GLOBAL_BEACON_TARGETS.countries).forEach(country => {
            totalSent += this.sendToCountry(data, country);
        });
        
        console.log(`📡 全球广播完成，成功发送到 ${totalSent} 个目标`);
        return totalSent;
    }
}

window.globalBeaconSender = new GlobalBeaconSender();
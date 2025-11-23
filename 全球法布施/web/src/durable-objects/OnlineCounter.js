/**
 * OnlineCounter Durable Object
 * 管理特定活动类型的在线用户计数
 * 
 * 功能：
 * - 追踪用户会话和最后心跳时间
 * - 自动清理超时用户（90秒未心跳）
 * - 提供实时在线人数统计
 */
export class OnlineCounter {
    constructor(state, env) {
        this.state = state;
        this.env = env;
        // 存储格式: sessionId -> lastHeartbeat (timestamp)
        this.sessions = new Map();
        this.TIMEOUT_MS = 90 * 1000; // 90秒超时
        this.CLEANUP_INTERVAL_MS = 30 * 1000; // 30秒检查一次
    }

    /**
     * 处理HTTP请求
     */
    async fetch(request) {
        const url = new URL(request.url);
        const action = url.searchParams.get('action');

        try {
            switch (action) {
                case 'join':
                    return await this.handleJoin(request);
                case 'heartbeat':
                    return await this.handleHeartbeat(request);
                case 'leave':
                    return await this.handleLeave(request);
                case 'count':
                    return await this.handleCount();
                default:
                    return this.jsonResponse({ error: 'Invalid action' }, 400);
            }
        } catch (error) {
            console.error('OnlineCounter error:', error);
            return this.jsonResponse({ error: error.message }, 500);
        }
    }

    /**
     * 用户加入活动
     */
    async handleJoin(request) {
        const { sessionId } = await request.json();

        if (!sessionId) {
            return this.jsonResponse({ error: 'sessionId required' }, 400);
        }

        const now = Date.now();
        this.sessions.set(sessionId, now);

        // 设置定时清理（如果还没设置）
        await this.ensureAlarm();

        console.log(`Session ${sessionId} joined. Total: ${this.sessions.size}`);

        return this.jsonResponse({
            success: true,
            sessionId,
            count: this.sessions.size
        });
    }

    /**
     * 用户心跳保活
     */
    async handleHeartbeat(request) {
        const { sessionId } = await request.json();

        if (!sessionId) {
            return this.jsonResponse({ error: 'sessionId required' }, 400);
        }

        if (!this.sessions.has(sessionId)) {
            // 会话不存在，可能已超时，返回错误让客户端重新join
            return this.jsonResponse({
                error: 'Session not found',
                shouldRejoin: true
            }, 404);
        }

        const now = Date.now();
        this.sessions.set(sessionId, now);

        return this.jsonResponse({
            success: true,
            count: this.sessions.size
        });
    }

    /**
     * 用户主动离开
     */
    async handleLeave(request) {
        const { sessionId } = await request.json();

        if (!sessionId) {
            return this.jsonResponse({ error: 'sessionId required' }, 400);
        }

        const existed = this.sessions.delete(sessionId);

        console.log(`Session ${sessionId} left. Total: ${this.sessions.size}`);

        return this.jsonResponse({
            success: true,
            existed,
            count: this.sessions.size
        });
    }

    /**
     * 获取当前在线人数
     */
    async handleCount() {
        // 先清理超时会话
        await this.cleanupTimeoutSessions();

        return this.jsonResponse({
            count: this.sessions.size
        });
    }

    /**
     * 清理超时的会话
     */
    async cleanupTimeoutSessions() {
        const now = Date.now();
        let cleanedCount = 0;

        for (const [sessionId, lastHeartbeat] of this.sessions.entries()) {
            if (now - lastHeartbeat > this.TIMEOUT_MS) {
                this.sessions.delete(sessionId);
                cleanedCount++;
            }
        }

        if (cleanedCount > 0) {
            console.log(`Cleaned ${cleanedCount} timeout sessions. Remaining: ${this.sessions.size}`);
        }

        return cleanedCount;
    }

    /**
     * 确保设置了定时清理alarm
     */
    async ensureAlarm() {
        const currentAlarm = await this.state.storage.getAlarm();
        if (currentAlarm === null) {
            // 设置下一次清理时间
            await this.state.storage.setAlarm(Date.now() + this.CLEANUP_INTERVAL_MS);
        }
    }

    /**
     * Alarm处理器 - 定期清理超时会话
     */
    async alarm() {
        await this.cleanupTimeoutSessions();

        // 如果还有活跃会话，继续设置下一次alarm
        if (this.sessions.size > 0) {
            await this.state.storage.setAlarm(Date.now() + this.CLEANUP_INTERVAL_MS);
        }
    }

    /**
     * 辅助方法：返回JSON响应
     */
    jsonResponse(data, status = 200) {
        return new Response(JSON.stringify(data), {
            status,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type',
            }
        });
    }
}

import { handleRegister, handleLogin, handleGetUserInfo, handleUpdateProfile, handleFirebasePhoneLogin, handleAppleLogin, handleDeleteAccount } from './handlers/auth.js';
import { handleSendSmsCode, handleSmsLogin } from './handlers/sms.js';
import { handleGetComments, handlePostComment, handleDeleteComment, handleGetTaggedPosts, handleGetHotFeed, handlePostDetail, handleBatchGetCommentCounts } from './handlers/comments.js';

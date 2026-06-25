"use strict";
(wx["webpackJsonp"] = wx["webpackJsonp"] || []).push([["pages/index/index"],{

/***/ "../../node_modules/.pnpm/@tarojs+taro-loader@4.2.0_@swc+helpers@0.5.15_webpack@5.91.0_@swc+core@1.3.96_@swc+helpers@0.5.15__postcss@8.5.15_/node_modules/@tarojs/taro-loader/lib/entry-cache.js?name=pages/index/index!./src/pages/index/index.tsx":
/*!**********************************************************************************************************************************************************************************************************************************************************!*\
  !*** ../../node_modules/.pnpm/@tarojs+taro-loader@4.2.0_@swc+helpers@0.5.15_webpack@5.91.0_@swc+core@1.3.96_@swc+helpers@0.5.15__postcss@8.5.15_/node_modules/@tarojs/taro-loader/lib/entry-cache.js?name=pages/index/index!./src/pages/index/index.tsx ***!
  \**********************************************************************************************************************************************************************************************************************************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": function() { return /* binding */ IndexPage; }
/* harmony export */ });
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_toConsumableArray_js__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/toConsumableArray.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/toConsumableArray.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regenerator.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regenerator.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_asyncToGenerator_js__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/asyncToGenerator.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/asyncToGenerator.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_slicedToArray_js__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/slicedToArray.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/slicedToArray.js");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "../../node_modules/.pnpm/react@18.3.1/node_modules/react/index.js");
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(react__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _tarojs_components__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @tarojs/components */ "../../node_modules/.pnpm/@tarojs+plugin-platform-weapp@4.2.0_@tarojs+service@4.2.0_@swc+helpers@0.5.15__@tarojs+shared@4.2.0/node_modules/@tarojs/plugin-platform-weapp/dist/components-react.js");
/* harmony import */ var _tarojs_taro__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @tarojs/taro */ "../../node_modules/.pnpm/@tarojs+taro@4.2.0_@tarojs+components@4.2.0_@tarojs+helper@4.2.0_@swc+helpers@0.5.15__@_ca19397a3faad49c6c33d55da60d24dc/node_modules/@tarojs/taro/index.js");
/* harmony import */ var _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_tarojs_taro__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var _fabushi_shared__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @fabushi/shared */ "../../packages/shared/src/index.ts");
/* harmony import */ var _fabushi_api_client__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @fabushi/api-client */ "../../packages/api-client/src/index.ts");
/* harmony import */ var react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! react/jsx-runtime */ "../../node_modules/.pnpm/react@18.3.1/node_modules/react/cjs/react-jsx-runtime.production.min.js");











var AI_BASE = (0,_fabushi_api_client__WEBPACK_IMPORTED_MODULE_3__.getDachengAiApiBaseUrl)();
var suggestions = [{
  icon: "✦",
  label: "大乘能做什么",
  prompt: _fabushi_shared__WEBPACK_IMPORTED_MODULE_2__.aiQuickPrompts[0]
}, {
  icon: "◉",
  label: "开始全球法布施",
  prompt: "",
  route: "/pages/globe/index"
}, {
  icon: "⌕",
  label: "AI找资源",
  prompt: "请帮我找适合初学者阅读的佛经资源。"
}, {
  icon: "▣",
  label: "加入功课本",
  prompt: "帮我整理一份今天可以完成的简短功课。"
}, {
  icon: "♡",
  label: "发愿文案",
  prompt: "请帮我润色一段慈悲、简洁的发愿文案。"
}];
function IndexPage() {
  var _user$membership;
  var _useState = (0,react__WEBPACK_IMPORTED_MODULE_0__.useState)(false),
    _useState2 = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_slicedToArray_js__WEBPACK_IMPORTED_MODULE_5__["default"])(_useState, 2),
    sidebarOpen = _useState2[0],
    setSidebarOpen = _useState2[1];
  var _useState3 = (0,react__WEBPACK_IMPORTED_MODULE_0__.useState)(""),
    _useState4 = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_slicedToArray_js__WEBPACK_IMPORTED_MODULE_5__["default"])(_useState3, 2),
    draft = _useState4[0],
    setDraft = _useState4[1];
  var _useState5 = (0,react__WEBPACK_IMPORTED_MODULE_0__.useState)(false),
    _useState6 = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_slicedToArray_js__WEBPACK_IMPORTED_MODULE_5__["default"])(_useState5, 2),
    loading = _useState6[0],
    setLoading = _useState6[1];
  var _useState7 = (0,react__WEBPACK_IMPORTED_MODULE_0__.useState)(null),
    _useState8 = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_slicedToArray_js__WEBPACK_IMPORTED_MODULE_5__["default"])(_useState7, 2),
    user = _useState8[0],
    setUser = _useState8[1];
  (0,react__WEBPACK_IMPORTED_MODULE_0__.useEffect)(function () {
    var savedUser = _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().getStorageSync("fabushi_user");
    if (savedUser) {
      try {
        setUser(JSON.parse(savedUser));
      } catch (e) {}
    }
  }, []);
  var _useState9 = (0,react__WEBPACK_IMPORTED_MODULE_0__.useState)([{
      id: "welcome",
      role: "assistant",
      text: "你好，我是大乘。你可以问经文、找资源，或让我帮你整理可分享的善法内容。"
    }]),
    _useState0 = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_slicedToArray_js__WEBPACK_IMPORTED_MODULE_5__["default"])(_useState9, 2),
    messages = _useState0[0],
    setMessages = _useState0[1];
  function handleSuggestionClick(item) {
    if (item.route) {
      _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().navigateTo({
        url: item.route
      });
    } else {
      setDraft(item.prompt);
    }
  }
  function startNewChat() {
    setMessages([]);
    setDraft("");
    setSidebarOpen(false);
  }
  function handleWechatLogin() {
    return _handleWechatLogin.apply(this, arguments);
  }
  function _handleWechatLogin() {
    _handleWechatLogin = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_asyncToGenerator_js__WEBPACK_IMPORTED_MODULE_6__["default"])(/*#__PURE__*/(0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_7__["default"])().m(function _callee() {
      var _yield$Taro$login, code, response, _response$data, _user, token, _t;
      return (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_7__["default"])().w(function (_context) {
        while (1) switch (_context.p = _context.n) {
          case 0:
            _context.p = 0;
            _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().showLoading({
              title: "登录中..."
            });
            _context.n = 1;
            return _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().login();
          case 1:
            _yield$Taro$login = _context.v;
            code = _yield$Taro$login.code;
            if (code) {
              _context.n = 2;
              break;
            }
            throw new Error("获取微信 code 失败");
          case 2:
            _context.n = 3;
            return _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().request({
              url: "".concat(_fabushi_api_client__WEBPACK_IMPORTED_MODULE_3__.API_BASE_URL, "/api/auth/wechat/mp-login"),
              method: "POST",
              data: {
                code: code
              }
            });
          case 3:
            response = _context.v;
            if (!(response.statusCode === 200 && response.data.success)) {
              _context.n = 4;
              break;
            }
            _response$data = response.data, _user = _response$data.user, token = _response$data.token;
            setUser(_user);
            _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().setStorageSync("fabushi_user", JSON.stringify(_user));
            _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().setStorageSync("fabushi_token", token);
            _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().showToast({
              title: "登录成功",
              icon: "success"
            });
            _context.n = 5;
            break;
          case 4:
            throw new Error(response.data.error || "登录失败");
          case 5:
            _context.n = 7;
            break;
          case 6:
            _context.p = 6;
            _t = _context.v;
            _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().showToast({
              title: _t.message || "登录出错",
              icon: "none"
            });
          case 7:
            _context.p = 7;
            _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().hideLoading();
            return _context.f(7);
          case 8:
            return _context.a(2);
        }
      }, _callee, null, [[0, 6, 7, 8]]);
    }));
    return _handleWechatLogin.apply(this, arguments);
  }
  function sendMessage() {
    return _sendMessage.apply(this, arguments);
  }
  function _sendMessage() {
    _sendMessage = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_asyncToGenerator_js__WEBPACK_IMPORTED_MODULE_6__["default"])(/*#__PURE__*/(0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_7__["default"])().m(function _callee2() {
      var text, userMessage, response, _t2;
      return (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_7__["default"])().w(function (_context2) {
        while (1) switch (_context2.p = _context2.n) {
          case 0:
            text = draft.trim();
            if (!(!text || loading)) {
              _context2.n = 1;
              break;
            }
            return _context2.a(2);
          case 1:
            userMessage = {
              id: "user-".concat(Date.now()),
              role: "user",
              text: text
            };
            setMessages(function (current) {
              return [].concat((0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_toConsumableArray_js__WEBPACK_IMPORTED_MODULE_8__["default"])(current), [userMessage]);
            });
            setDraft("");
            setLoading(true);
            _context2.p = 2;
            _context2.n = 3;
            return _tarojs_taro__WEBPACK_IMPORTED_MODULE_1___default().request({
              url: "".concat(AI_BASE).concat(_fabushi_api_client__WEBPACK_IMPORTED_MODULE_3__.dachengAiEndpoints.chat),
              method: "POST",
              header: {
                Accept: "application/json",
                "Content-Type": "application/json"
              },
              data: {
                message: text,
                clientMembershipHint: false
              },
              timeout: 60000
            });
          case 3:
            response = _context2.v;
            if (!(response.statusCode < 200 || response.statusCode >= 300 || response.data.success === false)) {
              _context2.n = 4;
              break;
            }
            throw new Error(response.data.message || "\u8BF7\u6C42\u5931\u8D25 ".concat(response.statusCode));
          case 4:
            setMessages(function (current) {
              return [].concat((0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_toConsumableArray_js__WEBPACK_IMPORTED_MODULE_8__["default"])(current), [{
                id: "assistant-".concat(Date.now()),
                role: "assistant",
                text: response.data.message || "AI 暂未返回内容。"
              }]);
            });
            _context2.n = 6;
            break;
          case 5:
            _context2.p = 5;
            _t2 = _context2.v;
            setMessages(function (current) {
              return [].concat((0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_toConsumableArray_js__WEBPACK_IMPORTED_MODULE_8__["default"])(current), [{
                id: "error-".concat(Date.now()),
                role: "assistant",
                text: _t2 instanceof Error ? _t2.message : "大乘 AI 暂不可用，请稍后再试。"
              }]);
            });
          case 6:
            _context2.p = 6;
            setLoading(false);
            return _context2.f(6);
          case 7:
            return _context2.a(2);
        }
      }, _callee2, null, [[2, 5, 6, 7]]);
    }));
    return _sendMessage.apply(this, arguments);
  }
  return /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
    className: "chat-page",
    children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
      className: "topbar",
      children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
        className: "menu-button",
        onClick: function onClick() {
          return setSidebarOpen(true);
        },
        children: "\u2630"
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
        className: "brand",
        children: "\u5927\u4E58"
      })]
    }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
      className: "chat-main",
      children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
        className: "intro",
        children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
          className: "greeting",
          children: ["Hi, ", user ? user.nickname || user.username : '朋友']
        }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
          className: "subtitle",
          children: "\u628A\u53EF\u5206\u4EAB\u7684\u5584\u6CD5\u8D44\u6E90\uFF0C\u5E26\u5230\u5168\u7403"
        })]
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
        className: "suggestions",
        children: suggestions.map(function (item) {
          return /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
            className: "suggestion",
            onClick: function onClick() {
              return handleSuggestionClick(item);
            },
            children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
              className: "suggestion-icon",
              children: item.icon
            }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
              children: item.label
            })]
          }, item.label);
        })
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
        className: "messages",
        children: [messages.map(function (message) {
          return /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
            className: "message ".concat(message.role),
            children: /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
              children: message.text
            })
          }, message.id);
        }), loading && /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
          className: "message assistant",
          children: /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
            children: "\u6B63\u5728\u751F\u6210..."
          })
        })]
      })]
    }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
      className: "composer",
      children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
        className: "add-button",
        children: "\uFF0B"
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Input, {
        className: "chat-input",
        value: draft,
        placeholder: "\u95EE\u95EE\u5927\u4E58",
        confirmType: "send",
        onInput: function onInput(event) {
          return setDraft(event.detail.value);
        },
        onConfirm: sendMessage
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
        className: "send-button",
        loading: loading,
        onClick: sendMessage,
        children: "\u2191"
      })]
    }), sidebarOpen && /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
      className: "scrim",
      onClick: function onClick() {
        return setSidebarOpen(false);
      }
    }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
      className: "sidebar ".concat(sidebarOpen ? "open" : ""),
      children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
        className: "sidebar-header",
        children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
          className: "sidebar-title",
          children: "\u5927\u4E58"
        }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
          className: "close-button",
          onClick: function onClick() {
            return setSidebarOpen(false);
          },
          children: "\xD7"
        })]
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
        className: "sidebar-user",
        children: user ? /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
          className: "user-profile",
          children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Image, {
            className: "user-avatar",
            src: user.avatar || "https://mmbiz.qpic.cn/mmbiz/icTdbqWNOwNRna42FI242Lcia07jQodd2FJGIYQfG0LAJGFxM4FbnQP6yfMxBgJ0F3YRqJCJ1aPAK2dQagdusBZg/0"
          }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
            className: "user-info",
            children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
              className: "user-name",
              children: user.nickname || user.username
            }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
              className: "user-membership",
              children: ((_user$membership = user.membership) === null || _user$membership === void 0 ? void 0 : _user$membership.type) === 'expired' ? '普通用户' : '会员用户'
            })]
          })]
        }) : /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
          className: "wechat-login-btn",
          onClick: handleWechatLogin,
          children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
            className: "wechat-icon",
            children: "\u268F"
          }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
            children: "\u5FAE\u4FE1\u5FEB\u6377\u767B\u5F55"
          })]
        })
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsxs)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Button, {
        className: "new-chat",
        onClick: startNewChat,
        children: [/*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
          className: "new-chat-icon",
          children: "\u229E"
        }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
          children: "\u5F00\u542F\u65B0\u5BF9\u8BDD"
        })]
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
        className: "today",
        children: "\u4ECA\u5929"
      }), /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.View, {
        className: "empty",
        children: /*#__PURE__*/(0,react_jsx_runtime__WEBPACK_IMPORTED_MODULE_4__.jsx)(_tarojs_components__WEBPACK_IMPORTED_MODULE_9__.Text, {
          children: "\u6CA1\u6709\u66F4\u591A\u5185\u5BB9\u5566"
        })
      })]
    })]
  });
}

/***/ }),

/***/ "./src/pages/index/index.tsx":
/*!***********************************!*\
  !*** ./src/pages/index/index.tsx ***!
  \***********************************/
/***/ (function(__unused_webpack_module, __unused_webpack___webpack_exports__, __webpack_require__) {

/* harmony import */ var _tarojs_runtime__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @tarojs/runtime */ "../../node_modules/.pnpm/@tarojs+runtime@4.2.0/node_modules/@tarojs/runtime/dist/dsl/common.js");
/* harmony import */ var _node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! !!../../../../../node_modules/.pnpm/@tarojs+taro-loader@4.2.0_@swc+helpers@0.5.15_webpack@5.91.0_@swc+core@1.3.96_@swc+helpers@0.5.15__postcss@8.5.15_/node_modules/@tarojs/taro-loader/lib/entry-cache.js?name=pages/index/index!./index.tsx */ "../../node_modules/.pnpm/@tarojs+taro-loader@4.2.0_@swc+helpers@0.5.15_webpack@5.91.0_@swc+core@1.3.96_@swc+helpers@0.5.15__postcss@8.5.15_/node_modules/@tarojs/taro-loader/lib/entry-cache.js?name=pages/index/index!./src/pages/index/index.tsx");


var config = {"enableShareAppMessage":true,"navigationBarTitleText":"全球法布施"};

_node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__["default"].enableShareAppMessage = true

var taroOption = (0,_tarojs_runtime__WEBPACK_IMPORTED_MODULE_1__.createPageConfig)(_node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__["default"], 'pages/index/index', {root:{cn:[]}}, config || {})
if (_node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__["default"] && _node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__["default"].behaviors) {
  taroOption.behaviors = (taroOption.behaviors || []).concat(_node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__["default"].behaviors)
}
var inst = Page(taroOption)



/* unused harmony default export */ var __WEBPACK_DEFAULT_EXPORT__ = (_node_modules_pnpm_tarojs_taro_loader_4_2_0_swc_helpers_0_5_15_webpack_5_91_0_swc_core_1_3_96_swc_helpers_0_5_15_postcss_8_5_15_node_modules_tarojs_taro_loader_lib_entry_cache_js_name_pages_index_index_index_tsx__WEBPACK_IMPORTED_MODULE_0__["default"]);


/***/ }),

/***/ "../../packages/api-client/src/client.ts":
/*!***********************************************!*\
  !*** ../../packages/api-client/src/client.ts ***!
  \***********************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* unused harmony exports FabushiApiClient, fabushiApiClient */
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regenerator.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regenerator.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_objectSpread2_js__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/objectSpread2.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/objectSpread2.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_asyncToGenerator_js__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/asyncToGenerator.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/asyncToGenerator.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_classCallCheck_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/classCallCheck.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/classCallCheck.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_createClass_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/createClass.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/createClass.js");
/* harmony import */ var _endpoints__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./endpoints */ "../../packages/api-client/src/endpoints.ts");






var FabushiApiClient = /*#__PURE__*/function () {
  function FabushiApiClient() {
    var baseUrl = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : _endpoints__WEBPACK_IMPORTED_MODULE_0__.API_BASE_URL;
    (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_classCallCheck_js__WEBPACK_IMPORTED_MODULE_1__["default"])(this, FabushiApiClient);
    this.baseUrl = baseUrl;
  }
  return (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_createClass_js__WEBPACK_IMPORTED_MODULE_2__["default"])(FabushiApiClient, [{
    key: "get",
    value: function () {
      var _get = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_asyncToGenerator_js__WEBPACK_IMPORTED_MODULE_3__["default"])(/*#__PURE__*/(0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_4__["default"])().m(function _callee(path, init) {
        var _init$headers;
        var response;
        return (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_regenerator_js__WEBPACK_IMPORTED_MODULE_4__["default"])().w(function (_context) {
          while (1) switch (_context.n) {
            case 0:
              _context.n = 1;
              return fetch("".concat(this.baseUrl).concat(path), (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_objectSpread2_js__WEBPACK_IMPORTED_MODULE_5__["default"])((0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_objectSpread2_js__WEBPACK_IMPORTED_MODULE_5__["default"])({}, init), {}, {
                headers: (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_objectSpread2_js__WEBPACK_IMPORTED_MODULE_5__["default"])({
                  Accept: "application/json"
                }, (_init$headers = init === null || init === void 0 ? void 0 : init.headers) !== null && _init$headers !== void 0 ? _init$headers : {}),
                cache: "no-store"
              }));
            case 1:
              response = _context.v;
              if (response.ok) {
                _context.n = 2;
                break;
              }
              throw new Error("Request failed with ".concat(response.status));
            case 2:
              _context.n = 3;
              return response.json();
            case 3:
              return _context.a(2, _context.v);
          }
        }, _callee, this);
      }));
      function get(_x, _x2) {
        return _get.apply(this, arguments);
      }
      return get;
    }()
  }]);
}();
var fabushiApiClient = new FabushiApiClient();

/***/ }),

/***/ "../../packages/api-client/src/dacheng-ai.ts":
/*!***************************************************!*\
  !*** ../../packages/api-client/src/dacheng-ai.ts ***!
  \***************************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   dachengAiEndpoints: function() { return /* binding */ dachengAiEndpoints; },
/* harmony export */   getDachengAiApiBaseUrl: function() { return /* binding */ getDachengAiApiBaseUrl; }
/* harmony export */ });
/* unused harmony export parseDachengSseChunk */
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_typeof_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/typeof.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/typeof.js");
/* harmony import */ var _Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_createForOfIteratorHelper_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/createForOfIteratorHelper.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/createForOfIteratorHelper.js");
/* provided dependency */ var window = __webpack_require__(/*! @tarojs/runtime */ "../../node_modules/.pnpm/@tarojs+runtime@4.2.0/node_modules/@tarojs/runtime/dist/index.js")["window"];


var DEFAULT_DACHENG_AI_PROXY_PATH = "/api/dacheng-ai";
var DEFAULT_DACHENG_AI_ORIGIN = "https://fabushi.ombhrum.com";
var DEFAULT_LOCAL_DACHENG_AI_API_BASE = "https://ai.ombhrum.com";
function readConfiguredAiBaseUrl() {
  var _env$process, _env$process2;
  var env = globalThis;
  return (((_env$process = env.process) === null || _env$process === void 0 || (_env$process = _env$process.env) === null || _env$process === void 0 ? void 0 : _env$process.NEXT_PUBLIC_DACHENG_AI_API_BASE_URL) || ((_env$process2 = env.process) === null || _env$process2 === void 0 || (_env$process2 = _env$process2.env) === null || _env$process2 === void 0 ? void 0 : _env$process2.TARO_APP_DACHENG_AI_API_BASE_URL) || "").trim();
}
function getDachengAiApiBaseUrl() {
  var configured = readConfiguredAiBaseUrl();
  if (configured) {
    return configured.replace(/\/+$/, "");
  }
  if (typeof window !== "undefined" && window.location.origin) {
    if (/^(localhost|127\.0\.0\.1|\[::1\])$/.test(window.location.hostname)) {
      return DEFAULT_LOCAL_DACHENG_AI_API_BASE;
    }
    return "".concat(window.location.origin).concat(DEFAULT_DACHENG_AI_PROXY_PATH);
  }
  return "".concat(DEFAULT_DACHENG_AI_ORIGIN).concat(DEFAULT_DACHENG_AI_PROXY_PATH);
}
var dachengAiEndpoints = {
  health: "/health",
  chat: "/api/ai/chat",
  chatStream: "/api/ai/chat/stream",
  conversations: "/api/ai/conversations",
  conversation: function conversation(id) {
    return "/api/ai/conversations/".concat(encodeURIComponent(id));
  },
  resourceSearch: "/api/resources/search",
  resourceDownload: "/api/resources/download"
};
function parseDachengSseChunk(chunk) {
  var currentEventName = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : "message";
  var events = [];
  var parts = chunk.split(/\n\n+/);
  var _iterator = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_createForOfIteratorHelper_js__WEBPACK_IMPORTED_MODULE_0__["default"])(parts),
    _step;
  try {
    for (_iterator.s(); !(_step = _iterator.n()).done;) {
      var _ref, _ref2, _ref3, _payload$text;
      var part = _step.value;
      var lines = part.split(/\r?\n/).filter(Boolean);
      if (lines.length === 0) continue;
      var eventName = currentEventName;
      var dataLines = [];
      var _iterator2 = (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_createForOfIteratorHelper_js__WEBPACK_IMPORTED_MODULE_0__["default"])(lines),
        _step2;
      try {
        for (_iterator2.s(); !(_step2 = _iterator2.n()).done;) {
          var line = _step2.value;
          if (line.startsWith("event:")) {
            eventName = line.slice("event:".length).trim() || "message";
          } else if (line.startsWith("data:")) {
            dataLines.push(line.slice("data:".length).trim());
          }
        }
      } catch (err) {
        _iterator2.e(err);
      } finally {
        _iterator2.f();
      }
      if (dataLines.length === 0) continue;
      var dataText = dataLines.join("\n");
      var payload = void 0;
      try {
        var decoded = JSON.parse(dataText);
        payload = decoded && (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_typeof_js__WEBPACK_IMPORTED_MODULE_1__["default"])(decoded) === "object" ? decoded : {
          text: String(decoded)
        };
      } catch (_unused) {
        payload = {
          text: dataText
        };
      }
      var type = eventName;
      var text = String((_ref = (_ref2 = (_ref3 = (_payload$text = payload.text) !== null && _payload$text !== void 0 ? _payload$text : payload.message) !== null && _ref3 !== void 0 ? _ref3 : payload.title) !== null && _ref2 !== void 0 ? _ref2 : payload.stage) !== null && _ref !== void 0 ? _ref : "");
      events.push({
        type: type,
        text: text,
        conversationId: typeof payload.conversationId === "string" ? payload.conversationId : undefined,
        provider: typeof payload.provider === "string" ? payload.provider : undefined,
        model: typeof payload.model === "string" ? payload.model : undefined,
        usage: payload.usage && (0,_Users_gloriachan_Documents_fabushi_frontend_node_modules_pnpm_babel_runtime_7_29_7_node_modules_babel_runtime_helpers_esm_typeof_js__WEBPACK_IMPORTED_MODULE_1__["default"])(payload.usage) === "object" ? payload.usage : undefined,
        title: typeof payload.title === "string" ? payload.title : undefined,
        message: typeof payload.message === "string" ? payload.message : undefined,
        raw: payload
      });
    }
  } catch (err) {
    _iterator.e(err);
  } finally {
    _iterator.f();
  }
  return events;
}

/***/ }),

/***/ "../../packages/api-client/src/endpoints.ts":
/*!**************************************************!*\
  !*** ../../packages/api-client/src/endpoints.ts ***!
  \**************************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   API_BASE_URL: function() { return /* binding */ API_BASE_URL; }
/* harmony export */ });
/* unused harmony export endpoints */
var _process, _env$NEXT_PUBLIC_FABU;
var env = typeof process !== "undefined" ? process.env : (_process = globalThis.process) === null || _process === void 0 ? void 0 : _process.env;
var API_BASE_URL = (_env$NEXT_PUBLIC_FABU = env === null || env === void 0 ? void 0 : env.NEXT_PUBLIC_FABUSHI_API_BASE_URL) !== null && _env$NEXT_PUBLIC_FABU !== void 0 ? _env$NEXT_PUBLIC_FABU : "https://flutter.ombhrum.com";
var endpoints = {
  health: "/health",
  leaderboard: "/api/leaderboard",
  practiceLeaderboard: "/api/leaderboard/practice",
  login: "/api/auth/login",
  register: "/api/auth/register",
  sendVerificationCode: "/api/auth/send-verification-code",
  userInfo: "/api/auth/user-info",
  forumThreads: "/api/community/threads",
  forumThread: function forumThread(slug) {
    return "/api/community/thread/".concat(encodeURIComponent(slug));
  }
};

/***/ }),

/***/ "../../packages/api-client/src/index.ts":
/*!**********************************************!*\
  !*** ../../packages/api-client/src/index.ts ***!
  \**********************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   API_BASE_URL: function() { return /* reexport safe */ _endpoints__WEBPACK_IMPORTED_MODULE_2__.API_BASE_URL; },
/* harmony export */   dachengAiEndpoints: function() { return /* reexport safe */ _dacheng_ai__WEBPACK_IMPORTED_MODULE_1__.dachengAiEndpoints; },
/* harmony export */   getDachengAiApiBaseUrl: function() { return /* reexport safe */ _dacheng_ai__WEBPACK_IMPORTED_MODULE_1__.getDachengAiApiBaseUrl; }
/* harmony export */ });
/* harmony import */ var _client__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./client */ "../../packages/api-client/src/client.ts");
/* harmony import */ var _dacheng_ai__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./dacheng-ai */ "../../packages/api-client/src/dacheng-ai.ts");
/* harmony import */ var _endpoints__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./endpoints */ "../../packages/api-client/src/endpoints.ts");





/***/ }),

/***/ "../../packages/shared/src/app-experience.ts":
/*!***************************************************!*\
  !*** ../../packages/shared/src/app-experience.ts ***!
  \***************************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   aiQuickPrompts: function() { return /* binding */ aiQuickPrompts; }
/* harmony export */ });
/* unused harmony exports appExperienceStats, flutterDesignTokens, miniProgramFlutterParity, appModules, sutraLibrary, practicePlan, practiceSessionPresets, dharmaFeedItems, globalDharmaActions, leaderboardPreview, miniProgramTabs, miniProgramNativeLimitations */
var appExperienceStats = [{
  label: "今日共修",
  value: "12,086",
  unit: "人次"
}, {
  label: "全球发送",
  value: "8.42",
  unit: "TB"
}, {
  label: "在线国家",
  value: "64",
  unit: "个"
}, {
  label: "经文素材",
  value: "1,248",
  unit: "份"
}];
var flutterDesignTokens = {
  colors: {
    spaceDeepBlue: "#0b0e14",
    spaceBlue: "#1b263b",
    starlightWhite: "#e8eaf6",
    nebulaPurple: "#7b1fa2",
    nebulaPink: "#e91e63",
    cosmicGold: "#ffd700",
    glassBorder: "rgba(255, 255, 255, 0.15)",
    glassSurface: "rgba(255, 255, 255, 0.1)"
  },
  radius: {
    panel: 8,
    control: 8
  },
  sources: ["fabushi/lib/core/design_system/colors.dart", "fabushi/lib/core/design_system/app_theme.dart", "fabushi/lib/screens/main_navigation_screen.dart", "fabushi/lib/screens/globe_home_screen.dart", "fabushi/lib/screens/meditation_room_screen.dart", "fabushi/lib/screens/my_profile_screen.dart"]
};
var miniProgramFlutterParity = [{
  flutter: "GlobeHomeScreen",
  miniProgram: "pages/index/index",
  title: "全球法布施",
  reused: "品牌、全局统计、AI 快捷任务、全球发送信息架构与宇宙玻璃视觉 token",
  nativeScope: "微信原生 View/Text/Button/Input 复刻首页与发送入口"
}, {
  flutter: "SutraReaderScreen / VideoFeedViewFullTextReader",
  miniProgram: "pages/sutra/index",
  title: "经文续读",
  reused: "经文书架、进度、功德利益和 AI 问经入口",
  nativeScope: "微信原生列表、搜索和进度条"
}, {
  flutter: "MeditationRoomScreen",
  miniProgram: "pages/practice/index",
  title: "禅室修行",
  reused: "零摩擦开始修行、计时、念诵计数、回向和榜单入口",
  nativeScope: "微信原生计时器、计数器、本地草稿保存"
}, {
  flutter: "DachengAiService / SutraAIPage",
  miniProgram: "pages/ai/index",
  title: "大乘 AI",
  reused: "AI 网关、快捷提示词、资源搜索类型与请求协议",
  nativeScope: "微信原生表单和 HTTPS request"
}, {
  flutter: "MyProfileScreen",
  miniProgram: "pages/me/index",
  title: "我的",
  reused: "账号、修行记录、设置、支持入口的信息架构",
  nativeScope: "微信原生资料卡和服务列表"
}];
var appModules = [{
  id: "global-dharma",
  title: "全球法布施",
  shortTitle: "法布施",
  summary: "选择经文、音频、图片或发愿文，一键发送到全球节点。",
  action: "开始发送",
  tone: "cyan",
  screenshot: "/product/global-dharma.png"
}, {
  id: "flashcards",
  title: "背诵闪卡",
  shortTitle: "闪卡",
  summary: "参考 RemNote 的挖空卡、双向卡和间隔复习，把经文内容变成可背诵知识点。",
  action: "开始背诵",
  tone: "blue",
  screenshot: "/product/main-sutra.png"
}, {
  id: "sutra",
  title: "经文听诵",
  shortTitle: "经文",
  summary: "读经、听诵、拼音辅助和功德利益说明集中在一个阅读面板。",
  action: "进入经藏",
  tone: "gold",
  screenshot: "/product/main-sutra.png"
}, {
  id: "meditation",
  title: "禅室修行",
  shortTitle: "禅室",
  summary: "香、灯、经书和计时器组合成可持续的每日修行空间。",
  action: "开始禅修",
  tone: "green",
  screenshot: "/product/immersive-meditation.png"
}, {
  id: "faliu",
  title: "法流学习",
  shortTitle: "法流",
  summary: "短内容、全文阅读、收藏和问经入口服务轻量学习。",
  action: "浏览法流",
  tone: "rose",
  screenshot: "/product/group-practice.png"
}, {
  id: "leaderboard",
  title: "共修榜单",
  shortTitle: "榜单",
  summary: "看见同行者的法布施与禅修节奏，也保留个人边界。",
  action: "查看榜单",
  tone: "violet",
  screenshot: "/product/global-ranking.png"
}, {
  id: "ai",
  title: "大乘 AI",
  shortTitle: "AI",
  summary: "帮你查找可分享资源、整理经文摘要、生成发愿文和修行计划。",
  action: "问问 AI",
  tone: "blue",
  screenshot: "/product/global-donation.png"
}];
var sutraLibrary = [{
  title: "心经",
  category: "般若",
  minutes: 8,
  progress: 86,
  summary: "适合每日短时听诵，训练把注意力收回空性与慈悲。"
}, {
  title: "金刚经",
  category: "般若",
  minutes: 42,
  progress: 64,
  summary: "适合做阶段性精读，结合重点偈句与回向记录。"
}, {
  title: "地藏经",
  category: "大乘经典",
  minutes: 108,
  progress: 32,
  summary: "适合分品听诵，配合家庭、祖先和众生回向。"
}, {
  title: "楞严咒",
  category: "咒语",
  minutes: 24,
  progress: 51,
  summary: "适合做固定功课，跟随音频逐段熟悉发音节奏。"
}];
var practicePlan = [{
  title: "清晨定课",
  duration: "18 分钟",
  detail: "净手、发愿、心经一遍、静坐十分钟。"
}, {
  title: "午间听诵",
  duration: "12 分钟",
  detail: "跟随音频复习今日经文，记录一句最有触动的句子。"
}, {
  title: "夜间回向",
  duration: "9 分钟",
  detail: "整理当天法布施内容，回向给具体人群与一切众生。"
}];
var practiceSessionPresets = [{
  title: "心经",
  targetMinutes: 18,
  dedication: "回向给今日同行者与一切众生"
}, {
  title: "金刚经",
  targetMinutes: 42,
  dedication: "愿以读诵功德增长智慧与慈悲"
}, {
  title: "地藏经",
  targetMinutes: 54,
  dedication: "回向父母眷属、祖先与有缘众生"
}, {
  title: "楞严咒",
  targetMinutes: 24,
  dedication: "愿身心清明，护持正念"
}];
var dharmaFeedItems = [{
  title: "如何把一段经文整理成可分享资料",
  tag: "法布施",
  readTime: "4 分钟"
}, {
  title: "每日功课不稳定时，先保留一个最小动作",
  tag: "修行",
  readTime: "3 分钟"
}, {
  title: "共修关系里最重要的是清楚、温和与可持续",
  tag: "共修",
  readTime: "5 分钟"
}];
var aiQuickPrompts = ["帮我整理一段适合全球法布施的善法文字", "查找可公开分享的心经学习资源，并说明来源", "根据今天的状态安排一个 20 分钟修行计划", "把这段经文解释给初学者听，语气庄重简洁"];
var globalDharmaActions = [{
  label: "发送经文",
  detail: "选择公共领域经文，生成可分享资料"
}, {
  label: "AI 找资源",
  detail: "调用大乘 AI 网关检索可公开传播来源"
}, {
  label: "加入共修",
  detail: "选择一门功课，开始计时与念诵计数"
}];
var leaderboardPreview = [{
  name: "明净",
  region: "中国",
  value: "328 分钟",
  rank: 1
}, {
  name: "善行",
  region: "新加坡",
  value: "271 分钟",
  rank: 2
}, {
  name: "慧灯",
  region: "加拿大",
  value: "236 分钟",
  rank: 3
}, {
  name: "净愿",
  region: "马来西亚",
  value: "219 分钟",
  rank: 4
}];
var miniProgramTabs = [{
  pagePath: "pages/index/index",
  text: "首页",
  icon: "home"
}, {
  pagePath: "pages/sutra/index",
  text: "经文",
  icon: "sutra"
}, {
  pagePath: "pages/practice/index",
  text: "修行",
  icon: "practice"
}, {
  pagePath: "pages/ai/index",
  text: "AI",
  icon: "ai"
}, {
  pagePath: "pages/me/index",
  text: "我的",
  icon: "me"
}];
var miniProgramNativeLimitations = ["微信小程序不运行 Flutter Engine，不能直接加载 Flutter Widget tree。", "当前 Flutter App 的 Firebase、3D、音视频、文件、支付、离线模型等插件不能在微信原生运行时无损复用。", "小程序侧复用 Flutter 的信息架构、设计 token、领域数据和 HTTPS API，UI 用微信原生组件等价实现。"];

/***/ }),

/***/ "../../packages/shared/src/brand.ts":
/*!******************************************!*\
  !*** ../../packages/shared/src/brand.ts ***!
  \******************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* unused harmony export brand */
var brand = {
  name: "法布施",
  englishName: "大乘",
  tagline: "经文、禅修、法流与全球法布施，一处安静开始。",
  mission: "用现代产品体验承接佛法传播、修行记录、禅修冥想与同行连接。",
  domain: "fabushi.ombhrum.com"
};

/***/ }),

/***/ "../../packages/shared/src/chat-experience.ts":
/*!****************************************************!*\
  !*** ../../packages/shared/src/chat-experience.ts ***!
  \****************************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* unused harmony exports dachengBrand, dachengToolEntries, dachengHeroChips, dachengQuickPrompts, globalDharmaRegions, remnoteInspiredFlashcardPrinciples, createDachengId, splitDachengSentences, makeDachengFlashcards, nextDachengFlashcardDue, buildGlobalDharmaChecklist, globalDharmaStartMessage, dachengHomeExperience */
var dachengBrand = {
  name: "大乘",
  productName: "法布施",
  greeting: "Hi,朋友",
  tagline: "大乘，让复杂变简单",
  inputPlaceholder: "问一问大乘",
  defaultText: "愿以此功德，普及于一切，我等与众生，皆共成佛道。"
};
var dachengToolEntries = [{
  id: "global-dharma",
  title: "全球法布施",
  shortTitle: "法布施",
  description: "把善法文字整理成全球地区清单，Web 和小程序只展示首页需要的轻量流程。",
  action: "生成清单",
  icon: "🌍"
}, {
  id: "flashcards",
  title: "背诵闪卡",
  shortTitle: "闪卡",
  description: "参考 RemNote 的挖空卡、双向卡和间隔复习，直接从输入内容制卡。",
  action: "制作闪卡",
  icon: "🪷"
}];
var dachengHeroChips = [{
  id: "who",
  label: "你是谁",
  icon: "✦",
  prompt: "你是谁？请用一句话介绍大乘能帮我做什么。"
}, {
  id: "global-dharma",
  label: "全球法布施",
  icon: "🌍",
  prompt: "帮我整理一段适合全球法布施的善法文字。",
  tool: "global-dharma"
}, {
  id: "flashcards",
  label: "背诵闪卡",
  icon: "🪷",
  prompt: "把这段经文拆成适合背诵的闪卡。",
  tool: "flashcards"
}, {
  id: "simple",
  label: "原来是这样",
  icon: "💡",
  prompt: "请用庄重、简洁、容易记住的方式解释这段佛法内容。"
}, {
  id: "today",
  label: "我今天修什么？",
  icon: "🧭",
  prompt: "根据今天的状态安排一个 20 分钟修行计划。"
}];
var dachengQuickPrompts = dachengHeroChips.map(function (item) {
  return item.prompt;
});
var globalDharmaRegions = ["中国", "新加坡", "日本", "印度", "澳大利亚", "德国", "法国", "英国", "美国", "加拿大", "巴西", "南非"];
var remnoteInspiredFlashcardPrinciples = ["一个卡片只考一个最小记忆点。", "优先做挖空卡，再补充正反向问答卡。", "按 Again、Hard、Good、Easy 四档安排下次复习。", "保留上下文，避免只背孤立词句。"];
function createDachengId() {
  var prefix = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : "dc";
  return "".concat(prefix, "-").concat(Date.now(), "-").concat(Math.random().toString(36).slice(2, 8));
}
function splitDachengSentences(text) {
  return text.split(/[。！？!?；;\n]+/).map(function (item) {
    return item.trim();
  }).filter(function (item) {
    return item.length > 5;
  }).slice(0, 6);
}
function makeDachengFlashcards(text) {
  var createId = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : createDachengId;
  return splitDachengSentences(text).flatMap(function (sentence) {
    var plain = sentence.replace(/[，、：,\s]/g, "");
    var start = Math.max(0, Math.floor(plain.length / 3) - 1);
    var term = plain.slice(start, Math.min(plain.length, start + 4));
    var fallbackEnd = Math.min(sentence.length, 14);
    var cloze = term && sentence.includes(term) ? sentence.replace(term, "〔……〕") : "".concat(sentence.slice(0, 8), "\u3014\u2026\u2026\u3015").concat(sentence.slice(fallbackEnd));
    return [{
      id: createId(),
      front: cloze,
      back: sentence,
      kind: "挖空",
      reviews: 0,
      due: "现在"
    }, {
      id: createId(),
      front: "\u8BF7\u80CC\u8BF5\u5E76\u89E3\u91CA\uFF1A".concat(sentence.slice(0, 18), "\u2026"),
      back: sentence,
      kind: "双向",
      reviews: 0,
      due: "现在"
    }];
  });
}
function nextDachengFlashcardDue(rating) {
  if (rating === "Again") return "10 分钟后";
  if (rating === "Hard") return "明天";
  if (rating === "Good") return "3 天后";
  return "7 天后";
}
function buildGlobalDharmaChecklist(text) {
  var summary = text.trim() || dachengBrand.defaultText;
  return globalDharmaRegions.map(function (region, index) {
    return {
      id: "region-".concat(index),
      region: region,
      label: "".concat(region, " \xB7 \u5DF2\u751F\u6210\u9996\u9875\u8F7B\u91CF\u6E05\u5355"),
      text: summary
    };
  });
}
function globalDharmaStartMessage() {
  var platform = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : "web";
  var label = platform === "mini" ? "小程序版" : platform === "static" ? "极速 Web 版" : "Web 版";
  return "\u5F00\u59CB\u5168\u7403\u6CD5\u5E03\u65BD\uFF1A".concat(label, "\u53EA\u4FDD\u7559\u9996\u9875\u8F7B\u91CF\u6D41\u7A0B\uFF0C\u4E0D\u52A0\u8F7D App \u4E13\u5C5E\u9875\u9762\u3002");
}
var dachengHomeExperience = {
  brand: dachengBrand,
  heroChips: dachengHeroChips,
  toolEntries: dachengToolEntries,
  regions: globalDharmaRegions,
  flashcardPrinciples: remnoteInspiredFlashcardPrinciples
};

/***/ }),

/***/ "../../packages/shared/src/copy.ts":
/*!*****************************************!*\
  !*** ../../packages/shared/src/copy.ts ***!
  \*****************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* unused harmony exports homeHighlights, homeUseCases, primaryNavigation, faqItems, contactChannels, betaApplicationTracks */
var homeHighlights = [{
  title: "经文听诵",
  description: "读经、听诵、离线素材与进度记录，日常修行更顺手。"
}, {
  title: "全球法布施",
  description: "把善意发送到世界各地，用 3D 地球看见传播路径。"
}, {
  title: "禅修与法流",
  description: "禅室、冥想、短视频法流与修行记录，轻量进入完整体验。"
}];
var homeUseCases = [{
  audience: "日常修行",
  title: "打开就能读经、听诵、记录。",
  description: "适合想把修行放进每天固定节奏的人。"
}, {
  audience: "佛法传播",
  title: "用可视化方式看见法布施。",
  description: "适合想分享经文、参与全球发送或关注功德回向的人。"
}, {
  audience: "共修同行",
  title: "看见记录，也保留边界。",
  description: "适合想参与共修、保持个人记录和控制公开范围的人。"
}, {
  audience: "内测体验",
  title: "快速找到对应下载入口。",
  description: "适合想试用 Android Beta 或 iOS TestFlight 的用户。"
}];
var primaryNavigation = [{
  label: "首页",
  href: "/"
}, {
  label: "下载",
  href: "/download"
}, {
  label: "申请测试",
  href: "/apply"
}, {
  label: "常见问题",
  href: "/faq"
}, {
  label: "联系",
  href: "/contact"
}];
var faqItems = [{
  question: "大乘 是什么？",
  answer: "大乘 是一款佛教修行应用，提供经文听诵、全球法布施、禅修冥想、法流视频和修行记录。"
}, {
  question: "现在可以下载吗？",
  answer: "Android Beta 和 iOS TestFlight 会在下载页显示当前状态。入口开放时可以直接点击；未开放时可以先申请测试。"
}, {
  question: "Android 和 iOS 入口有什么区别？",
  answer: "Android Beta 通常更快同步版本；iOS 通过 TestFlight 加入内测；正式版会在人工确认后公开。"
}, {
  question: "适合哪些人先试用？",
  answer: "适合需要日常读经听诵、禅修记录、佛法内容传播，或愿意参与早期体验并反馈问题的人。"
}, {
  question: "测试申请需要提供什么？",
  answer: "请写明平台、设备型号、常用邮箱和最想体验的功能。合作沟通可直接说明方向和联系方式。"
}, {
  question: "下载或安装遇到问题怎么办？",
  answer: "可以通过 support@ombhrum.com 联系支持。请附上平台、系统版本、错误截图或发生步骤。"
}];
var contactChannels = [{
  label: "支持邮箱",
  value: "support@ombhrum.com",
  href: "mailto:support@ombhrum.com",
  note: "下载问题、测试申请、账号支持和合作沟通。"
}, {
  label: "官网域名",
  value: "fabushi.ombhrum.com",
  href: "https://fabushi.ombhrum.com",
  note: "长期公开入口，适合转发下载页和常见问题。"
}, {
  label: "公开项目",
  value: "fabushi.ombhrum.com",
  href: "https://fabushi.ombhrum.com",
  note: "查看项目进展、功能更新和最新发布动态。"
}];
var betaApplicationTracks = [{
  name: "iOS TestFlight",
  summary: "适合想体验完整主应用，并愿意接受内测节奏的用户。",
  checklist: ["附上你的常用邮箱", "说明你更关注内容传播、修行记录还是社交发现", "写明你是否愿意反馈 bug 和体验问题"],
  ctaLabel: "申请 iOS 内测",
  ctaHref: "mailto:support@ombhrum.com?subject=Fabushi%20iOS%20Beta%20Application&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E7%94%B3%E8%AF%B7%20Fabushi%20iOS%20%E5%86%85%E6%B5%8B%E3%80%82%0A%0A%E5%B8%B8%E7%94%A8%E9%82%AE%E7%AE%B1%EF%BC%9A%0A%E5%85%B3%E6%B3%A8%E7%82%B9%EF%BC%9A%0A%E6%98%AF%E5%90%A6%E6%84%BF%E6%84%8F%E5%8F%8D%E9%A6%88%E9%97%AE%E9%A2%98%EF%BC%9A%0A"
}, {
  name: "Android Beta",
  summary: "适合想尽快体验新版本、全球法布施和法流内容的人。",
  checklist: ["附上你的常用邮箱", "说明你的 Android 机型或系统版本", "写明你最想优先体验哪个模块"],
  ctaLabel: "申请 Android 内测",
  ctaHref: "mailto:support@ombhrum.com?subject=Fabushi%20Android%20Beta%20Application&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E7%94%B3%E8%AF%B7%20Fabushi%20Android%20%E5%86%85%E6%B5%8B%E3%80%82%0A%0A%E5%B8%B8%E7%94%A8%E9%82%AE%E7%AE%B1%EF%BC%9A%0AAndroid%20%E6%9C%BA%E5%9E%8B%2F%E7%B3%BB%E7%BB%9F%E7%89%88%E6%9C%AC%EF%BC%9A%0A%E6%9C%80%E6%83%B3%E4%BD%93%E9%AA%8C%E7%9A%84%E6%A8%A1%E5%9D%97%EF%BC%9A%0A"
}, {
  name: "合作与渠道",
  summary: "适合讨论传播合作、内容共建、渠道联动或活动承接。",
  checklist: ["附上你的姓名或组织名称", "说明合作方向或渠道资源", "留下可回联的邮箱或微信说明"],
  ctaLabel: "发起合作沟通",
  ctaHref: "mailto:support@ombhrum.com?subject=Fabushi%20Partnership%20Inquiry&body=%E4%BD%A0%E5%A5%BD%EF%BC%8C%E6%88%91%E6%83%B3%E5%92%8C%20Fabushi%20%E8%AE%A8%E8%AE%BA%E5%90%88%E4%BD%9C%E3%80%82%0A%0A%E5%A7%93%E5%90%8D%E6%88%96%E7%BB%84%E7%BB%87%E5%90%8D%E7%A7%B0%EF%BC%9A%0A%E5%90%88%E4%BD%9C%E6%96%B9%E5%90%91%EF%BC%9A%0A%E5%9B%9E%E8%81%94%E6%96%B9%E5%BC%8F%EF%BC%9A%0A"
}];

/***/ }),

/***/ "../../packages/shared/src/index.ts":
/*!******************************************!*\
  !*** ../../packages/shared/src/index.ts ***!
  \******************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   aiQuickPrompts: function() { return /* reexport safe */ _app_experience__WEBPACK_IMPORTED_MODULE_2__.aiQuickPrompts; }
/* harmony export */ });
/* harmony import */ var _brand__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./brand */ "../../packages/shared/src/brand.ts");
/* harmony import */ var _copy__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./copy */ "../../packages/shared/src/copy.ts");
/* harmony import */ var _app_experience__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./app-experience */ "../../packages/shared/src/app-experience.ts");
/* harmony import */ var _chat_experience__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./chat-experience */ "../../packages/shared/src/chat-experience.ts");






/***/ }),

/***/ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/asyncToGenerator.js":
/*!******************************************************************************************************************!*\
  !*** ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/asyncToGenerator.js ***!
  \******************************************************************************************************************/
/***/ (function(__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": function() { return /* binding */ _asyncToGenerator; }
/* harmony export */ });
function asyncGeneratorStep(n, t, e, r, o, a, c) {
  try {
    var i = n[a](c),
      u = i.value;
  } catch (n) {
    return void e(n);
  }
  i.done ? t(u) : Promise.resolve(u).then(r, o);
}
function _asyncToGenerator(n) {
  return function () {
    var t = this,
      e = arguments;
    return new Promise(function (r, o) {
      var a = n.apply(t, e);
      function _next(n) {
        asyncGeneratorStep(a, r, o, _next, _throw, "next", n);
      }
      function _throw(n) {
        asyncGeneratorStep(a, r, o, _next, _throw, "throw", n);
      }
      _next(void 0);
    });
  };
}


/***/ }),

/***/ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/objectSpread2.js":
/*!***************************************************************************************************************!*\
  !*** ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/objectSpread2.js ***!
  \***************************************************************************************************************/
/***/ (function(__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": function() { return /* binding */ _objectSpread2; }
/* harmony export */ });
/* harmony import */ var _defineProperty_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./defineProperty.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/defineProperty.js");

function ownKeys(e, r) {
  var t = Object.keys(e);
  if (Object.getOwnPropertySymbols) {
    var o = Object.getOwnPropertySymbols(e);
    r && (o = o.filter(function (r) {
      return Object.getOwnPropertyDescriptor(e, r).enumerable;
    })), t.push.apply(t, o);
  }
  return t;
}
function _objectSpread2(e) {
  for (var r = 1; r < arguments.length; r++) {
    var t = null != arguments[r] ? arguments[r] : {};
    r % 2 ? ownKeys(Object(t), !0).forEach(function (r) {
      (0,_defineProperty_js__WEBPACK_IMPORTED_MODULE_0__["default"])(e, r, t[r]);
    }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) {
      Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r));
    });
  }
  return e;
}


/***/ }),

/***/ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regenerator.js":
/*!*************************************************************************************************************!*\
  !*** ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regenerator.js ***!
  \*************************************************************************************************************/
/***/ (function(__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": function() { return /* binding */ _regenerator; }
/* harmony export */ });
/* harmony import */ var _regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./regeneratorDefine.js */ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regeneratorDefine.js");

function _regenerator() {
  /*! regenerator-runtime -- Copyright (c) 2014-present, Facebook, Inc. -- license (MIT): https://github.com/babel/babel/blob/main/packages/babel-helpers/LICENSE */
  var e,
    t,
    r = "function" == typeof Symbol ? Symbol : {},
    n = r.iterator || "@@iterator",
    o = r.toStringTag || "@@toStringTag";
  function i(r, n, o, i) {
    var c = n && n.prototype instanceof Generator ? n : Generator,
      u = Object.create(c.prototype);
    return (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(u, "_invoke", function (r, n, o) {
      var i,
        c,
        u,
        f = 0,
        p = o || [],
        y = !1,
        G = {
          p: 0,
          n: 0,
          v: e,
          a: d,
          f: d.bind(e, 4),
          d: function d(t, r) {
            return i = t, c = 0, u = e, G.n = r, a;
          }
        };
      function d(r, n) {
        for (c = r, u = n, t = 0; !y && f && !o && t < p.length; t++) {
          var o,
            i = p[t],
            d = G.p,
            l = i[2];
          r > 3 ? (o = l === n) && (u = i[(c = i[4]) ? 5 : (c = 3, 3)], i[4] = i[5] = e) : i[0] <= d && ((o = r < 2 && d < i[1]) ? (c = 0, G.v = n, G.n = i[1]) : d < l && (o = r < 3 || i[0] > n || n > l) && (i[4] = r, i[5] = n, G.n = l, c = 0));
        }
        if (o || r > 1) return a;
        throw y = !0, n;
      }
      return function (o, p, l) {
        if (f > 1) throw TypeError("Generator is already running");
        for (y && 1 === p && d(p, l), c = p, u = l; (t = c < 2 ? e : u) || !y;) {
          i || (c ? c < 3 ? (c > 1 && (G.n = -1), d(c, u)) : G.n = u : G.v = u);
          try {
            if (f = 2, i) {
              if (c || (o = "next"), t = i[o]) {
                if (!(t = t.call(i, u))) throw TypeError("iterator result is not an object");
                if (!t.done) return t;
                u = t.value, c < 2 && (c = 0);
              } else 1 === c && (t = i["return"]) && t.call(i), c < 2 && (u = TypeError("The iterator does not provide a '" + o + "' method"), c = 1);
              i = e;
            } else if ((t = (y = G.n < 0) ? u : r.call(n, G)) !== a) break;
          } catch (t) {
            i = e, c = 1, u = t;
          } finally {
            f = 1;
          }
        }
        return {
          value: t,
          done: y
        };
      };
    }(r, o, i), !0), u;
  }
  var a = {};
  function Generator() {}
  function GeneratorFunction() {}
  function GeneratorFunctionPrototype() {}
  t = Object.getPrototypeOf;
  var c = [][n] ? t(t([][n]())) : ((0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(t = {}, n, function () {
      return this;
    }), t),
    u = GeneratorFunctionPrototype.prototype = Generator.prototype = Object.create(c);
  function f(e) {
    return Object.setPrototypeOf ? Object.setPrototypeOf(e, GeneratorFunctionPrototype) : (e.__proto__ = GeneratorFunctionPrototype, (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(e, o, "GeneratorFunction")), e.prototype = Object.create(u), e;
  }
  return GeneratorFunction.prototype = GeneratorFunctionPrototype, (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(u, "constructor", GeneratorFunctionPrototype), (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(GeneratorFunctionPrototype, "constructor", GeneratorFunction), GeneratorFunction.displayName = "GeneratorFunction", (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(GeneratorFunctionPrototype, o, "GeneratorFunction"), (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(u), (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(u, o, "Generator"), (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(u, n, function () {
    return this;
  }), (0,_regeneratorDefine_js__WEBPACK_IMPORTED_MODULE_0__["default"])(u, "toString", function () {
    return "[object Generator]";
  }), (_regenerator = function _regenerator() {
    return {
      w: i,
      m: f
    };
  })();
}


/***/ }),

/***/ "../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regeneratorDefine.js":
/*!*******************************************************************************************************************!*\
  !*** ../../node_modules/.pnpm/@babel+runtime@7.29.7/node_modules/@babel/runtime/helpers/esm/regeneratorDefine.js ***!
  \*******************************************************************************************************************/
/***/ (function(__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) {

/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": function() { return /* binding */ _regeneratorDefine; }
/* harmony export */ });
function _regeneratorDefine(e, r, n, t) {
  var i = Object.defineProperty;
  try {
    i({}, "", {});
  } catch (e) {
    i = 0;
  }
  _regeneratorDefine = function regeneratorDefine(e, r, n, t) {
    function o(r, n) {
      _regeneratorDefine(e, r, function (e) {
        return this._invoke(r, n, e);
      });
    }
    r ? i ? i(e, r, {
      value: n,
      enumerable: !t,
      configurable: !t,
      writable: !t
    }) : e[r] = n : (o("next", 0), o("throw", 1), o("return", 2));
  }, _regeneratorDefine(e, r, n, t);
}


/***/ })

},
/******/ function(__webpack_require__) { // webpackRuntimeModules
/******/ var __webpack_exec__ = function(moduleId) { return __webpack_require__(__webpack_require__.s = moduleId); }
/******/ __webpack_require__.O(0, ["taro","vendors"], function() { return __webpack_exec__("./src/pages/index/index.tsx"); });
/******/ var __webpack_exports__ = __webpack_require__.O();
/******/ }
]);
//# sourceMappingURL=index.js.map
const WEB_URL = 'https://flutter.ombhrum.com/';

Page({
  data: {
    url: WEB_URL
  },
  onShareAppMessage() {
    return {
      title: '灵光',
      path: '/pages/web/index'
    };
  }
});

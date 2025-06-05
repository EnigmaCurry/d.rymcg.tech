/* main.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.main = ysy.main || {};
ysy.initGantt = function () {
  $("p.nodata").remove();
  ysy.data.loader.init();
  ysy.data.loader.load();
  ysy.data.storage.init();
  if (!ysy.settings.easyRedmine) {
    moment.locale(ysy.settings.language || "en");
  }
  ysy.view.start();
  //ysy.main.start();
};

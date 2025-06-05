/* storage.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.data = ysy.data || {};
ysy.data.storage = ysy.data.storage || {};
$.extend(ysy.data.storage, {
  _scope: "easy-gantt-",
  zoomKey: "zoom",
  init: function () {

    // ZOOM saving
    ysy.settings.zoom.register(function () {
      this.saveSessionData(this.zoomKey, ysy.settings.zoom.zoom);
    }, this);

  },
  getSavedZoom: function () {
    return this.getSessionData(this.zoomKey);
  },
  saveCookie: function (key, value) {
    $.cookie(this._scope + key, value, {expires: 3650, path: '/'});
  },
  getCookie: function (key) {
    return $.cookie(this._scope + key);
  },
  saveSessionData: function (key, value) {
    window.sessionStorage.setItem(this._scope + key, value);
  },
  getSessionData: function (key) {
    return window.sessionStorage.getItem(this._scope + key);
  },
  savePersistentData: function (key, value) {
    window.localStorage.setItem(this._scope + key, value);
  },
  getPersistentData: function (key) {
    return window.localStorage.getItem(this._scope + key);
  }
});

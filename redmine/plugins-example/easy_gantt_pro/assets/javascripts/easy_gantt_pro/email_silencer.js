window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.silencer = ysy.pro.silencer || {};
$.extend(ysy.pro.silencer, {
  setting: null,
  name: "Silencer",
  patch: function () {
    ysy.proManager.register("beforeSaveIssue", this.updateSaveData);
    this.setting = new ysy.data.Data();
    this.setting.init({name: this.name, turnedOn: false});
    var $checkBox = $(' <input id="checkbox_silencer" class="gantt-menu-checkbox" type="checkbox" >'
        + '<label for="checkbox_silencer">' + ysy.settings.labels.silencer.label_disable_notifications + '</label>');
    $("#button_year_zoom").after($checkBox);
    ysy.view.AllButtons.prototype.extendees.silencer = {
      widget: ysy.view.CheckBox,
      bind: function () {
        this.model = ysy.pro.silencer.setting;
      },
      func: function () {
        this.model.turnedOn = this.$target.is(":checked");
        this.model._fireChanges(this, "click");
      },
      isOn: function () {
        return this.model.turnedOn;
      }
    };
  },
  updateSaveData: function (data) {
    if (ysy.pro.silencer.setting.turnedOn)
      data.easy_gantt_suppress_notification = true;
  }
});
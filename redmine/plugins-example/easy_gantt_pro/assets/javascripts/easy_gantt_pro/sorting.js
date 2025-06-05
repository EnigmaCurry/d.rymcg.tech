window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.sorting = $.extend(ysy.pro.sorting, {
  name:"Sorter",
  patch: function () {
    var setting = new ysy.data.Data();
    setting.init({_name: "Sorting", sortBy: null});
    ysy.settings.sorting = setting;

    gantt.attachEvent("onGanttReady", $.proxy(this.bindClick, gantt));

  },
  columnCompares: {
    start_date: function (a, b) {
      return (a._start_date || a.start_date) - (b._start_date || b.start_date);
    },
    end_date: function (a, b) {
      return (a._end_date || a.end_date) - (b._end_date || b.end_date);
    },
    subject: function (a, b) {
      return a.text.localeCompare(b.text);
    }
  },
  getCompareFunction: function (column, sort) {
    var sortCoefficient = sort ? -1 : 1;
    if (this.columnCompares[column]) {
      var func = this.columnCompares[column];
      return function (a, b) {
        var result = func(a, b);
        if (result === 0) result = a.order - b.order;
        return sortCoefficient * result;
      }
    }
    return function (a, b) {
      var result = ysy.pro.sorting.columnsValidation(a, b);
      if (result === undefined) {
        result = a.columns[column].toString().localeCompare(b.columns[column].toString());
        if (result === 0) result = a.order - b.order;
      }
      return sortCoefficient * result;
    }
  },
  columnsValidation: function (a, b) {
    if (!a.columns) {
      if (!b.columns) return a.order - b.order;
      return -1
    }
    if (!b.columns) return 1;
    return undefined;
  },
  bindClick: function () {
    this._click.gantt_grid_head_cell = dhtmlx.bind(function (e, id, trg) {
      var column = trg.getAttribute("column_id");

      if (!this.callEvent("onGridHeaderClick", [column, e]))
        return;

      if (this._sort && this._sort.direction && this._sort.name == column) {
        var sort = this._sort.direction;
        if (sort === "desc") {
          // remove sorting by column (on third click)
          this._sort = null;
          this.sort();
          return;
        }
        // invert sort direction
        sort = (sort == "desc") ? "asc" : "desc";
      } else {
        sort = "asc";
      }
      var sortFunction = ysy.pro.sorting.getCompareFunction(column, sort == "desc");
      this._sort = {
        name: column,
        criteria: sortFunction,
        direction: sort
      };
      this.sort(sortFunction);
    }, this);
  }
});
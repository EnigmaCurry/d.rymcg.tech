/* bars.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};

ysy.view.bars = ysy.view.bars || {};
$.extend(ysy.view.bars, {
  _dateCache: {}, // for faster parsing YYYY-MM-DD to moment
  _rendererStack: {},

  registerRenderer: function (entity, renderer) {
    if (this._rendererStack[entity] === undefined) {
      this._rendererStack[entity] = [];
    }
    var renderers = this._rendererStack[entity];
    var found = false;
    for (var i = 0; i < renderers.length; i++) {
      if (renderers[i] === renderer) found = true;
    }
    if (found) return;
    renderers.push(renderer);
    this.reconstructRenderer(entity);
  },
  removeRenderer: function (entity, renderer) {
    var renderers = this._rendererStack[entity];
    if (!renderers) return;
    for (var i = 0; i < renderers.length; i++) {
      if (renderers[i] === renderer) {
        renderers.splice(i, 1);
        this.reconstructRenderer(entity);
        return;
      }
    }
  },
  reconstructRenderer: function (entity) {
    var renderers = this._rendererStack[entity];
    if (renderers.length === 0) {
      gantt.config.type_renderers[entity] = gantt._task_default_render;
      return;
    }
    gantt.config.type_renderers[entity] = function (task) {
      var i = renderers.length - 1;
      var nextRenderer = function () {
        if (i < 0) return gantt._task_default_render;
        return renderers[i--];
      };
      return nextRenderer().call(this, task, nextRenderer);
    }
  },

  getFromDateCache: function (allodate) {
    var alloMoment = this._dateCache[allodate];
    if (alloMoment === undefined) {
      alloMoment = moment(allodate);
      this._dateCache[allodate] = alloMoment;
    }
    return alloMoment;
  },
  insertCanvas:function (canvas,rootDiv) {
    var taskLeftElements = rootDiv.getElementsByClassName("task_left");
    if (taskLeftElements.length === 0) {
      rootDiv.appendChild(canvas);
    } else {
      rootDiv.insertBefore(canvas, taskLeftElements[0]);
    }
  },
  canvasListBuilder: function () {
    return {
      __proto__: this.canvasListPrototype
    };
    //return canvasList;
  },
  canvasListPrototype: {
    limit: 8170,
    build: function (task, gantt, start_date, end_date) {
      // initialization
      this.canvases = [];
      this.contexts = [];
      this.starts = [];
      this.gantt = gantt;
      this.isAssignee = task.type === "assignee";
      this.el = null;
      this.height = this.isAssignee ? gantt.config.row_height : gantt._tasks.bar_height;
      this.columnWidth = gantt._tasks.col_width;

      var startX = gantt.posFromDate(start_date || task.start_date);
      var endX = gantt.posFromDate(end_date || task.end_date);
      //var fullWidth = gantt._get_task_width(task);
      var fullWidth = endX - startX;
      this.startX = startX;
      this.fullWidth = fullWidth;
      var config = gantt._tasks;

      if (fullWidth < this.limit) {
        this.el = this.createCanvas(fullWidth);
        this.starts.push(startX);
        this.staticPack = {
          ctx: this.contexts[0],
          canvas: this.el,
          start: startX,
          end: startX + fullWidth
        };
      } else {
        this.el = document.createElement("div");
        var lefts = config.left;
        for (var i = 0; i < lefts.length; i++) {
          if (lefts[i] >= startX) break;
        }
        var partX = startX;
        for (; i < lefts.length; i++) {
          if (lefts[i] > fullWidth + startX) break;
          if (lefts[i] >= partX + this.limit) {
            var canvas = this.createCanvas(lefts[i - 1] - partX);
            this.el.appendChild(canvas);
            this.starts.push(partX);
            partX = lefts[i - 1];
          }
        }
        canvas = this.createCanvas(startX + fullWidth - partX);
        this.el.appendChild(canvas);
        this.starts.push(partX);

      }
      this.el.className += " gantt-task-bar-line";
      if (this.isAssignee) {
        var y = this.gantt.getTaskTop(task.id);
        this.el.style.left = startX + "px";
        this.el.style.top = y + "px";
      }
    },
    createCanvas: function (width) {
      var el = document.createElement("canvas");
      //var height = this.gantt._tasks.bar_height;
      width = Math.round(width);
      el.style.width = width + "px";
      el.width = width;
      el.height = this.height - 1;
      el.className = "gantt-task-bar-canvas";
      this.canvases.push(el);
      var ctx = el.getContext("2d");
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      this.contexts.push(ctx);
      return el;
    },
    getElement: function () {
      return this.el;
    },
    inRange: function (date) {
      var pos = gantt.posFromDateCached(date);
      return pos + this.columnWidth >= this.startX && pos < this.fullWidth + this.startX;
    },
    fillTextAt: function (date, text, styles) {
      var x = gantt.posFromDateCached(date);
      var pack = this.getPack(x);
      var posPack = this.getPosPack(x, pack);
      var ctx = pack.ctx;
      if (styles.backgroundColor) {
        this.fillRectAtPosPack(posPack, pack, styles.backgroundColor);
      }
      ctx.font = styles.fontStyle;
      ctx.fillStyle = styles.textColor;
      text = this.fitTextInWidth(text, posPack.width, ctx);
      ctx.fillText(text, posPack.middle, this.height / 2 + 1);
    },
    fillFormattedTextAt: function (date, formatter, value, styles) {
      var x = gantt.posFromDateCached(date);
      var pack = this.getPack(x);
      var posPack = this.getPosPack(x, pack);
      var ctx = pack.ctx;
      if (styles.backgroundColor) {
        this.fillRectAtPosPack(posPack, pack, styles.backgroundColor, styles.shrink);
      }
      ctx.font = styles.fontStyle;
      ctx.fillStyle = styles.textColor;
      var text = formatter(value, posPack.width);
      text = this.fitTextInWidth(text, posPack.width, ctx);
      ctx.fillText(text, posPack.middle, this.height / 2 + 1);
    },
    fillTwoTextAt: function (date, textUpper, textBottom, styles) {
      var x = gantt.posFromDateCached(date);
      var pack = this.getPack(x);
      var posPack = this.getPosPack(x, pack);
      var ctx = pack.ctx;
      if (styles.backgroundColor) {
        this.fillRectAtPosPack(posPack, pack, styles.backgroundColor, styles.shrink);
      }
      var bottomLine = this.height / 2 + 1;
      ctx.fillStyle = styles.textColor;
      if (textUpper) {
        ctx.font = styles.fontStyle.replace("12px", "9px");
        bottomLine = bottomLine * 13.0 / 10;
        textUpper = this.fitTextInWidth(textUpper, posPack.width, ctx);
        ctx.fillText(textUpper, posPack.middle, this.height * 3 / 12);
      }
      if (textBottom) {
        ctx.font = styles.fontStyle;
        // ctx.fillStyle = styles.textColor;
        textBottom = this.fitTextInWidth(textBottom, posPack.width, ctx);
        ctx.fillText(textBottom, posPack.middle, bottomLine);
      }
    },
    fillRectAtPosPack: function (posPack, pack, fillColor, shrink) {
      pack.ctx.fillStyle = fillColor;
      if (shrink) {
        pack.ctx.fillRect(posPack.start + 1, 1, posPack.width - 3, this.height - 3);
      } else {
        pack.ctx.fillRect(posPack.start, 0, posPack.width, this.height);
      }
    },
    roundTo1: function (number) {
      if (number === undefined) return "";
      var modulated = number % 1;
      if (modulated < 0) {
        modulated += 1;
      }
      if (modulated < this.MARGIN || modulated > (1 - this.MARGIN)) {
        return number.toFixed();
      }
      return number.toFixed(1);
    },
    fitTextInWidth: function (text, width, ctx) {
      width -= 2;
      if (text.length * 7.2 < width) return text;
      ctx.font = ctx.font.replace("12px", "9px");
      if (text.length * 5.3 < width) return text;
      var splitPos = Math.floor(width / 5.3 - 1);
      return text.substring(0, splitPos) + "#";
    },
    getPosPack: function (x, pack) {
      var start, end, width = this.columnWidth;
      if (!pack) return null;
      start = x - pack.start;
      if (x < pack.start || x > pack.end - width) {
        end = start + width + Math.min(0, pack.end - width - x);
        start = Math.max(start, 0);
        return {
          start: start,
          end: end,
          middle: Math.floor((start + end) / 2),
          width: end - start
        };
      } else {
        return {
          start: start,
          end: start + width,
          middle: Math.floor(start + width / 2),
          width: width
        };
      }
    },
    getPack: function (pos) {
      if (this.staticPack) return this.staticPack;
      //var pos = gantt.posFromDateCached(date);
      // var min = this.startX;
      var mid = pos + this.columnWidth / 2;
      // if (pos + width < min) return null;
      // if (pos >= this.fullWidth + min) return null;

      for (var i = 1; i < this.starts.length; i++) {
        if (this.starts[i] > mid) break;
      }
      if (i >= this.starts.length) {
        i = this.starts.length;
        var end = this.startX + this.fullWidth;
      } else {
        end = this.starts[i];
      }

      return {
        ctx: this.contexts[i - 1],
        canvas: this.canvases[i - 1],
        start: this.starts[i - 1],
        end: end
      };
    }
  }
});

/* history.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.history = ysy.history || {};
$.extend(ysy.history, {
  _name: "History",
  _inbrack: 0,
  stack: [],
  _binded: false,
  add: function (diff, ctx) {
    this.stack.push({diff: diff, ctx: ctx});
    this._fireChanges(this, "add");
    this._bind();
  },
  revert: function (who) {
    var first = true;
    if (this.stack.length === 0) return;
    while (this._inbrack || first) {
      first = false;
      var rev = this.stack.pop();
      if (!rev) return;
      if (typeof rev === "string") {
        if (rev === "close") {
          this._inbrack++;
          continue;
        } else if (rev === "open") {
          this._inbrack--;
          break;
        }
      }
      this._revertOne(rev);
    }
    //console.log("Revert by "+(typeof rev.diff));
    if (this.stack.length === 0) {
      this._unbind();
    }
    this._fireChanges(who, "revert");
  },
  _revertOne: function (rev) {
    if (typeof rev.diff === "array") {
      rev.ctx.array = rev.diff;
      rev.ctx._fireChanges(this, "revert");
    } else if (typeof rev.diff === "function") {
      $.proxy(rev.diff, rev.ctx)();
      rev.ctx._fireChanges(this, "revert");
    } else {
      //rev.ctx.set(rev.diff,true);
      $.extend(rev.ctx, rev.diff);
      rev.ctx._fireChanges(this, "revert");
    }

  },
  clear: function (who) {
    if (this.stack.length > 0) {
      this._unbind();
    }
    this.stack = [];
    this._inbrack = 0;
    this._fireChanges(who, "clear");
  },
  openBrack: function () {
    if (this._inbrack) {

    } else {
      this.stack.push("open");
    }
    this._inbrack++;
  },
  closeBrack: function () {
    if (this._inbrack === 0) {
      ysy.log.error("History bracket is not opened");
    }
    if (this._inbrack === 1) {
      if (this.stack[this.stack.length - 1] === "open") {
        this.stack.pop();
      } else {
        this.stack.push("close");
      }
    }
    this._inbrack--;
  },
  _bind: function () {
    if (this._binded)return;
    $(window).bind('beforeunload', function (e) {
      var message = "Some changes are not saved!";
      e.returnValue = message;
      return message;
    });
  },
  _unbind: function () {
    $(window).unbind('beforeunload');
    this._binded = false;
  },
  _onChange: [],
  register: function (func, ctx) {
    this._onChange.push({func: func, ctx: ctx});
  },
  inBracket: function () {
    return this._inbrack > 0
  },
  isEmpty: function () {
    return !this.stack.length;
  },
  _fireChanges: function (who, reason) {
    if (who) {
      var rest = "";
      if (reason) {
        rest = " because of " + reason;
      }
      ysy.log.log("* " + who._name + " ordered repaint on " + this._name + "" + rest);

    }
    if (this._onChange.length > 0) {
      ysy.log.log("- " + this._name + " onChange fired for " + this._onChange.length + " widgets");
    } else {
      ysy.log.log("- no changes for " + this._name);
    }
    for (var i = 0; i < this._onChange.length; i++) {
      var ctx = this._onChange[i].ctx;
      if (!ctx || ctx.deleted) {
        this._onChange.splice(i, 1);
        continue;
      }
      //this.onChangeNew[i].func();
      ysy.log.log("-- changes to " + ctx.name + " widget");
      //console.log(ctx);
      $.proxy(this._onChange[i].func, ctx)();
    }
  }
});
/* collapsor.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.collapsor = ysy.pro.collapsor || {};
$.extend(ysy.pro.collapsor, {
  templateHtml: null,
  patch: function () {
    var $sourceDiv = $("#close_all_something");
    this.templateHtml = '<div id="gantt_grid_collapsors" class="gantt-grid-header-collapse-buttons">' + $sourceDiv.html() + '</div>';
    $sourceDiv.remove();

  },
  extendees: [
    {
      id: "close_all_parent_issues",

      bind: function () {
        this.model = ysy.data.limits;
      },
      func: function () {
        var openings = this.model.openings;
        var issues = ysy.data.issues.getArray();
        this.model.parentsIssuesClosed = !this.model.parentsIssuesClosed;
        if (this.model.parentsIssuesClosed) {
          for (var i = 0; i < issues.length; i++) {
            openings[issues[i].getID()] = false;
          }
        } else {
          for (i = 0; i < issues.length; i++) {
            delete openings[issues[i].getID()];
          }
        }
        this.model._fireChanges(this, "close_all_parent_issues");
        return false;
      },
      isOn: function () {
        return this.model.parentsIssuesClosed;
      }
    },
    {
      id: "close_all_milestones",
      bind: function () {
        this.model = ysy.data.limits;
      },
      func: function () {
        var openings = this.model.openings;
        var milestones = ysy.data.milestones.getArray();
        this.model.milestonesClosed = !this.model.milestonesClosed;
        if (this.model.milestonesClosed) {
          for (var i = 0; i < milestones.length; i++) {
            openings[milestones[i].getID()] = false;
          }
        } else {
          for (i = 0; i < milestones.length; i++) {
            delete openings[milestones[i].getID()];
          }
        }
        this.model._fireChanges(this, "close_all_milestones");
        return false;
      },
      isOn: function () {
        return this.model.milestonesClosed;
      }
    },
    {
      id: "close_all_projects",
      bind: function () {
        this.model = ysy.data.limits;
      },
      func: function () {
        var openings = this.model.openings;
        var projects = ysy.data.projects.getArray();
        this.model.projectsClosed = !this.model.projectsClosed;
        if (this.model.projectsClosed) {
          for (var i = 0; i < projects.length; i++) {
            if (projects[i].id === ysy.settings.projectID) continue;
            delete openings[projects[i].getID()];
            // gantt.close(projects[i].getID());
          }
        } else {
          for (i = 0; i < projects.length; i++) {
            if (!projects[i].needLoad) {
              openings[projects[i].getID()] = true;
            }
            //gantt.open(projects[i].getID());
          }
        }
        this.model._fireChanges(this, "close_all_projects");
        return false;
      },
      isOn: function () {
        return this.model.projectsClosed;
      }
    }
  ]
});
//#############################################################################################
ysy.view.Collapsors = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.Collapsors, {
  name: "CollapsorsWidget",
  _postInit:function(){
    this.model = ysy.settings.resource;
    this.model.unregister(this);
    this.model.register(this.requestRepaint,this);
  },
  _updateChildren: function () {
    for (var i = 0; i < this.children.length; i++) {
      this.children.destroy();
    }
    this.children = [];
    var collapsorClass = ysy.pro.collapsor;
    for (i = 0; i < collapsorClass.extendees.length; i++) {
      var extendee = collapsorClass.extendees[i];
      var button = new ysy.view.Button();
      $.extend(button, extendee);
      button.init();
      this.children.push(button);
    }
  },
  repaint: function (force) {
    var $target = $("#gantt_grid_collapsors");
    if(this.repaintRequested){
      if(this.model.open){
        $target.hide();
        return;
      }else{
        $target.show();
      }
      $target.off("click").on("click",function(){
        return false;
      });
    }
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      child.$target = this.getChildTarget(child);
      if(!child.$target.length) continue;
      child.repaint(force || this.repaintRequested);
    }
    this.repaintRequested=false;
  },
  getChildTarget: function (child) {
    return this.$target.find("#" + child.elementPrefix + child.id);
  }
});


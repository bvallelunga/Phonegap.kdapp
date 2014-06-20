/* Compiled by kdc on Fri Jun 20 2014 22:59:46 GMT+0000 (UTC) */
(function() {
/* KDAPP STARTS */
/* BLOCK STARTS: /home/bvallelunga/Applications/Phonegap.kdapp/index.coffee */
var EditorView, FinderView, LogWatcher, PhonegapController, PhonegapMainView, TerminalView, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

LogWatcher = (function(_super) {
  __extends(LogWatcher, _super);

  function LogWatcher() {
    _ref = LogWatcher.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  LogWatcher.prototype.fileAdded = function(change) {
    var name, percentage, status, _ref1;
    name = change.file.name;
    _ref1 = name.split('-'), percentage = _ref1[0], status = _ref1[1];
    return this.emit("UpdateProgress", percentage, status);
  };

  return LogWatcher;

})(FSWatcher);

TerminalView = (function(_super) {
  __extends(TerminalView, _super);

  function TerminalView(options, data) {
    if (options == null) {
      options = {};
    }
    TerminalView.__super__.constructor.call(this, options, data);
    this.addSubView(this.terminal = new TerminalPane);
  }

  return TerminalView;

})(KDView);

FinderView = (function(_super) {
  __extends(FinderView, _super);

  function FinderView(options, data) {
    var vmController,
      _this = this;
    if (options == null) {
      options = {};
    }
    FinderView.__super__.constructor.call(this, options, data);
    vmController = KD.getSingleton("vmController");
    vmController.fetchDefaultVm(function(err, vm) {
      if (err) {
        warn(err);
      }
      _this.finderController = new NFinderController({
        hideDotFiles: true
      });
      _this.finderController.isNodesHiddenFor = function() {
        return true;
      };
      _this.addSubView(_this.finderController.getView());
      _this.finderController.mountVm(vm);
      return _this.finderController.on("FileNeedsToBeOpened", _this.bound('openFile'));
    });
  }

  FinderView.prototype.openFile = function(file) {
    var _this = this;
    return file.fetchContents(function(err, contents) {
      var JSEditor, panel;
      if (!err) {
        panel = _this.getDelegate();
        JSEditor = panel.panesByName.JSEditor;
        JSEditor.openFile(file, contents);
        return _this.emit("switchMode", 'develop');
      } else {
        return new KDNotificationView({
          type: "mini",
          cssClass: "error",
          title: "Sorry, couldn't fetch file content, please try again...",
          duration: 3000
        });
      }
    });
  };

  FinderView.prototype.loadFile = function(path) {
    var file, kite;
    file = FSHelper.createFileFromPath(path);
    kite = KD.getSingleton('vmController').getKiteByVmName(file.vmName);
    if (!kite) {
      return callback({
        message: "VM not found"
      });
    }
    return this.openFile(file);
  };

  return FinderView;

})(KDView);

EditorView = (function(_super) {
  __extends(EditorView, _super);

  function EditorView(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = "editor-pane";
    EditorView.__super__.constructor.call(this, options, data);
    this.storage = KD.singletons.localStorageController.storage("PhoneGap");
    this.createEditorInstance();
  }

  EditorView.prototype.createEditorInstance = function() {
    var content, file, path,
      _this = this;
    path = "localfile:/index.html";
    file = FSHelper.createFileFromPath(path);
    content = this.getOptions().content;
    this.ace = new Ace({
      delegate: this,
      enableShortcuts: false
    }, file);
    return this.ace.once("ace.ready", function() {
      if (content) {
        _this.ace.editor.setValue(content);
      }
      return _this.prepareEditor();
    });
  };

  EditorView.prototype.closeFile = function() {
    return this.openFile(FSHelper.createFileFromPath('localfile:/index.html'));
  };

  EditorView.prototype.loadFile = function(path, callback) {
    var file, kite,
      _this = this;
    if (callback == null) {
      callback = noop;
    }
    file = FSHelper.createFileFromPath(path);
    kite = KD.getSingleton('vmController').getKiteByVmName(file.vmName);
    if (!kite) {
      return callback({
        message: "VM not found"
      });
    }
    return file.fetchContents(function(err, content) {
      if (err) {
        return callback(err);
      }
      file.path = path;
      _this.openFile(file, content);
      return KD.utils.defer(function() {
        return callback(null, {
          file: file,
          content: content
        });
      });
    });
  };

  EditorView.prototype.loadLastOpenFile = function() {
    var path,
      _this = this;
    path = this.storage.getAt(this._lastFileKey);
    if (!path) {
      return;
    }
    return this.loadFile(path, function(err) {
      if (err != null) {
        return _this.storage.unsetKey(_this._lastFileKey);
      } else {
        return _this.emit("RecentFileLoaded");
      }
    });
  };

  EditorView.prototype.openFile = function(file, content) {
    var validPath;
    validPath = file instanceof FSFile && !/^localfile\:/.test(file.path);
    if (validPath) {
      this.storage.setValue(this._lastFileKey, file.path);
    } else {
      this.storage.unsetKey(this._lastFileKey);
    }
    this.ace.editor.setValue(content, -1);
    this.ace.setSyntax();
    return this.setData(file);
  };

  EditorView.prototype.viewAppended = function() {
    this.findAndReplaceView = new AceFindAndReplaceView({
      delegate: this
    });
    this.findAndReplaceView.hide();
    this.addSubView(this.ace);
    return this.addSubView(this.findAndReplaceView);
  };

  EditorView.prototype.getValue = function() {
    return this.ace.editor.getSession().getValue();
  };

  EditorView.prototype.requestSave = function() {
    var content, file;
    file = this.getData();
    if (!file) {
      return;
    }
    content = this.getValue();
    return file.save(content, function(err) {
      if (err) {
        return warn(err);
      }
    });
  };

  EditorView.prototype.requestSaveAll = function() {
    return log("save all");
  };

  EditorView.prototype.prepareEditor = function() {
    var _this = this;
    this.ace.addKeyCombo("save", "Ctrl-S", this.bound("requestSave"));
    this.ace.addKeyCombo("saveAll", "Ctrl-Shift-S", this.bound("requestSaveAll"));
    this.ace.addKeyCombo("find", "Ctrl-F", this.ace.lazyBound("showFindReplaceView", false));
    this.ace.addKeyCombo("replace", "Ctrl-Shift-F", this.ace.lazyBound("showFindReplaceView", true));
    this.ace.addKeyCombo("preview", "Ctrl-Shift-P", function() {
      return _this.getDelegate().preview();
    });
    this.ace.addKeyCombo("fullscreen", "Ctrl-Enter", function() {
      return _this.getDelegate().toggleFullscreen();
    });
    this.ace.addKeyCombo("gotoLine", "Ctrl-G", this.ace.bound("showGotoLine"));
    this.ace.addKeyCombo("settings", "Ctrl-,", noop);
    return this.on("PaneResized", _.debounce(function() {
      return _this.ace.editor.resize();
    }), 400);
  };

  return EditorView;

})(KDView);

PhonegapMainView = (function(_super) {
  var domain, installerScript, outPath, phoneGapBin, png, user;

  __extends(PhonegapMainView, _super);

  user = KD.nick();

  domain = "" + user + ".kd.io";

  outPath = "/tmp/_PhoneGapinstaller.out";

  phoneGapBin = "/usr/bin/phonegap";

  installerScript = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/installer.sh";

  png = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/phonegap.png";

  function PhonegapMainView(options, data) {
    if (options == null) {
      options = {};
    }
    options.cssClass = 'phonegap main-view';
    PhonegapMainView.__super__.constructor.call(this, options, data);
  }

  PhonegapMainView.prototype.viewAppended = function() {
    var _this = this;
    return KD.singletons.appManager.require('Terminal', function() {
      _this.addSubView(_this.workContainer = new KDCustomHTMLView({
        tagName: "div",
        cssClass: "work-container"
      }));
      _this.workContainer.addSubView(new KDCustomHTMLView({
        tagName: "iframe",
        cssClass: "iframe-view",
        attributes: {
          src: ""
        }
      }));
      _this.workContainer.addSubView(_this.workEditor = new Workspace({
        title: "Text Editor",
        name: "TextEditor",
        cssClass: "editor-view",
        panels: [
          {
            title: "Text Editor",
            layout: {
              direction: "vertical",
              sizes: ["180px", "100%"],
              splitName: "BaseSplit",
              views: [
                {
                  type: "custom",
                  name: "finder",
                  paneClass: FinderView
                }, {
                  type: "custom",
                  name: "JSEditor",
                  paneClass: EditorView
                }
              ]
            }
          }
        ]
      }));
      _this.workContainer.addSubView(_this.workTerminal = new Workspace({
        title: "Terminal",
        name: "Terminal",
        cssClass: "terminal-view",
        panels: [
          {
            title: "Terminal",
            layout: {
              direction: "vertical",
              sizes: ["100%", null],
              splitName: "BaseSplit",
              views: [
                {
                  type: "custom",
                  name: "Terminal",
                  paneClass: TerminalView
                }
              ]
            }
          }
        ]
      }));
      _this.workEditor.once("viewAppended", function() {
        var JSEditor;
        _this.emit('ready');
        JSEditor = _this.workEditor.activePanel.panesByName.JSEditor;
        return JSEditor.ace.once('ace.ready', function() {
          return JSEditor.ace.editor.on("change", _.debounce(_this.lazyBound('emit', 'previewApp', false), 500));
        });
      });
      _this.addSubView(_this.installContainer = new KDCustomHTMLView({
        tagName: "div",
        cssClass: "install-container hidden"
      }));
      _this.installContainer.addSubView(new KDHeaderView({
        title: "PhoneGap Installer",
        type: "big"
      }));
      _this.installContainer.addSubView(_this.installToggle = new KDToggleButton({
        cssClass: 'toggle-button',
        style: "clean-gray",
        defaultState: "Show details",
        states: [
          {
            title: "Show details",
            callback: function(cb) {
              _this.installTerminal.setClass('in');
              _this.installToggle.setClass('toggle');
              _this.installTerminal.webterm.setKeyView();
              return typeof cb === "function" ? cb() : void 0;
            }
          }, {
            title: "Hide details",
            callback: function(cb) {
              _this.installTerminal.unsetClass('in');
              _this.installToggle.unsetClass('toggle');
              return typeof cb === "function" ? cb() : void 0;
            }
          }
        ]
      }));
      _this.installContainer.addSubView(new KDCustomHTMLView({
        tagName: 'img',
        cssClass: 'logo',
        attributes: {
          src: png
        }
      }));
      _this.installContainer.addSubView(_this.installProgress = new KDProgressBarView({
        initial: 100,
        title: "Checking installation..."
      }));
      _this.installContainer.addSubView(_this.installTerminal = new TerminalPane({
        cssClass: 'terminal'
      }));
      _this.installContainer.addSubView(_this.installButton = new KDButtonView({
        title: "Install PhoneGap",
        cssClass: 'main-button solid',
        loader: {
          color: "#FFFFFF",
          diameter: 12
        },
        callback: function() {
          return _this.installCallback();
        }
      }));
      _this.installContainer.addSubView(new KDCustomHTMLView({
        cssClass: "phonegap-help",
        partial: " \n<p><strong>NOTE:</strong> To test PhoneGap apps on Koding please install the Ripple Emulator <a href=\"https://chrome.google.com/webstore/detail/ripple-emulator-beta/geelfhphabnejjhdalkjhgipohgpdnoc\">chrome extension</a>. After installing the chome extension, please enable it when you are given the phonegap launch url.<img src=\"https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/screenshot.png\"/></p>\n<p>Easily create apps using the web technologies you know and love: <strong>HTML</strong>, <strong>CSS</strong>, and <strong>JavaScript</strong>.</p>\n<p>PhoneGap is a free and open source framework that allows you to create mobile apps using standardized web APIs for the platforms you care about. For more information checkout phonegaps <a href=\"http://phonegap.com/\">website</a>.</p>"
      }));
      _this.watcher = new LogWatcher;
      return _this.checkState();
    });
  };

  PhonegapMainView.prototype.startWork = function() {
    var Terminal;
    Terminal = this.workTerminal.panels[0].panesByName.Terminal;
    return Terminal.terminal.runCommand("cd ~/PhoneGap;");
  };

  PhonegapMainView.prototype.startDemo = function() {
    var Terminal;
    Terminal = this.workTerminal.panels[0].panesByName.Terminal;
    return Terminal.terminal.runCommand("ccd ~/PhoneGap/hello; phonegap serve;");
  };

  PhonegapMainView.prototype.checkState = function() {
    var vmc,
      _this = this;
    vmc = KD.getSingleton('vmController');
    this.installButton.showLoader();
    return FSHelper.exists(phoneGapBin, vmc.defaultVmName, function(err, PhoneGap) {
      if (err) {
        warn(err);
      }
      if (!PhoneGap) {
        _this.installProgress.updateBar(100, '%', "PhoneGap is not installed.");
        return _this.switchState('install');
      } else {
        return _this.switchState('ready');
      }
    });
  };

  PhonegapMainView.prototype.switchState = function(state) {
    if (state == null) {
      state = 'run';
    }
    this.watcher.off('UpdateProgress');
    switch (state) {
      case 'install':
        this.installContainer.show();
        this.workContainer.hide();
        return this.installButton.hideLoader();
      case 'ready':
        this.installContainer.hide();
        this.workContainer.show();
        return this.startWork();
      case 'demo':
        this.installContainer.hide();
        this.workContainer.show();
        return this.startDemo();
    }
  };

  PhonegapMainView.prototype.stopCallback = function() {
    this._lastRequest = 'stop';
    return this.checkState();
  };

  PhonegapMainView.prototype.installCallback = function() {
    var session, tmpOutPath, vmc,
      _this = this;
    this.watcher.on('UpdateProgress', function(percentage, status) {
      _this.installProgress.updateBar(percentage, '%', status);
      if (percentage === "100") {
        _this.installButton.hideLoader();
        _this.installTerminal.unsetClass('in');
        _this.installToggle.setState('Show details');
        _this.installToggle.unsetClass('toggle');
        return _this.switchState('demo');
      } else if (percentage === "80") {
        _this.installTerminal.unsetClass('in');
        _this.installToggle.setState('Show details');
        return _this.installToggle.unsetClass('toggle');
      } else if (percentage === "40") {
        _this.installTerminal.setClass('in');
        _this.installTerminal.webterm.setKeyView();
        _this.installToggle.setState('Hide details');
        return _this.installToggle.setClass('toggle');
      } else if (percentage === "0") {
        _this.installTerminal.unsetClass('in');
        _this.installToggle.setState('Show details');
        return _this.installToggle.unsetClass('toggle');
      }
    });
    session = (Math.random() + 1).toString(36).substring(7);
    tmpOutPath = "" + outPath + "/" + session;
    vmc = KD.getSingleton('vmController');
    return vmc.run("rm -rf " + outPath + "; mkdir -p " + tmpOutPath, function() {
      _this.watcher.stopWatching();
      _this.watcher.path = tmpOutPath;
      _this.watcher.watch();
      return _this.installTerminal.runCommand("curl --silent " + installerScript + " | bash -s " + session + " " + user);
    });
  };

  return PhonegapMainView;

})(KDView);

PhonegapController = (function(_super) {
  __extends(PhonegapController, _super);

  function PhonegapController(options, data) {
    if (options == null) {
      options = {};
    }
    options.view = new PhonegapMainView;
    options.appInfo = {
      name: "Phonegap",
      type: "application"
    };
    PhonegapController.__super__.constructor.call(this, options, data);
  }

  return PhonegapController;

})(AppController);

(function() {
  var view;
  if (typeof appView !== "undefined" && appView !== null) {
    view = new PhonegapMainView;
    return appView.addSubView(view);
  } else {
    return KD.registerAppClass(PhonegapController, {
      name: "PhoneGap",
      routes: {
        "/:name?/Phonegap": null,
        "/:name?/bvallelunga/Apps/Phonegap": null
      },
      dockPath: "/bvallelunga/Apps/Phonegap",
      behavior: "application"
    });
  }
})();

/* KDAPP ENDS */
}).call();
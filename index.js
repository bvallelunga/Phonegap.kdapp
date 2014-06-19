/* Compiled by kdc on Thu Jun 19 2014 23:43:03 GMT+0000 (UTC) */
(function() {
/* KDAPP STARTS */
/* BLOCK STARTS: /home/bvallelunga/Applications/Phonegap.kdapp/index.coffee */
var LogWatcher, PhonegapController, PhonegapMainView, _ref,
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
      _this.addSubView(_this.header = new KDHeaderView({
        title: "PhoneGap Installer",
        type: "big"
      }));
      _this.addSubView(_this.toggle = new KDToggleButton({
        cssClass: 'toggle-button',
        style: "clean-gray",
        defaultState: "Show details",
        states: [
          {
            title: "Show details",
            callback: function(cb) {
              _this.terminal.setClass('in');
              _this.toggle.setClass('toggle');
              _this.terminal.webterm.setKeyView();
              return typeof cb === "function" ? cb() : void 0;
            }
          }, {
            title: "Hide details",
            callback: function(cb) {
              _this.terminal.unsetClass('in');
              _this.toggle.unsetClass('toggle');
              return typeof cb === "function" ? cb() : void 0;
            }
          }
        ]
      }));
      _this.addSubView(_this.logo = new KDCustomHTMLView({
        tagName: 'img',
        cssClass: 'logo',
        attributes: {
          src: png
        }
      }));
      _this.watcher = new LogWatcher;
      _this.addSubView(_this.progress = new KDProgressBarView({
        initial: 100,
        title: "Checking installation..."
      }));
      _this.addSubView(_this.terminal = new TerminalPane({
        cssClass: 'terminal'
      }));
      _this.addSubView(_this.button = new KDButtonView({
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
      _this.addSubView(_this.link = new KDCustomHTMLView({
        cssClass: 'hidden running-link'
      }));
      _this.link.startServer = function() {
        var port;
        port = Math.round(Math.random() * (4000 - 3000) + 3000);
        this.parent.terminal.runCommand("cd ~/PhoneGap/HelloWorld; /usr/bin/phonegap serve --port " + port);
        this.updatePartial("Click here to launch PhoneGap: <a target='_blank' href='http://" + domain + ":" + port + "'>http://" + domain + ":" + port + "</a>");
        return this.show();
      };
      _this.addSubView(_this.content = new KDCustomHTMLView({
        cssClass: "phonegap-help",
        partial: "   \n<p><br>Easily create apps using the web technologies you know and love: <strong>HTML</strong>, <strong>CSS</strong>, and <strong>JavaScript</strong></p>.\n<p>PhoneGap is a free and open source framework that allows you to create mobile apps using standardized web APIs for the platforms you care about. For more information checkout phonegaps <a href=\"http://phonegap.com/\">website</a>.</p>"
      }));
      return _this.checkState();
    });
  };

  PhonegapMainView.prototype.checkState = function() {
    var vmc,
      _this = this;
    vmc = KD.getSingleton('vmController');
    this.button.showLoader();
    return FSHelper.exists(phoneGapBin, vmc.defaultVmName, function(err, PhoneGap) {
      if (err) {
        warn(err);
      }
      if (!PhoneGap) {
        _this.link.hide();
        _this.progress.updateBar(100, '%', "PhoneGap is not installed.");
        return _this.switchState('install');
      } else {
        _this.progress.updateBar(100, '%', "PhoneGap is installed.");
        return _this.switchState('ready');
      }
    });
  };

  PhonegapMainView.prototype.switchState = function(state) {
    var style, title,
      _this = this;
    if (state == null) {
      state = 'run';
    }
    this.watcher.off('UpdateProgress');
    switch (state) {
      case 'install':
        title = "Install PhoneGap";
        style = '';
        this.button.setCallback(function() {
          return _this.installCallback();
        });
        break;
      case 'ready':
        title = 'Run PhoneGap';
        style = '';
        this.button.setCallback(function() {
          return _this.switchState('run');
        });
        break;
      case 'run':
        this.link.startServer();
        this.button.hide();
    }
    this.button.unsetClass('red green');
    this.button.setClass(style);
    this.button.setTitle(title || "Run PhoneGap");
    return this.button.hideLoader();
  };

  PhonegapMainView.prototype.stopCallback = function() {
    this._lastRequest = 'stop';
    this.button.hide();
    return this.checkState();
  };

  PhonegapMainView.prototype.installCallback = function() {
    var session, tmpOutPath, vmc,
      _this = this;
    this.watcher.on('UpdateProgress', function(percentage, status) {
      _this.progress.updateBar(percentage, '%', status);
      if (percentage === "100") {
        _this.button.hideLoader();
        _this.toggle.setState('Show details');
        _this.terminal.unsetClass('in');
        _this.toggle.unsetClass('toggle');
        return _this.switchState('ready');
      } else if (percentage === "80") {
        _this.toggle.setState('Hide details');
        _this.terminal.setClass('in');
        return _this.toggle.setClass('toggle');
      } else if (percentage === "40") {
        _this.toggle.setState('Show details');
        _this.terminal.setClass('in');
        _this.toggle.setClass('toggle');
        return _this.terminal.webterm.setKeyView();
      } else if (percentage === "0") {
        _this.toggle.setState('Hide details');
        _this.terminal.setClass('in');
        return _this.toggle.setClass('toggle');
      }
    });
    session = (Math.random() + 1).toString(36).substring(7);
    tmpOutPath = "" + outPath + "/" + session;
    vmc = KD.getSingleton('vmController');
    return vmc.run("rm -rf " + outPath + "; mkdir -p " + tmpOutPath, function() {
      _this.watcher.stopWatching();
      _this.watcher.path = tmpOutPath;
      _this.watcher.watch();
      return _this.terminal.runCommand("curl --silent " + installerScript + " | bash -s " + session + " " + user);
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
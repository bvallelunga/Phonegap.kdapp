class LogWatcher extends FSWatcher

  fileAdded:(change)->
    {name} = change.file
    [percentage, status] = name.split '-'
    
    @emit "UpdateProgress", percentage, status


class PhonegapMainView extends KDView
  
  user            = KD.nick()
  domain          = "#{user}.kd.io"
  outPath         = "/tmp/_PhoneGapinstaller.out"
  phoneGapBin     = "/usr/bin/phonegap"
  installerScript = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/installer.sh"
  png             = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/phonegap.png"

  constructor:(options = {}, data)->
    options.cssClass = 'phonegap main-view'
    super options, data

  viewAppended:->
    
    KD.singletons.appManager.require 'Terminal', =>
    
      @addSubView @header = new KDHeaderView
        title         : "PhoneGap Installer"
        type          : "big"

      @addSubView @toggle = new KDToggleButton
        cssClass        : 'toggle-button'
        style           : "clean-gray" 
        defaultState    : "Show details"
        states          : [
          title         : "Show details"
          callback      : (cb)=>
            @terminal.setClass 'in'
            @toggle.setClass 'toggle'
            @terminal.webterm.setKeyView()
            cb?()
        ,
          title         : "Hide details"
          callback      : (cb)=>
            @terminal.unsetClass 'in'
            @toggle.unsetClass 'toggle'
            cb?()
        ]

      @addSubView @logo = new KDCustomHTMLView
        tagName       : 'img'
        cssClass      : 'logo'
        attributes    :
          src         : png

      @watcher = new LogWatcher

      @addSubView @progress = new KDProgressBarView
        initial       : 100
        title         : "Checking installation..."

      @addSubView @terminal = new TerminalPane
        cssClass      : 'terminal'

      @addSubView @button = new KDButtonView
        title         : "Install PhoneGap"
        cssClass      : 'main-button solid'
        loader        :
          color       : "#FFFFFF"
          diameter    : 12
        callback      : => @installCallback()

      @addSubView @link = new KDCustomHTMLView
        cssClass : 'hidden running-link'
        
      @link.startServer = ()->
        port = Math.round  Math.random() * (4000 - 3000) + 3000
        @parent.terminal.runCommand "cd ~/PhoneGap/hello; phonegap serve --port #{port}"
        @updatePartial "Click here to launch PhoneGap: <a target='_blank' href='http://#{domain}:#{port}'>http://#{domain}:#{port}</a>"
        @show()

      @addSubView @content = new KDCustomHTMLView
        cssClass : "phonegap-help"
        partial  : """ 
          <p><strong>NOTE:</strong> To test PhoneGap apps on Koding please install the Ripple Emulator <a href="https://chrome.google.com/webstore/detail/ripple-emulator-beta/geelfhphabnejjhdalkjhgipohgpdnoc">chrome extension</a>. After installing the chome extension, please enable it when you are given the phonegap launch url.<img src="https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/screenshot.png"/></p>
          <p>Easily create apps using the web technologies you know and love: <strong>HTML</strong>, <strong>CSS</strong>, and <strong>JavaScript</strong>.</p>
          <p>PhoneGap is a free and open source framework that allows you to create mobile apps using standardized web APIs for the platforms you care about. For more information checkout phonegaps <a href="http://phonegap.com/">website</a>.</p>
        """

      @checkState()
  
  checkState:->

    vmc = KD.getSingleton 'vmController'

    @button.showLoader()

    FSHelper.exists phoneGapBin, vmc.defaultVmName, (err, PhoneGap)=>
      warn err if err
      
      unless PhoneGap
        @link.hide()
        @progress.updateBar 100, '%', "PhoneGap is not installed."
        @switchState 'install'
      else
        @progress.updateBar 100, '%', "PhoneGap is installed."
        @switchState 'ready'
        
  switchState:(state = 'run')->

    @watcher.off 'UpdateProgress'

    switch state
      when 'install'
        title = "Install PhoneGap"
        style = ''
        @button.setCallback => @installCallback()
      when 'ready'
        title = 'Run PhoneGap'
        style = ''
        @button.setCallback => @switchState 'run'
      when 'run'
        @link.startServer()
        @button.hide()

    @button.unsetClass 'red green'
    @button.setClass style
    @button.setTitle title or "Run PhoneGap"
    @button.hideLoader()
    
    
  stopCallback:->
    @_lastRequest = 'stop'
    @button.hide()
    @checkState()

  installCallback:->
    @watcher.on 'UpdateProgress', (percentage, status)=>
      @progress.updateBar percentage, '%', status
      if percentage is "100"
        @button.hideLoader()
        @toggle.setState 'Show details'
        @terminal.unsetClass 'in'
        @toggle.unsetClass 'toggle'
        @switchState 'ready'
      
      else if percentage is "80"
        @toggle.setState 'Hide details'
        @terminal.setClass 'in'
        @toggle.setClass 'toggle'
        
      else if percentage is "40"
        @toggle.setState 'Show details'
        @terminal.setClass 'in'
        @toggle.setClass 'toggle'
        @terminal.webterm.setKeyView()
      
      else if percentage is "0"
        @toggle.setState 'Hide details'
        @terminal.setClass 'in'
        @toggle.setClass 'toggle'

    session = (Math.random() + 1).toString(36).substring 7
    tmpOutPath = "#{outPath}/#{session}"
    vmc = KD.getSingleton 'vmController'
    vmc.run "rm -rf #{outPath}; mkdir -p #{tmpOutPath}", =>
      @watcher.stopWatching()
      @watcher.path = tmpOutPath
      @watcher.watch()
      @terminal.runCommand "curl --silent #{installerScript} | bash -s #{session} #{user}"

class PhonegapController extends AppController

  constructor:(options = {}, data)->
    options.view    = new PhonegapMainView
    options.appInfo =
      name : "Phonegap"
      type : "application"

    super options, data

do ->

  # In live mode you can add your App view to window's appView
  if appView?

    view = new PhonegapMainView
    appView.addSubView view

  else

    KD.registerAppClass PhonegapController,
      name     : "PhoneGap"
      routes   :
        "/:name?/Phonegap" : null
        "/:name?/bvallelunga/Apps/Phonegap" : null
      dockPath : "/bvallelunga/Apps/Phonegap"
      behavior : "application"
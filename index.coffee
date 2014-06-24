class LogWatcher extends FSWatcher

  fileAdded: (change)->
    {name} = change.file
    [percentage, status] = name.split '-'
    
    @emit "UpdateProgress", percentage, status
    
class TerminalView extends KDView

  constructor: (options = {}, data) ->
    super options, data     
    
    @addSubView @terminal = new TerminalPane

class FinderView extends KDView

  constructor: (options = {}, data) ->
    super options, data

    vmController = KD.getSingleton "vmController"
    vmController.fetchDefaultVm (err, vm) =>
      
      warn err  if err
      
      @finderController = new NFinderController {
        hideDotFiles : yes
      }
      
      # Temporary fix, until its fixed in upstream ~ GG
      @finderController.isNodesHiddenFor = -> yes
      
      @addSubView @finderController.getView()
      @finderController.mountVm vm
      
      @finderController.on "FileNeedsToBeOpened", @bound 'openFile'

  openFile: (file) ->
    file.fetchContents (err, contents) =>
      unless err
        
        panel = @getDelegate()
        {JSEditor} = panel.panesByName
        
        JSEditor.openFile file, contents
        @emit "switchMode", 'develop'
        
      else
        
        new KDNotificationView
          type     : "mini"
          cssClass : "error"
          title    : "Sorry, couldn't fetch file content, please try again..."
          duration : 3000

  loadFile: (path)->
    file = FSHelper.createFileFromPath path
    kite = KD.getSingleton('vmController').getKiteByVmName file.vmName
    return  callback {message: "VM not found"}  unless kite

    @openFile file    

class EditorView extends KDView

  constructor:(options = {}, data)->
    options.cssClass = "editor-pane"
    super options, data

    @storage = KD.singletons.localStorageController.storage "PhoneGap"
    @createEditorInstance()

  createEditorInstance:->
    path      = "localfile:/index.html"
    file      = FSHelper.createFileFromPath path
    {content} = @getOptions()

    @ace      = new Ace
      delegate        : this
      enableShortcuts : no
    , file

    @ace.once "ace.ready", =>
      if content then @ace.editor.setValue content
      @prepareEditor()

  closeFile:->
    @openFile FSHelper.createFileFromPath 'localfile:/index.html'

  loadFile:(path, callback = noop)->
    file = FSHelper.createFileFromPath path
    kite = KD.getSingleton('vmController').getKiteByVmName file.vmName
    return  callback {message: "VM not found"}  unless kite

    file.fetchContents (err, content)=>
      return callback err  if err

      file.path = path
      @openFile file, content

      KD.utils.defer -> callback null, {file, content}

  loadLastOpenFile:->
    path = @storage.getAt @_lastFileKey
    return  unless path

    @loadFile path, (err)=>
      if err?
      then @storage.unsetKey @_lastFileKey
      else @emit "RecentFileLoaded"

  openFile: (file, content)->
    validPath = file instanceof FSFile and not /^localfile\:/.test file.path

    if validPath
    then @storage.setValue @_lastFileKey, file.path
    else @storage.unsetKey @_lastFileKey
  
    @ace.editor.setValue content, -1
    @ace.setSyntax()
    @setData file

  viewAppended:->
    
    @findAndReplaceView = new AceFindAndReplaceView delegate: @
    @findAndReplaceView.hide()
    
    @addSubView @ace
    @addSubView @findAndReplaceView

  getValue: ->
    @ace.editor.getSession().getValue()
  
  requestSave:->
    
    file    = @getData()
    return  unless file
    content = @getValue()
    
    file.save content, (err)-> warn err  if err
    
  requestSaveAll:->
    log "save all"

  prepareEditor:->
    @ace.addKeyCombo "save",       "Ctrl-S",       @bound "requestSave"
    @ace.addKeyCombo "saveAll",    "Ctrl-Shift-S", @bound "requestSaveAll"
    @ace.addKeyCombo "find",       "Ctrl-F",       @ace.lazyBound "showFindReplaceView", no
    @ace.addKeyCombo "replace",    "Ctrl-Shift-F", @ace.lazyBound "showFindReplaceView", yes
    @ace.addKeyCombo "preview",    "Ctrl-Shift-P", => @getDelegate().preview()
    @ace.addKeyCombo "fullscreen", "Ctrl-Enter",   => @getDelegate().toggleFullscreen()
    @ace.addKeyCombo "gotoLine",   "Ctrl-G",       @ace.bound "showGotoLine"
    @ace.addKeyCombo "settings",   "Ctrl-,",       noop # ace creates a settings view for this shortcut, overriding it.
  
    @on "PaneResized", _.debounce(=> @ace.editor.resize()) , 400


class PhonegapMainView extends KDView
  
  user            = KD.nick()
  domain          = "#{user}.kd.io"
  outPath         = "/tmp/_PhoneGapinstaller.out"
  phoneGapBin     = "/usr/bin/phonegap"
  installerScript = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/installer.sh"
  phonegapLogo    = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/phonegap.png"
  appLogo         = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/app.png"
  iosApp          = "https://itunes.apple.com/app/id843536693"
  androidApp      = "https://play.google.com/store/apps/details?id=com.adobe.phonegap.app"
  phonegapApis    = "http://phonegap.com/about/feature/"

  constructor:(options = {}, data)->
    options.cssClass = 'phonegap main-view'
    super options, data

  viewAppended:->
    KD.singletons.appManager.require 'Teamwork', =>
      
      #Work Container
      @addSubView @workContainer = new KDCustomHTMLView
        tagName    : "div"
        cssClass   : "work-container"
      
      @workContainer.addSubView @workDownload = new KDCustomHTMLView
        tagName    : "div"
        cssClass   : "download-view"
       
      @workDownload.addSubView new KDCustomHTMLView
        tagName       : 'img'
        cssClass      : 'logo'
        attributes    :
          src         : appLogo
          
      @workDownload.addSubView new KDCustomHTMLView
        tagName    : "div"
        cssClass   : "helper"
        partial  : """ 
          <p>The PhoneGap Developer app aims to lower the barrier of entry to creating PhoneGap applications. You can now immediately preview your app on a device without installing platform SDKs, registering devices, or even compiling code. You have full access to the <a href="#{phonegapApis}">official PhoneGap APIs</a>. You can even develop an iOS app on Windows - and soon - a Windows Phone app on OS X. Whether you’re a novice or expert, we think the PhoneGap Developer app will become part of your personal toolkit!</p>
          <p>
            <strong>1. Install the PhoneGap Developer App</strong><br>
            Now grab the mobile app, which is globally available in an app store near you:
            <br><br>
            <div class="links">
              <ul>
                <li><a href="#{iosApp}">iOS from the App Store</a></li>
                <li><a href="#{androidApp}">Android from Google Play</a></li>
              </ul>
            </div>
          </p>
          <p>
            <strong>2. Create an App</strong><br>
            The PhoneGap Developer app is compatible with existing PhoneGap and Apache Cordova projects.
            <br><br>
            You can create a new app:
            <div class="code">
              $ phonegap create my-app
              <br>
              $ cd my-app/
            </div>
            <br>
            Or open an existing app:
            <div class="code">
              $ cd ~/PhoneGap/my-existing-app
            </div>
          </p>
          <p>
            <strong>3. Pair the CLI and Developer App</strong><br>
            This is where the magic happens. The CLI starts a tiny web server to serve your project. Then, the PhoneGap Developer App connects to that server.
            <br><br>
            First, use the CLI to serve your project:
            <div class="code">
              $ phonegap serve
              <br>
              [phonegap] starting app server...
              <br>
              [phonegap] listening on #{user}.kd.io:3000
              <br>
              [phonegap]
              <br>
              [phonegap] ctrl-c to stop the server
              <br>
              [phonegap]
            </div>
            <br>
            Second, enter the server address into the PhoneGap Developer App. In this example, the address is <strong>#{user}.kd.io:3000</strong>
          </p>
          <p>
            <strong>4. Get to Work</strong><br>
            Once paired, it’s business as usual. You can freely add, edit, and remove files from your project. Every saved change will automatically update the preview displayed in the PhoneGap Developer App.
            <br><br>
            You can also use hidden touch gestures for additional control:
            <br>
            <ul>
              <li>3-finger tap will go to the home page</li>
              <li>4-finger tap will force the app to update</li>
            <ul>
          </p>
        """
     
      @workContainer.addSubView @workEditor = new Workspace
        title      : "Text Editor"
        name       : "TextEditor"
        cssClass   : "editor-view"
        panels     : [
          title               : "Text Editor"
          layout              :
            direction         : "vertical"
            sizes             : ["180px", "100%"]
            splitName         : "BaseSplit"
            views             : [
              {
                type          : "custom"
                name          : "finder"
                paneClass     : FinderView
              }                                       
              {
                type          : "custom"
                name          : "JSEditor"
                paneClass     : EditorView
              }                 
            ]
        ] 
        
      @workContainer.addSubView @workTerminal = new Workspace
        title      : "Terminal"
        name       : "Terminal"
        cssClass   : "terminal-view"
        panels     : [
          title               : "Terminal"
          layout              :
            direction         : "vertical"
            sizes             : ["100%", null]
            splitName         : "BaseSplit"
            views             : [
              {
                type          : "custom"
                name          : "Terminal"
                paneClass    : TerminalView
              }                 
            ]
        ]
  

      @workEditor.once "viewAppended", =>
        @emit 'ready'

        {JSEditor} = \
          @workEditor.activePanel.panesByName

        JSEditor.ace.once 'ace.ready', =>
      
          JSEditor.ace.editor.on "change", \
            _.debounce (@lazyBound 'emit', 'previewApp', no), 500

    
      #Installer Container
      @addSubView @installContainer = new KDCustomHTMLView
        tagName    : "div"
        cssClass   : "install-container hidden"
      
      @installContainer.addSubView new KDHeaderView
        title         : "PhoneGap Installer"
        type          : "big"

      @installContainer.addSubView @installToggle = new KDToggleButton
        cssClass        : 'toggle-button'
        style           : "clean-gray" 
        defaultState    : "Show details"
        states          : [
          title         : "Show details"
          callback      : (cb)=>
            @installTerminal.setClass 'in'
            @installToggle.setClass 'toggle'
            @installTerminal.webterm.setKeyView()
            cb?()
        ,
          title         : "Hide details"
          callback      : (cb)=>
            @installTerminal.unsetClass 'in'
            @installToggle.unsetClass 'toggle'
            cb?()
        ]

      @installContainer.addSubView new KDCustomHTMLView
        tagName       : 'img'
        cssClass      : 'logo'
        attributes    :
          src         : phonegapLogo

      @installContainer.addSubView @installProgress = new KDProgressBarView
        initial       : 100
        title         : "Checking installation..."

      @installContainer.addSubView @installTerminal = new TerminalPane
        cssClass      : 'terminal'

      @installContainer.addSubView @installButton = new KDButtonView
        title         : "Install PhoneGap"
        cssClass      : 'main-button solid'
        loader        :
          color       : "#FFFFFF"
          diameter    : 12
        callback      : => @installCallback()

      @installContainer.addSubView new KDCustomHTMLView
        cssClass : "phonegap-help"
        partial  : """
          <p>Easily create apps using the web technologies you know and love: <strong>HTML</strong>, <strong>CSS</strong>, and <strong>JavaScript</strong>.</p>
          <p>PhoneGap is a free and open source framework that allows you to create mobile apps using standardized web APIs for the platforms you care about. For more information checkout phonegaps <a href="http://phonegap.com/">website</a>.</p>
        """
      
      @watcher = new LogWatcher
      @checkState()
  
  startWork:->
    {Terminal} = @workTerminal.panels[0].panesByName
    Terminal.terminal.runCommand "cd ~/PhoneGap;";
  
  startDemo:->
    {Terminal} = @workTerminal.panels[0].panesByName
    Terminal.terminal.runCommand "cd ~/PhoneGap/hello; phonegap serve;";
    
    {finder} = @workEditor.panels[0].panesByName
    finder.loadFile("~/PhoneGap/hello/www/index.html")
    
  
  checkState:->
    vmc = KD.getSingleton 'vmController'
    @installButton.showLoader()

    FSHelper.exists phoneGapBin, vmc.defaultVmName, (err, PhoneGap)=>
      warn err if err
      
      unless PhoneGap
        @installProgress.updateBar 100, '%', "PhoneGap is not installed."
        @switchState 'install'
      else
        @switchState 'ready'
        
  switchState:(state = 'run')->
    @watcher.off 'UpdateProgress'

    switch state
      when 'install'
        @installContainer.show()
        @workContainer.hide()
        @installButton.hideLoader()
      when 'ready'
        @installContainer.hide()
        @workContainer.show()
        @startWork()
      when 'demo'
        @installContainer.hide()
        @workContainer.show()
        @startDemo()
   
    
  stopCallback:->
    @_lastRequest = 'stop'
    @checkState()

  installCallback:->
    @watcher.on 'UpdateProgress', (percentage, status)=>
      @installProgress.updateBar percentage, '%', status
      
      if percentage is "100"
        @installButton.hideLoader()
        @installTerminal.unsetClass 'in'
        @installToggle.setState 'Show details'
        @installToggle.unsetClass 'toggle'
        @switchState 'demo'
      
      else if percentage is "80"
        @installTerminal.unsetClass 'in'
        @installToggle.setState 'Show details'
        @installToggle.unsetClass 'toggle'
        
      else if percentage is "40"
        @installTerminal.setClass 'in'
        @installTerminal.webterm.setKeyView()
        @installToggle.setState 'Hide details'
        @installToggle.setClass 'toggle'
      
      else if percentage is "0"
        @installTerminal.unsetClass 'in'
        @installToggle.setState 'Show details'
        @installToggle.unsetClass 'toggle'

    session = (Math.random() + 1).toString(36).substring 7
    tmpOutPath = "#{outPath}/#{session}"
    vmc = KD.getSingleton 'vmController'
    vmc.run "rm -rf #{outPath}; mkdir -p #{tmpOutPath}", =>
      @watcher.stopWatching()
      @watcher.path = tmpOutPath
      @watcher.watch()
      @installTerminal.runCommand "curl --silent #{installerScript} | bash -s #{session} #{user}"

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
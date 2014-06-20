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

        switch file.getExtension()
          when 'css', 'styl'
          then editor = CSSEditor
          else editor = JSEditor
        
        editor.openFile file, contents
        
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
  png             = "https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/phonegap.png"

  constructor:(options = {}, data)->
    options.cssClass = 'phonegap main-view'
    super options, data

  viewAppended:->
    KD.singletons.appManager.require 'Teamwork', =>
      
      @addSubView @workContainer = new KDCustomHTMLView
        tagName    : "div"
        cssClass   : "work-container hidden"
      
      @workContainer.addSubView new KDCustomHTMLView
        tagName    : "iframe"
        cssClass   : "iframe"
        attributes :
          src      : ""        
     
      @workContainer.addSubView @workEditor = new Workspace
        title      : "Text Editor"
        name       : "TextEditor"
        cssClass   : "textEditor"
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
      
      @workContainer.addSubView @workTerminal = new TerminalPane
        title      : "Terminal"
        name       : "Terminal"
        cssClass   : 'terminalView'

      @workEditor.once "viewAppended", =>
        @emit 'ready'

        {JSEditor} = \
          @workEditor.activePanel.panesByName

        JSEditor.ace.once 'ace.ready', =>
      
          JSEditor.ace.editor.on "change", \
            _.debounce (@lazyBound 'emit', 'previewApp', no), 500

    
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
          src         : png

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
          <p><strong>NOTE:</strong> To test PhoneGap apps on Koding please install the Ripple Emulator <a href="https://chrome.google.com/webstore/detail/ripple-emulator-beta/geelfhphabnejjhdalkjhgipohgpdnoc">chrome extension</a>. After installing the chome extension, please enable it when you are given the phonegap launch url.<img src="https://raw.githubusercontent.com/bvallelunga/PhoneGap.kdapp/master/resources/screenshot.png"/></p>
          <p>Easily create apps using the web technologies you know and love: <strong>HTML</strong>, <strong>CSS</strong>, and <strong>JavaScript</strong>.</p>
          <p>PhoneGap is a free and open source framework that allows you to create mobile apps using standardized web APIs for the platforms you care about. For more information checkout phonegaps <a href="http://phonegap.com/">website</a>.</p>
        """
      
      @watcher = new LogWatcher
      @checkState()
  
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
   
    
  stopCallback:->
    @_lastRequest = 'stop'
    @checkState()

  installCallback:->
    @watcher.on 'UpdateProgress', (percentage, status)=>
      @progress.updateBar percentage, '%', status
      if percentage is "100"
        @installButton.hideLoader()
        @installTerminal.unsetClass 'in'
        @installToggle.setState 'Show details'
        @installToggle.unsetClass 'toggle'
        @switchState 'ready'
      
      else if percentage is "80"
        @installTerminal.setClass 'in'
        @installToggle.setState 'Hide details'
        @installToggle.setClass 'toggle'
        
      else if percentage is "40"
        @installTerminal.setClass 'in'
        @installTerminal.webterm.setKeyView()
        @installToggle.setState 'Show details'
        @installToggle.setClass 'toggle'
      
      else if percentage is "0"
        @installTerminal.setClass 'in'
        @installToggle.setState 'Hide details'
        @installToggle.setClass 'toggle'

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
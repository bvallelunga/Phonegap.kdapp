class PhonegapMainView extends KDView

  constructor:(options = {}, data)->
    options.cssClass = 'phonegap main-view'
    super options, data

  viewAppended:->
    @addSubView new KDView
      partial  : "Welcome to Phonegap app!"
      cssClass : "welcome-view"

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
      name     : "Phonegap"
      routes   :
        "/:name?/Phonegap" : null
        "/:name?/bvallelunga/Apps/Phonegap" : null
      dockPath : "/bvallelunga/Apps/Phonegap"
      behavior : "application"
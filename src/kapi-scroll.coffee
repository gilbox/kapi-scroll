if (typeof define == 'function' && define.amd)
  # When using rekapi with requirejs, you must handle the dependencies yourself, because
  # here we assume that if require is being used then rekapi has already been loaded in
  Rekapi = window.Rekapi or require('rekapi')

  # If any other deps are being loaded in without being exposed in the global namespace,
  # the same as above applies
  _ = window._ or (if require.defined('lodash') then require('lodash') else require('underscore'))
  AnimationFrame = window.AnimationFrame or (if require.defined('animationFrame') then require('animationFrame') else require('AnimationFrame'))
else
  [Rekapi, _, AnimationFrame] = [window.Rekapi, window._, window.AnimationFrame]

angular.module('gilbox.kapiScroll', [])
.factory 'rekapi', ($document) -> new Rekapi($document[0].body)

.constant 'kapiFormulas', {

  # formulas are always in the format: variable or variable<offset>
  #   (note that you cannot combine formula variables)
  # for example:
  #
  #      top+40
  #      top-120
  #      top
  #      center
  #      center-111
  #
  # are valid formulas. (top40 is valid as well but less intuitive)
  #
  # each property of the sparkFormulas object is a formula variable

  # top of the element hits the top of the viewport
  top: (element, container, rect, containerRect, offset) ->  ~~(rect.top - containerRect.top + offset)

  # top of the element hits the center of the viewport
  center: (element, container, rect, containerRect, offset) ->  ~~(rect.top - containerRect.top - container.clientHeight/2 + offset)

  # top of the element hits the bottom of the viewport
  bottom: (element, container, rect, containerRect, offset) ->  ~~(rect.top - containerRect.top - container.clientHeight + offset)
}

.directive 'kapiScroll', (rekapi, $window, kapiFormulas) ->
  (scope, element, attr) ->
    actor = rekapi.addActor({ context: element[0] })
    y = 0
    prevScrollY = 0
    scrollY = 0
    animationFrame = new AnimationFrame()
    updating = false

    container = document.documentElement

    actionProps = {

      # When the up, down fns are called, `this` is the current keyFrame object

      # fn reference that is called when scrolled up past keyframe
      'onUp':
        up: -> @onUp(@, 'onUp')

      # fn reference that is called when scrolled down past keyframe
      'onDown':
        down: -> @onDown(@, 'onDown')

      # class(es) added when scrolled down past keyframe,
      'downAddClass':
        down: -> element.addClass(@downAddClass)

      # class(es) added when scrolled up past keyframe,
      'upAddClass':
        up: -> element.addClass(@upAddClass)

      # class(es) removed when scrolled down past keyframe
      'downRemoveClass':
        down: -> element.removeClass(@downRemoveClass)

      # class(es) removed when scrolled up past keyframe
      'upRemoveClass':
        up: -> element.removeClass(@upRemoveClass)

    }
    actionPropKeys = _.keys(actionProps)
    actions = {}
    actionFrames = []
    actionFrameIdx = -1

    actionsUpdate = ->

      d = scrollY - prevScrollY

      if d<0 and actionFrameIdx >= 0  # scroll up: don't apply on page load (only apply on page load for downward movement)
        idx = if (actionFrameIdx >= actionFrames.length) then actionFrameIdx-1 else actionFrameIdx
        while (idx >= 0 and y < actionFrames[idx])
          c = actions[actionFrames[idx]]

          for prop of c
            actionProp = actionProps[prop]
            actionProp.up.apply(c) if actionProp.up

          actionFrameIdx = --idx

      if d>=0 and actionFrameIdx < actionFrames.length  # scroll down: will apply on page load
        idx = if (actionFrameIdx < 0) then 0 else actionFrameIdx
        while (idx < actionFrames.length and y > actionFrames[idx])
          c = actions[actionFrames[idx]]

          for prop of c
            actionProp = actionProps[prop]
            actionProp.down.apply(c) if actionProp.down

          actionFrameIdx = ++idx

      prevScrollY = scrollY


    actionsUpdate = _.debounce(actionsUpdate, 66, {leading: true, maxWait: 66})


    update = ->
      d = scrollY - y
      ad = Math.abs(d)
      if ad < 1.5
        updating = false
        y = scrollY
        rekapi.update(y)
      else
        updating = true
        y += if ad>8 then d*0.25 else (if d > 0 then 1 else -1) # ease the scroll
        rekapi.update(parseInt(y))
        animationFrame.request(update)


    # automatic conversion from camelCase to dashed-case
    dashersize = (str) ->
      str.replace(/\W+/g, '-').replace(/([a-z\d])([A-Z])/g, '$1-$2').toLowerCase()


    ksWatchCancel = scope.$watch attr.kapiScroll, (data) ->
      return unless data

      # useful in angular < v1.3 where one-time binding isn't available
      if attr.kapiScrollBindOnce? then ksWatchCancel()

      # element ease property
      elmEase = data.ease || 'linear';
      delete data.ease

      actions = {}
      actionFrames = []

      # this is used for formula comprehension... a possible performance improvement might
      # forgo these calculations by adding some option or deferring calculation automatically
      rect = element[0].getBoundingClientRect()
      containerRect = container.getBoundingClientRect()

      # setup the rekapi keyframes
      for scrollY, keyFrame of data

        # formula comprehension
        # when scrollY first char is not a digit, we assume this is a formula
        c = scrollY.charCodeAt(0)
        if (c < 48 or c > 57)
#              keyFrame.formula = scrollY # we could possibly support this by adding a check below that skips it for rekapi
          parts = scrollY.match(/^(\w+)(.*)$/)
          variable = parts[1]
          offset = ~~parts[2]
          scrollY = kapiFormulas[variable](element, container, rect, containerRect, offset)

        actionCount = 0

        # custom actions not supported by rekapi
        for actionProp in actionPropKeys
          if keyFrame[actionProp]
            actionCount++
            actions[scrollY] or= {}
            actions[scrollY][actionProp] = keyFrame[actionProp]
            delete keyFrame[actionProp]

        actionFrames.push(parseInt(scrollY)) if actionCount

        # keyframe ease property
        # (will override or fallback to element ease property)
        ease = {}
        kfEase = elmEase
        if keyFrame.ease?
          if angular.isObject(keyFrame.ease)
            ease = keyFrame.ease
          else
            kfEase = keyFrame.ease
          delete keyFrame.ease

        # comprehension of array-notation for easing
        # (will override or fall back to keyframe ease propery as needed)
        for prop, val of keyFrame
          dprop = dashersize(prop)
          val = [val, kfEase] if not angular.isArray(val)
          o = {}
          o[dprop] = val[1]
          angular.extend(ease, o)
          keyFrame[dprop] = val[0]
          delete keyFrame[prop] if prop != dprop

        actor.keyframe(scrollY, keyFrame, ease)
        console.log "keyframe-->scrollY, keyFrame, ease", scrollY, keyFrame, ease



      console.log "-->actions", actions
      console.log "-->actionFrames", actionFrames


      actionFrames.sort (a,b) -> a > b

      y = prevScrollY = scrollY = $window.scrollY
      update()
      actionsUpdate()
    , true  # deep watch

    # respond to scroll event
    angular.element($window).on 'scroll', ->
      scrollY = $window.scrollY
      actionsUpdate()
      update() if !updating # debounced update

    scope.$on '$destroy', ->
      rekapi.removeActor(actor)
      angular.element($window).off 'scroll'
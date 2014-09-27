angular.module('gilbox.sparkScroll', [])
.directive 'sparkScroll', ($window) ->
  (scope, element, attr) ->
    prevScrollY = 0
    scrollY = 0

    sparkData = {}
    actionFrames = []
    actionFrameIdx = -1

    actionProps = {

      # When the up, down fns are called, `this` is the current keyFrame object

      # keyframe onUp property
      # fn reference that is called when scrolled up past keyframe
      'onUp':
        up: -> @actions.onUp(@)

      # keyframe onDown property
      # fn reference that is called when scrolled down past keyframe
      'onDown':
        down: -> @actions.onDown(@)

      # keyframe class property
      # class(es) added when scrolled down past keyframe,
      # but removed when scrolled up past keyframe
      'class':
        up: -> element.removeClass(@actions['class'])
        down: -> element.addClass(@actions['class'])

      # keyframe classUp property
      # class(es) added when scrolled up past keyframe,
      # but removed when scrolled down past keyframe
      'classUp':
        up: -> element.addClass(@actions.classUp)
        down: -> element.removeClass(@actions.classUp)

      # keyframe classRemove property
      # class(es) removed when scrolled down past keyframe
      'classRemove':
        down: -> element.removeClass(@actions.classRemove)

      # keyframe classUpRemove property
      # class(es) removed when scrolled up past keyframe
      'classUpRemove':
        up: -> element.removeClass(@actions.classUpRemove)

      # keyframe broadcast event property
      # broadcasts an event when scrolled down past keyframe
      'broadcastDown':
        down: -> scope.$broadcast(@actions.broadcastDown, @)

      # keyframe broadcast event property
      # broadcasts an event when scrolled up past keyframe
      'broadcastUp':
        down: -> scope.$broadcast(@actions.broadcastUp, @)

      # keyframe emit event property
      # emits an event when scrolled down past keyframe
      'emitDown':
        down: -> scope.$emit(@actions.emitDown, @)

      # keyframe emit event property
      # emits an event when scrolled up past keyframe
      'emitUp':
        down: -> scope.$emit(@actions.emitUp, @)
    }
    actionPropKeys = _.keys(actionProps)

    actionsUpdate = ->

      d = scrollY - prevScrollY

      if d<0 and actionFrameIdx >= 0  # scroll up: don't apply on page load (only apply on page load for downward movement)
        idx = if (actionFrameIdx >= actionFrames.length) then actionFrameIdx-1 else actionFrameIdx
        while (idx >= 0 and scrollY < actionFrames[idx])
          c = sparkData[actionFrames[idx]]

          for prop of c.actions
            actionProp = actionProps[prop]
            actionProp.up.apply(c) if actionProp?.up

          actionFrameIdx = --idx

      if d>=0 and actionFrameIdx < actionFrames.length  # scroll down: will apply on page load
        idx = if (actionFrameIdx < 0) then 0 else actionFrameIdx
        while (idx < actionFrames.length and scrollY > actionFrames[idx])
          c = sparkData[actionFrames[idx]]

          for prop of c.actions
            actionProp = actionProps[prop]
            actionProp.down.apply(c) if actionProp?.down

          actionFrameIdx = ++idx


    actionsUpdate = _.debounce(actionsUpdate, 33, {leading: true, maxWait: 33})


    watchCancel = scope.$watch attr.sparkScroll, (data) ->
      return unless data

      # useful in angular < v1.3 where one-time binding isn't available
      if attr.sparkScrollBindOnce? then watchCancel()

      sparkData = data
      actionFrames = []

      for scrollY, keyFrame of sparkData

        actionCount = 0

        # put actions in actions sub-object
        for actionProp in actionPropKeys
          if keyFrame[actionProp]
            actionCount++
            keyFrame.actions or= { }
            keyFrame.actions[actionProp] = keyFrame[actionProp]
            delete keyFrame[actionProp]

        # @todo: these are for prototypeing. If you use directives as needed, these shouldn't be necessary (?)
        keyFrame.actionCount = actionCount
        keyFrame.elm = element
        keyFrame.scope = scope
        keyFrame.domElm = element[0]

      actionFrames.push(parseInt(scrollY)) for scrollY of sparkData
      actionFrames.sort (a,b) -> a > b

      prevScrollY = scrollY = $window.scrollY
      actionsUpdate()

    , true  # deep watch

    # respond to scroll event
    angular.element($window).on 'scroll', ->
      prevScrollY = scrollY
      scrollY = $window.scrollY
      actionsUpdate()

    scope.$on '$destroy', ->
      angular.element($window).off 'scroll'
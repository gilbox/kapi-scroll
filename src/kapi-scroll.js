(function() {
  var AnimationFrame, Rekapi, _, _ref;

  if (typeof define === 'function' && define.amd) {
    Rekapi = window.Rekapi || require('rekapi');
    _ = window._ || (require.defined('lodash') ? require('lodash') : require('underscore'));
    AnimationFrame = window.AnimationFrame || (require.defined('animationFrame') ? require('animationFrame') : require('AnimationFrame'));
  } else {
    _ref = [window.Rekapi, window._, window.AnimationFrame], Rekapi = _ref[0], _ = _ref[1], AnimationFrame = _ref[2];
  }

  angular.module('gilbox.kapiScroll', []).factory('rekapi', function($document) {
    return new Rekapi($document[0].body);
  }).directive('kapiScroll', function(rekapi, $window) {
    return function(scope, element, attr) {
      var actionFrameIdx, actionFrames, actionPropKeys, actionProps, actions, actionsUpdate, actor, animationFrame, dashersize, ksWatchCancel, prevScrollY, scrollY, update, updating, y;
      actor = rekapi.addActor({
        context: element[0]
      });
      y = 0;
      prevScrollY = 0;
      scrollY = 0;
      animationFrame = new AnimationFrame();
      updating = false;
      actionProps = {
        'onUp': {
          up: function() {
            return this.onUp(this, 'onUp');
          }
        },
        'onDown': {
          down: function() {
            return this.onDown(this, 'onDown');
          }
        },
        'downAddClass': {
          down: function() {
            return element.addClass(this.downAddClass);
          }
        },
        'upAddClass': {
          up: function() {
            return element.addClass(this.upAddClass);
          }
        },
        'downRemoveClass': {
          down: function() {
            return element.removeClass(this.downRemoveClass);
          }
        },
        'upRemoveClass': {
          up: function() {
            return element.removeClass(this.upRemoveClass);
          }
        }
      };
      actionPropKeys = _.keys(actionProps);
      actions = {};
      actionFrames = [];
      actionFrameIdx = -1;
      actionsUpdate = function() {
        var actionProp, c, d, idx, prop;
        d = scrollY - prevScrollY;
        if (d < 0 && actionFrameIdx >= 0) {
          idx = actionFrameIdx >= actionFrames.length ? actionFrameIdx - 1 : actionFrameIdx;
          while (idx >= 0 && y < actionFrames[idx]) {
            c = actions[actionFrames[idx]];
            for (prop in c) {
              actionProp = actionProps[prop];
              if (actionProp.up) {
                actionProp.up.apply(c);
              }
            }
            actionFrameIdx = --idx;
          }
        }
        if (d >= 0 && actionFrameIdx < actionFrames.length) {
          idx = actionFrameIdx < 0 ? 0 : actionFrameIdx;
          while (idx < actionFrames.length && y > actionFrames[idx]) {
            c = actions[actionFrames[idx]];
            for (prop in c) {
              actionProp = actionProps[prop];
              if (actionProp.down) {
                actionProp.down.apply(c);
              }
            }
            actionFrameIdx = ++idx;
          }
        }
        return prevScrollY = scrollY;
      };
      actionsUpdate = _.debounce(actionsUpdate, 66, {
        leading: true,
        maxWait: 66
      });
      update = function() {
        var ad, d;
        d = scrollY - y;
        ad = Math.abs(d);
        if (ad < 1.5) {
          updating = false;
          y = scrollY;
          return rekapi.update(y);
        } else {
          updating = true;
          y += ad > 8 ? d * 0.25 : (d > 0 ? 1 : -1);
          rekapi.update(parseInt(y));
          return animationFrame.request(update);
        }
      };
      dashersize = function(str) {
        return str.replace(/\W+/g, '-').replace(/([a-z\d])([A-Z])/g, '$1-$2').toLowerCase();
      };
      ksWatchCancel = scope.$watch(attr.kapiScroll, function(data) {
        var actionCount, actionProp, dprop, ease, elmEase, keyFrame, kfEase, o, prop, val, _i, _len;
        if (!data) {
          return;
        }
        if (attr.kapiScrollBindOnce != null) {
          ksWatchCancel();
        }
        elmEase = data.ease || 'linear';
        delete data.ease;
        actions = {};
        actionFrames = [];
        for (scrollY in data) {
          keyFrame = data[scrollY];
          actionCount = 0;
          for (_i = 0, _len = actionPropKeys.length; _i < _len; _i++) {
            actionProp = actionPropKeys[_i];
            if (keyFrame[actionProp]) {
              actionCount++;
              actions[scrollY] || (actions[scrollY] = {});
              actions[scrollY][actionProp] = keyFrame[actionProp];
              delete keyFrame[actionProp];
            }
          }
          if (actionCount) {
            actionFrames.push(parseInt(scrollY));
          }
          ease = {};
          kfEase = elmEase;
          if (keyFrame.ease != null) {
            if (angular.isObject(keyFrame.ease)) {
              ease = keyFrame.ease;
            } else {
              kfEase = keyFrame.ease;
            }
            delete keyFrame.ease;
          }
          for (prop in keyFrame) {
            val = keyFrame[prop];
            dprop = dashersize(prop);
            if (!angular.isArray(val)) {
              val = [val, kfEase];
            }
            o = {};
            o[dprop] = val[1];
            angular.extend(ease, o);
            keyFrame[dprop] = val[0];
            if (prop !== dprop) {
              delete keyFrame[prop];
            }
          }
          actor.keyframe(scrollY, keyFrame, ease);
        }
        actionFrames.sort(function(a, b) {
          return a > b;
        });
        y = prevScrollY = scrollY = $window.scrollY;
        update();
        return actionsUpdate();
      }, true);
      angular.element($window).on('scroll', function() {
        scrollY = $window.scrollY;
        actionsUpdate();
        if (!updating) {
          return update();
        }
      });
      return scope.$on('$destroy', function() {
        rekapi.removeActor(actor);
        return angular.element($window).off('scroll');
      });
    };
  });

}).call(this);

//# sourceMappingURL=kapi-scroll.js.map
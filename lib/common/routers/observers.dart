// ignore_for_file: unnecessary_overrides

import 'package:flutter/material.dart';

import 'index.dart';

/// 记录路由的变化
class RouteObservers<R extends Route<dynamic>> extends RouteObserver<R> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    var name = route.settings.name ?? '';
    if (name.isNotEmpty) RoutePages.history.add(name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = route.settings.name;
    if (name == null) return;
    if (RoutePages.history.isNotEmpty && RoutePages.history.last == name) {
      RoutePages.history.removeLast();
      return;
    }
    RoutePages.history.remove(name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      var name = newRoute.settings.name ?? '';
      if (name.isNotEmpty) {
        final oldName = oldRoute?.settings.name;
        if (oldName == null) {
          RoutePages.history.add(name);
          return;
        }
        final index = RoutePages.history.lastIndexOf(oldName);
        if (index >= 0) {
          RoutePages.history[index] = name;
          return;
        }
        RoutePages.history.add(name);
      }
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    final name = route.settings.name;
    if (name == null) return;
    if (RoutePages.history.isNotEmpty && RoutePages.history.last == name) {
      RoutePages.history.removeLast();
      return;
    }
    RoutePages.history.remove(name);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didStartUserGesture(route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    super.didStopUserGesture();
  }
}


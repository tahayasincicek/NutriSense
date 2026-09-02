import 'dart:async';

import 'package:flutter/widgets.dart';

import 'accessibility_service.dart';

/// Ekran değiştiğinde önceki ekranın sesli anlatımını keser.
///
/// Sesli geri bildirim kuyruğa alınır; kullanıcı ekranı değiştirdiğinde eski
/// ekranın kalan cümleleri konuşmaya devam ediyordu. Bu, görme engelli
/// kullanıcı için yalnız rahatsız edici değil, yanıltıcıdır: duyduğu cümle
/// artık ekranda olmayan bir içeriği anlatır.
///
/// Kesme tek yerden yapılır; her ekranın kendi başına durdurmayı hatırlaması
/// gerekmez.
class SpeechRouteObserver extends NavigatorObserver {
  SpeechRouteObserver(this._accessibility);

  final AccessibilityService _accessibility;

  void _silence() {
    unawaited(_accessibility.stop());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // İlk ekranın açılışında kesecek bir konuşma yoktur; yalnız gerçek
    // geçişlerde susturulur.
    if (previousRoute != null) _silence();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _silence();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _silence();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _silence();
    super.didRemove(route, previousRoute);
  }
}

/* 앱에서만 도는 얇은 연결 코드.
   브라우저로 열면 window.Capacitor 가 없어서 아무것도 하지 않는다.
   그래서 www/ 폴더를 그냥 웹으로 열어봐도 사이트가 똑같이 뜬다. */
(function () {
  var cap = window.Capacitor;
  if (!cap || !cap.isNativePlatform || !cap.isNativePlatform()) return;

  var P = cap.Plugins || {};
  var StatusBar = P.StatusBar;
  var SplashScreen = P.SplashScreen;

  /* ---- 상태 표시줄 ----
     화면 모드에 따라 시계와 배터리 글자색을 바꾼다.
     어두운 모드면 흰 글씨(Dark), 밝은 모드면 검은 글씨(Light) 다. */
  function applyStatusBar() {
    if (!StatusBar) return;
    var dark = document.documentElement.dataset.theme === "dark";
    try {
      StatusBar.setStyle({ style: dark ? "DARK" : "LIGHT" });
    } catch (e) {}
  }
  if (StatusBar) {
    try { StatusBar.setOverlaysWebView({ overlay: true }); } catch (e) {}
    applyStatusBar();
    // 사이트가 html[data-theme] 을 바꾸면 따라간다
    try {
      new MutationObserver(applyStatusBar).observe(document.documentElement, {
        attributes: true,
        attributeFilter: ["data-theme"],
      });
    } catch (e) {}
  }

  /* ---- 시작 화면 ----
     사이트가 스스로 "불러오는 중" 화면을 그리고 있다가 준비되면 지운다.
     그 순간에 맞춰 애플 시작 화면을 내려야 검은 화면이 한 번 스치지 않는다. */
  var hidden = false;
  function hideSplash() {
    if (hidden) return;
    hidden = true;
    if (SplashScreen) {
      try { SplashScreen.hide({ fadeOutDuration: 220 }); } catch (e) {}
    }
  }
  function ready() {
    var root = document.getElementById("root");
    return root && !root.querySelector(".mr-splash") && root.children.length > 0;
  }
  if (ready()) hideSplash();
  else {
    var root = document.getElementById("root");
    if (root) {
      var mo = new MutationObserver(function () {
        if (ready()) { mo.disconnect(); hideSplash(); }
      });
      mo.observe(root, { childList: true, subtree: true });
    }
    // 화면이 끝내 안 뜨더라도 시작 화면에 갇히지는 않게 한다
    setTimeout(hideSplash, 8000);
  }
})();

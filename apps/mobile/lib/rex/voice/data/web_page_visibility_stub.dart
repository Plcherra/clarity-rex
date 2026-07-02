typedef WebPageVisibilityCallback = void Function(bool isVisible);

void listenWebPageVisibility(WebPageVisibilityCallback callback) {}

void disposeWebPageVisibilityListener() {}

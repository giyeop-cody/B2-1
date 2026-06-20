"""
UI 계층 (View Adapters)
- 사용자와 직접 상호작용하는 계층.
- 인터페이스 계층의 IView를 구현한다.
- 교체 가능성: ConsoleView → GUIView, WebView, TUIView 등
"""

from budget_app.views.console_view import ConsoleView

__all__ = ["ConsoleView"]

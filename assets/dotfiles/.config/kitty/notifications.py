def main(notification):
    app_name = (notification.application_name or "").lower()
    if app_name in ("", "kitty", "kitten", "kitten-notify") and not notification.icon_path:
        notification.icon_names = ("utilities-terminal",)
    return False

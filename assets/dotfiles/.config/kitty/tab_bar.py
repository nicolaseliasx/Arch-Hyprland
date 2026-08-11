"""Keep normal tabs short while allowing Omni route titles to use free space."""

from kitty.fast_data_types import get_boss
from kitty.tab_bar import draw_tab_with_fade


def _is_omni_tab(tab):
    kitty_tab = get_boss().tab_for_id(tab.tab_id)
    return bool(
        kitty_tab
        and any(window.user_vars.get("omniroute_title") == "1" for window in kitty_tab)
    )


def draw_tab(
    draw_data,
    screen,
    tab,
    before,
    max_tab_length,
    index,
    is_last,
    extra_data,
):
    if _is_omni_tab(tab):
        draw_data = draw_data._replace(max_tab_title_length=0)
    return draw_tab_with_fade(
        draw_data,
        screen,
        tab,
        before,
        max_tab_length,
        index,
        is_last,
        extra_data,
    )

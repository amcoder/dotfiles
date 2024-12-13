set -g @plugin 'catppuccin/tmux'

set -g @catppuccin_flavor 'macchiato'

set -g @catppuccin_window_status_style 'rounded'
set -g @catppuccin_window_text "#W"
set -g @catppuccin_window_current_text "#W"
set -g @catppuccin_window_number_position "right"
set -g @catppuccin_window_flags "icon"

set -g status-right "#{E:@catppuccin_status_application}"
set -ag status-right "#{E:@catppuccin_status_session}"
set -g status-left ""


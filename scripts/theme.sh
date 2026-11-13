#!/usr/bin/env bash
#
# Switch the Gruvbox flavour (dark / light) across every config in this repo.
#
# Each config keeps a single "switcher" line that points at a flavour-specific
# palette file; this script rewrites those lines in place. Because ~/.config is
# stowed into this repo, editing here is what the running apps actually see.
#
#   ./scripts/theme.sh            # show what each config is set to
#   ./scripts/theme.sh light      # switch everything to Gruvbox Light
#   ./scripts/theme.sh toggle     # flip between dark and light

set -euo pipefail

DOTFILES="$(cd -- "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")/.." && pwd)"

# Canonical record of the active flavour.
MARKER="hypr/.config/hypr/modules/colors.lua"

# Light drives the system into light mode, dark into dark. These are still the
# Catppuccin GTK themes; change them if you install a Gruvbox pair under ~/.themes.
GTK_THEME_LIGHT="Catppuccin-BL-MB-Light"
GTK_THEME_DARK="Catppuccin-BL-MB-Dark"

# label | repo-relative file | ERE matching the switcher line | replacement
# @f@ expands to the flavour (dark or light).
targets() {
	cat <<-'EOF'
		btop|btop/.config/btop/btop.conf|^color_theme *=|color_theme = "gruvbox-@f@"
		ghostty|ghostty/.config/ghostty/config|^config-file *= *colors/|config-file = colors/gruvbox-@f@.conf
		waybar|waybar/.config/waybar/colors.css|^@import .*colors/|@import './colors/custom/gruvbox-@f@.css';
		swaync|swaync/.config/swaync/colors.css|^@import .*colors/|@import './colors/gruvbox-@f@.css';
		wlogout|wlogout/.config/wlogout/colors.css|^@import .*colors/|@import './colors/gruvbox-@f@.css';
		rofi|rofi/.config/rofi/shared/colors.rasi|^@import .*colors/|@import "~/.config/rofi/colors/gruvbox-@f@.rasi"
		hypr|hypr/.config/hypr/colors.conf|^source *=.*/colors/|source = ~/.config/hypr/colors/gruvbox-@f@.conf
		hypr-lua|hypr/.config/hypr/modules/colors.lua|^local active *=|local active = "@f@"
		tmux|tmux/.config/tmux/tmux.conf|^source-file .*/colors/|source-file ~/.config/tmux/colors/gruvbox-@f@.conf
		nvim|nvim/.config/nvim/lua/plugins/theme.lua|^local flavour *=|local flavour = "@f@"
	EOF
}

if [[ -t 1 ]]; then
	BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RED=$'\033[31m' RESET=$'\033[0m'
else
	BOLD='' DIM='' GREEN='' YELLOW='' RED='' RESET=''
fi

info() { printf '  %s\n' "$*"; }
ok() { printf '  %s✓%s %-9s %s%s%s\n' "$GREEN" "$RESET" "$1" "$DIM" "$2" "$RESET"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() {
	printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

# From the kernel rather than $WSL_DISTRO_NAME, which systemd user services
# (follow-windows-theme.service) do not get.
is_wsl() { grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; }

usage() {
	cat <<EOF
${BOLD}Usage:${RESET} ${0##*/} [FLAVOUR]

Switch every config in this dotfiles repo to a Gruvbox flavour.

${BOLD}Flavours:${RESET}
  dark            Gruvbox Dark
  light           Gruvbox Light
  toggle          flip between the two

With no argument, prints the flavour each config currently points at.
EOF
}

# Replace whole lines matching an ERE. Line-oriented, so the replacement text
# needs no escaping. Returns non-zero if nothing matched.
replace_line() {
	local file=$1 regex=$2 newline=$3
	local tmp line found=0

	tmp=$(mktemp)
	while IFS= read -r line || [[ -n $line ]]; do
		if [[ $line =~ $regex ]]; then
			printf '%s\n' "$newline"
			found=1
		else
			printf '%s\n' "$line"
		fi
	done <"$file" >"$tmp"

	if ((found)); then
		# Preserve the original mode rather than mktemp's 0600.
		chmod --reference="$file" "$tmp" 2>/dev/null || true
		mv -- "$tmp" "$file"
		return 0
	fi

	rm -f -- "$tmp"
	return 1
}

current_flavour() {
	local path="$DOTFILES/$MARKER"
	[[ -f $path ]] || return 1
	sed -nE 's/^local active = "([a-z]+)".*/\1/p' "$path" | head -1
}

show_current() {
	printf '%sActive flavour:%s %s\n\n' "$BOLD" "$RESET" "$(current_flavour || echo unknown)"
	printf '%sSwitcher lines:%s\n' "$BOLD" "$RESET"

	local label rel regex tmpl line settings
	while IFS='|' read -r label rel regex tmpl; do
		[[ -n ${label:-} ]] || continue
		if [[ ! -f "$DOTFILES/$rel" ]]; then
			warn "$(printf '%-9s' "$label") $rel not found"
			continue
		fi
		line=$(grep -m1 -E "$regex" "$DOTFILES/$rel" || true)
		if [[ -n $line ]]; then
			printf '  %-9s %s\n' "$label" "$line"
		else
			warn "$(printf '%-9s' "$label") no switcher line in $rel"
		fi
	done < <(targets)

	if is_wsl && settings=$(windows_terminal_settings); then
		line=$(grep -m1 -oE '"colorScheme": *"[^"]*"' "$settings" || true)
		printf '  %-9s %s\n' terminal "${line:-no colorScheme set}"
	fi
}

# Path to Windows Terminal's settings.json, as seen from WSL. Set WT_SETTINGS
# to override the lookup.
windows_terminal_settings() {
	if [[ -n ${WT_SETTINGS:-} ]]; then
		[[ -f $WT_SETTINGS ]] && printf '%s\n' "$WT_SETTINGS"
		return
	fi

	command -v cmd.exe >/dev/null 2>&1 || return 1

	local appdata pkg path
	appdata=$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')
	[[ -n $appdata ]] || return 1
	appdata=$(wslpath -u "$appdata") || return 1

	for pkg in Microsoft.WindowsTerminal_8wekyb3d8bbwe Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe; do
		path="$appdata/Packages/$pkg/LocalState/settings.json"
		if [[ -f $path ]]; then
			printf '%s\n' "$path"
			return 0
		fi
	done
	return 1
}

# Under WSL the terminal is Windows Terminal, and it paints the background
# behind nvim (transparent) and the shell, so it has to follow the flavour too.
# It hot-reloads settings.json, so rewriting the scheme name is enough. Only a
# "colorScheme" that already names a Gruvbox (or the old Catppuccin) scheme is
# touched, and only when the scheme it would switch to is defined: Windows
# Terminal has no built-in Gruvbox, see windows-terminal/gruvbox.json.
apply_windows_terminal() {
	local scheme=$1 settings tmp tab_bar=''

	if ! settings=$(windows_terminal_settings); then
		warn "settings.json not found — set WT_SETTINGS to its path"
		return 0
	fi

	if ! grep -qE '"colorScheme": *"(Gruvbox|Catppuccin) [A-Za-z]+"' "$settings"; then
		warn "no \"colorScheme\": \"Gruvbox …\" in settings.json — left alone"
		return 0
	fi

	if ! grep -qE "\"name\": *\"$scheme\"" "$settings"; then
		warn "no \"$scheme\" scheme in settings.json — add the ones in windows-terminal/gruvbox.json"
		return 0
	fi

	local exprs=(-e 's/^([[:space:]]*"colorScheme": *)"(Gruvbox|Catppuccin) [A-Za-z]+"/\1"'"$scheme"'"/')

	# Windows Terminal "themes" (tabs, tab row, window chrome) share the scheme
	# names. "theme" is only switched when it already names one, so "system"
	# stays, and only when the target is defined under "themes" — Windows
	# Terminal writes keys alphabetically, so that block runs to the end.
	if grep -qE '"theme": *"(Gruvbox|Catppuccin) [A-Za-z]+"' "$settings" &&
		sed -n '/"themes":/,$p' "$settings" | grep -qE "\"name\": *\"$scheme\""; then
		exprs+=(-e 's/^([[:space:]]*"theme": *)"(Gruvbox|Catppuccin) [A-Za-z]+"/\1"'"$scheme"'"/')
		tab_bar=1
	fi

	# Copied back in place rather than mv'd over: the file lives on the
	# Windows side, where replacing it can race Windows Terminal's own handle.
	tmp=$(mktemp)
	sed -E "${exprs[@]}" "$settings" >"$tmp"
	cat -- "$tmp" >"$settings"
	rm -f -- "$tmp"
	ok terminal "$scheme${tab_bar:+ (colours + tab bar)}"
}

# Windows itself only has a light/dark mode and an accent colour, so that is
# what follows the flavour: apps and the taskbar go light or dark, and the
# accent is set to the Gruvbox blues. Windows draws with the lighter shades of
# the palette in dark mode and the darker ones in light mode, so one palette
# serves both. Running apps repaint on the broadcast; the taskbar and Start can
# need a sign-out to pick up a changed accent.
apply_windows_appearance() {
	local flavour=$1 light=0 script out

	if ! command -v powershell.exe >/dev/null 2>&1; then
		warn "powershell.exe not found — Windows light/dark mode unchanged"
		return 0
	fi

	[[ $flavour == light ]] && light=1

	# Already there, typically because Windows itself just switched and
	# follow-windows-theme.sh called us: skip PowerShell's start-up cost.
	# Output is captured before matching: a `grep -q` that exits early can
	# fail reg.exe's last write, and with pipefail the whole check.
	if command -v reg.exe >/dev/null 2>&1; then
		local personalize accent
		personalize=$(reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 2>/dev/null || true)
		accent=$(reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' /v AccentColorMenu 2>/dev/null || true)
		# 0xff888545 is the accent (#458588) as ABGR, as set below.
		if [[ $(grep -cE "(AppsUseLightTheme|SystemUsesLightTheme) +REG_DWORD +0x$light"$'\r?$' <<<"$personalize") == 2 &&
			$accent == *0xff888545* ]]; then
			ok mode "$flavour (Windows apps + taskbar, already set)"
			ok accent "Gruvbox blue #458588 (already set)"
			return 0
		fi
	fi

	script=$(
		cat <<-'EOF'
			$ErrorActionPreference = 'Stop'

			$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
			Set-ItemProperty $personalize AppsUseLightTheme @LIGHT@ -Type DWord
			Set-ItemProperty $personalize SystemUsesLightTheme @LIGHT@ -Type DWord

			# RGBA: three lighter shades, the accent (#458588), three darker, a spare.
			$palette = [byte[]](0xc1,0xd2,0xcc,0, 0xa2,0xbc,0xb2,0, 0x83,0xa5,0x98,0, 0x45,0x85,0x88,0,
				0x07,0x66,0x78,0, 0x05,0x4c,0x5a,0, 0x04,0x33,0x3c,0, 0xd6,0x5d,0x0e,0)
			$accent = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
			if (-not (Test-Path $accent)) { New-Item $accent | Out-Null }
			Set-ItemProperty $accent AccentPalette $palette -Type Binary
			Set-ItemProperty $accent AccentColorMenu 0xff888545 -Type DWord  # ABGR, the accent
			Set-ItemProperty $accent StartColorMenu 0xff786607 -Type DWord   # ABGR, first darker shade

			$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
			Set-ItemProperty $dwm AccentColor 0xff888545 -Type DWord
			Set-ItemProperty $dwm ColorizationColor 0xc4458588 -Type DWord      # ARGB
			Set-ItemProperty $dwm ColorizationAfterglow 0xc4458588 -Type DWord

			# WM_SETTINGCHANGE "ImmersiveColorSet" to every top-level window, as the
			# Settings app does, so running apps repaint. Posted rather than sent:
			# a synchronous broadcast waits on each app while it repaints.
			Add-Type -Namespace Dotfiles -Name User32 -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SendNotifyMessage(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam);'
			if (-not [Dotfiles.User32]::SendNotifyMessage([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'ImmersiveColorSet')) {
				throw 'WM_SETTINGCHANGE broadcast failed'
			}
		EOF
	)
	script=${script//@LIGHT@/$light}

	# -EncodedCommand (UTF-16LE, base64) sidesteps quoting across the WSL boundary.
	if out=$(powershell.exe -NoProfile -NonInteractive -EncodedCommand \
		"$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)" 2>&1); then
		ok mode "$flavour (Windows apps + taskbar)"
		ok accent "Gruvbox blue #458588"
	else
		warn "powershell.exe failed — Windows light/dark mode and accent unchanged: ${out%%$'\r'*}"
	fi
}

apply_windows() {
	local flavour=$1

	is_wsl || return 0

	printf '\n%sWindows:%s\n' "$BOLD" "$RESET"
	apply_windows_terminal "Gruvbox ${flavour^}"
	apply_windows_appearance "$flavour"
}

# Replace "key=value" in an ini file, appending under [Settings] if absent.
set_ini_key() {
	local file=$1 key=$2 value=$3
	local tmp line found=0

	[[ -f $file ]] || return 1

	tmp=$(mktemp)
	while IFS= read -r line || [[ -n $line ]]; do
		if [[ $line == "$key="* ]]; then
			printf '%s=%s\n' "$key" "$value"
			found=1
		else
			printf '%s\n' "$line"
		fi
	done <"$file" >"$tmp"

	if ((!found)); then
		awk -v k="$key" -v v="$value" '
			{ print }
			/^\[Settings\]/ && !seen { print k "=" v; seen = 1 }
		' "$file" >"$tmp"
	fi

	chmod --reference="$file" "$tmp" 2>/dev/null || true
	mv -- "$tmp" "$file"
}

# The "-BL-MB-" themes reach GTK4 apps through symlinks into ~/.themes.
relink_gtk4_theme() {
	local gtk_theme=$1 name link target
	for name in assets gtk.css gtk-dark.css; do
		link="$HOME/.config/gtk-4.0/$name"
		# only re-point links that are already symlinks; never clobber real files
		[[ -L $link ]] || continue
		target="$HOME/.themes/$gtk_theme/gtk-4.0/$name"
		[[ -e $target ]] || continue
		ln -sfn "$target" "$link"
		ok "gtk4:$name" "-> ~/.themes/$gtk_theme/gtk-4.0/$name"
	done
}

# Light -> light mode, dark -> dark mode, for GTK/libadwaita apps and the
# xdg-desktop-portal appearance setting that Electron/Chromium apps read.
apply_system_appearance() {
	local flavour=$1
	local scheme gtk_theme prefer_dark

	if [[ $flavour == light ]]; then
		scheme=prefer-light
		gtk_theme=$GTK_THEME_LIGHT
		prefer_dark=0
	else
		scheme=prefer-dark
		gtk_theme=$GTK_THEME_DARK
		prefer_dark=1
	fi

	printf '\n%sSystem appearance:%s\n' "$BOLD" "$RESET"

	if [[ ! -d "$HOME/.themes/$gtk_theme" && ! -d "/usr/share/themes/$gtk_theme" ]]; then
		warn "GTK theme '$gtk_theme' is not installed — leaving the GTK theme alone"
		gtk_theme=''
	fi

	# Files first, dconf last. Running apps watch the dconf keys and re-read
	# their theme the moment those change, so the CSS and settings.ini they
	# would read must already be correct — otherwise a fast-reacting app picks
	# up the previous theme.

	# GTK apps that read settings.ini rather than dconf. These files are not
	# stowed, so they are edited in place in ~/.config.
	local ini
	for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
		[[ -f $ini ]] || continue
		[[ -n $gtk_theme ]] && set_ini_key "$ini" gtk-theme-name "$gtk_theme"
		set_ini_key "$ini" gtk-application-prefer-dark-theme "$prefer_dark"
		ok "${ini#"$HOME/.config/"}" "prefer-dark=$prefer_dark${gtk_theme:+, $gtk_theme}"
	done

	[[ -n $gtk_theme ]] && relink_gtk4_theme "$gtk_theme"

	if command -v gsettings >/dev/null 2>&1; then
		if [[ -n $gtk_theme ]]; then
			gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
			ok gtk-theme "$gtk_theme"
		fi
		# Last: this is the key xdg-desktop-portal exposes, so it is what most
		# apps actually react to.
		gsettings set org.gnome.desktop.interface color-scheme "$scheme"
		ok color-scheme "$scheme"
	else
		warn "gsettings not found — skipped the dconf appearance settings"
	fi

	return 0
}

# Point the wallpaper at the new flavour's set. The picker owns the directory
# resolution and only swaps when the current wallpaper is from the wrong set.
apply_wallpaper() {
	local picker="$HOME/.config/hypr/scripts/wallpaper-picker.sh" result

	printf '\n%sWallpaper:%s\n' "$BOLD" "$RESET"

	if [[ ! -x $picker ]]; then
		warn "wallpaper-picker.sh not found — wallpaper unchanged"
		return 0
	fi

	# awww only runs inside a graphical session
	if ! pgrep -x awww-daemon >/dev/null 2>&1; then
		info "${DIM}awww-daemon not running — wallpaper unchanged${RESET}"
		return 0
	fi

	if result=$("$picker" --sync 2>/dev/null); then
		ok "${result%% *}" "${result#* }"
	else
		warn "wallpaper-picker.sh --sync failed — wallpaper unchanged"
	fi

	return 0
}

reload_running_apps() {
	printf '\n%sReloading:%s\n' "$BOLD" "$RESET"
	local any=0

	if pgrep -x waybar >/dev/null 2>&1 && pkill -USR2 -x waybar; then
		ok waybar "config + css reloaded"
		any=1
	fi

	if pgrep -x swaync >/dev/null 2>&1 && command -v swaync-client >/dev/null 2>&1 &&
		swaync-client --reload-css >/dev/null 2>&1; then
		swaync-client --reload-config >/dev/null 2>&1 || true
		ok swaync "css reloaded"
		any=1
	fi

	if command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1; then
		ok hyprland "window borders reloaded"
		any=1
	fi

	# Ghostty does not watch its config file, but it exports the same
	# reload-config action its menu uses on the session bus.
	if pgrep -x ghostty >/dev/null 2>&1 && command -v gdbus >/dev/null 2>&1 &&
		gdbus call --session --dest com.mitchellh.ghostty \
			--object-path /com/mitchellh/ghostty \
			--method org.gtk.Actions.Activate \
			reload-config "[]" "{}" >/dev/null 2>&1; then
		ok ghostty "config reloaded"
		any=1
	fi

	if command -v tmux >/dev/null 2>&1 && tmux has-session >/dev/null 2>&1; then
		# catppuccin/tmux assigns both its palette (@thm_*) and its derived module
		# colours (@catppuccin_status_*_text_fg and friends) with `set -ogqF`:
		# -F bakes the colour to a literal hex at source time and -o then refuses
		# to overwrite it. So a plain re-source keeps the previous flavour. Clear
		# everything catppuccin-owned and let tmux.conf plus the plugin rebuild it.
		local opt
		while read -r opt; do
			[[ -n $opt ]] && tmux set -gu "$opt"
		done < <(tmux show -g 2>/dev/null | grep -oE '^@(thm|catppuccin)[a-z_0-9]*' || true)

		if tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1; then
			ok tmux "palette cleared and reloaded"
			any=1
		fi
	fi

	# Every nvim re-reads plugins/theme.lua on SIGUSR1 (the Signal autocmd
	# there). Both the TUI client and its --embed server survive the signal.
	if pgrep -x -U "$UID" nvim >/dev/null 2>&1 && pkill -USR1 -x -U "$UID" nvim; then
		ok nvim "signalled to reload the colorscheme"
		any=1
	fi

	((any)) || info "${DIM}nothing running to reload${RESET}"

	return 0
}

print_next_launch() {
	printf '\n%sApplies on next launch:%s\n' "$BOLD" "$RESET"
	info "${DIM}btop, rofi, wlogout, hyprlock${RESET}"
	info "${DIM}GTK3 apps read settings.ini at startup, so they need a restart${RESET}"
	info "${DIM}htop has no custom themes — it follows the terminal palette${RESET}"
}

main() {
	local arg=${1:-}

	case $arg in
	'')
		show_current
		exit 0
		;;
	-h | --help | help)
		usage
		exit 0
		;;
	esac

	local flavour
	case $arg in
	dark) flavour=dark ;;
	light) flavour=light ;;
	toggle)
		if [[ $(current_flavour || echo dark) == light ]]; then
			flavour=dark
		else
			flavour=light
		fi
		;;
	*)
		usage >&2
		die "unknown flavour: $arg"
		;;
	esac

	# "dark" -> "Gruvbox Dark", for messages and Windows Terminal's scheme name.
	local name="Gruvbox ${flavour^}"

	printf '%sSwitching to %s%s\n\n' "$BOLD" "$name" "$RESET"

	local label rel regex tmpl newline
	while IFS='|' read -r label rel regex tmpl; do
		[[ -n ${label:-} ]] || continue

		newline=${tmpl//@f@/$flavour}

		if [[ ! -f "$DOTFILES/$rel" ]]; then
			warn "$(printf '%-9s' "$label") $rel not found — skipped"
		elif replace_line "$DOTFILES/$rel" "$regex" "$newline"; then
			ok "$label" "$newline"
		else
			warn "$(printf '%-9s' "$label") no line matching /$regex/ in $rel — left alone"
		fi
	done < <(targets)

	apply_system_appearance "$flavour"
	apply_wallpaper
	reload_running_apps
	# After the reloads: PowerShell takes a second or two to start, and the
	# terminal side should not wait on it.
	apply_windows "$flavour"
	print_next_launch
}

main "$@"

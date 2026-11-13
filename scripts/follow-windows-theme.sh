#!/usr/bin/env bash
#
# Keep the Gruvbox flavour in step with Windows' light/dark mode, so the
# PowerToys Light Switch shortcut (Win + Ctrl + Shift + D) — or anything else
# that flips it — also switches tmux, nvim, btop and Windows Terminal.
#
# WSL only; runs as a systemd user service (services/follow-windows-theme.service).
# A PowerShell child blocks on RegNotifyChangeKeyValue and prints
# AppsUseLightTheme once at start and again on every change, so nothing polls.
# theme.sh sets the Windows mode too; when that change comes back round here
# the flavour already matches and nothing happens.

set -euo pipefail

DOTFILES="$(cd -- "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")/.." && pwd)"
THEME_SH="$DOTFILES/scripts/theme.sh"
MARKER="$DOTFILES/hypr/.config/hypr/modules/colors.lua"
POWERSHELL=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe

watcher=$(
	cat <<-'EOF'
		$ErrorActionPreference = 'Stop'
		$ProgressPreference = 'SilentlyContinue'  # else progress arrives as CLIXML on stderr
		Add-Type -Namespace Dotfiles -Name Advapi32 -MemberDefinition '[DllImport("advapi32.dll")] public static extern int RegNotifyChangeKeyValue(IntPtr hKey, bool watchSubtree, int notifyFilter, IntPtr hEvent, bool asynchronous);'

		$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')
		$changed = New-Object Threading.AutoResetEvent $false

		# The WSL side keeps stdin open for as long as it runs. EOF means it is
		# gone, so exit rather than linger as an orphaned Windows process.
		$stdin = [Console]::OpenStandardInput()
		$eof = $stdin.BeginRead((New-Object byte[] 1), 0, 1, $null, $null)

		$last = $null
		while ($true) {
			# Arm before reading, so a change in between is not missed.
			# 4 = REG_NOTIFY_CHANGE_LAST_SET
			$rc = [Dotfiles.Advapi32]::RegNotifyChangeKeyValue($key.Handle.DangerousGetHandle(), $false, 4, $changed.SafeWaitHandle.DangerousGetHandle(), $true)
			if ($rc -ne 0) { throw "RegNotifyChangeKeyValue failed: $rc" }

			$value = $key.GetValue('AppsUseLightTheme')
			if ($value -ne $last) {
				[Console]::Out.WriteLine($value)
				[Console]::Out.Flush()
				$last = $value
			}

			if ([Threading.WaitHandle]::WaitAny(@($changed, $eof.AsyncWaitHandle)) -eq 1) { exit 0 }
		}
	EOF
)

current_flavour() {
	sed -nE 's/^local active = "([a-z]+)".*/\1/p' "$MARKER" | head -1
}

# -EncodedCommand (UTF-16LE, base64) sidesteps quoting across the WSL boundary.
coproc WATCH {
	"$POWERSHELL" -NoProfile -NonInteractive -EncodedCommand \
		"$(printf '%s' "$watcher" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)"
}
# Bash unsets WATCH once the coproc exits; keep our own copy of its output.
exec {out}<&"${WATCH[0]}"

while IFS= read -r value <&"$out"; do
	value=${value%$'\r'}
	case $value in
	0) want=dark ;;
	1) want=light ;;
	*) continue ;;
	esac

	if [[ $(current_flavour) == "$want" ]]; then
		echo "Windows is in $want mode; already Gruvbox ${want^}"
		continue
	fi

	echo "Windows switched to $want mode"
	"$THEME_SH" "$want" || echo "theme.sh $want failed" >&2
done

echo "PowerShell watcher exited" >&2
exit 1

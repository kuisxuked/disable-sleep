import Foundation
import Darwin

struct OneClickAuthorization: Sendable {
    let userID: uid_t
    let runner: any CommandRunning

    init(userID: uid_t = getuid(), runner: any CommandRunning = SystemCommandRunner()) {
        self.userID = userID
        self.runner = runner
    }

    var rulePath: String { "/private/etc/sudoers.d/disablesleep-\(userID)" }
    var marker: String { "# Managed by Disable Sleep for UID \(userID)" }
    var rule: String {
        // Numeric UID syntax avoids placing account names into sudoers or shell code.
        "#\(userID) ALL = (root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
    }

    var isInstalled: Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: rulePath) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
            && (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == 0
            && (attributes[.posixPermissions] as? NSNumber)?.uint16Value == 0o440
    }

    func rootScript(enable: Bool) -> String {
        let preflight = """
        set -eu
        /usr/sbin/visudo -cf /private/etc/sudoers >/dev/null
        target='\(rulePath)'
        if [ -L "$target" ] || [ -d "$target" ]; then
            echo 'Refusing to replace an unexpected authorization file.' >&2
            exit 1
        fi
        if [ -e "$target" ]; then
            /usr/bin/grep -Fxq '\(marker)' "$target" || { echo 'Authorization file belongs to another tool.' >&2; exit 1; }
        fi
        """
        if !enable {
            return preflight + "\n/bin/rm -f \"$target\"\n"
        }
        return preflight + "\n" + """
        /usr/bin/grep -Eq '^[[:space:]]*[#@]includedir[[:space:]]+(/private)?/etc/sudoers[.]d([[:space:]]|$)' /private/etc/sudoers || { echo 'This Mac does not enable sudoers.d. No system settings were modified.' >&2; exit 1; }
        temporary=$(/usr/bin/mktemp /private/etc/sudoers.d/.disablesleep-\(userID).XXXXXX)
        trap '/bin/rm -f "$temporary"' EXIT
        /usr/bin/printf '%s\\n' '\(marker)' '\(rule)' > "$temporary"
        /usr/sbin/chown root:wheel "$temporary"
        /bin/chmod 0440 "$temporary"
        /usr/sbin/visudo -cf "$temporary" >/dev/null
        /bin/mv -f "$temporary" "$target"
        if ! /usr/sbin/visudo -cf /private/etc/sudoers >/dev/null; then
            /bin/rm -f "$target"
            echo 'Authorization validation failed; the new rule was removed.' >&2
            exit 1
        fi
        """
    }

    static func appleScript(shellCommand: String) -> String {
        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return """
        try
            do shell script "\(escaped)" with administrator privileges
        on error errorMessage number errorNumber
            if errorNumber is -128 then
                return "DISABLE_SLEEP_USER_CANCELLED"
            else
                error errorMessage number errorNumber
            end if
        end try
        """
    }

    func configure(enable: Bool) throws {
        let result = try runner.run("/usr/bin/osascript", arguments: ["-e", Self.appleScript(shellCommand: rootScript(enable: enable))])
        guard result.status == 0 else { throw SleepControlError.commandFailed(result.output) }
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "DISABLE_SLEEP_USER_CANCELLED" {
            throw SleepControlError.cancelled
        }
        guard isInstalled == enable else { throw SleepControlError.configurationFailed }
    }
}

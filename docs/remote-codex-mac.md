# Configure a Mac as a Codex Remote SSH Target

Configure this Mac so an approved client computer can connect over SSH using a
public key and launch Codex Remote from the selected macOS account's working
login shell.

Perform the setup safely, preserve existing access, and verify the completed
connection from the client and from the Codex desktop app.

## Desired outcome

- Use macOS Remote Login and the Mac account's native POSIX login shell.
- Install the client's public key only for the selected Mac account.
- Make the native macOS `codex` executable available through `PATH` in a fresh,
  non-interactive SSH session.
- Do not install WSL, a replacement SSH server, or a replacement login shell.
- Do not reboot or log out of the Mac.
- Do not expose SSH directly to the public internet. Use the existing trusted
  LAN or an approved VPN.
- Do not enable Full Disk Access, Accessibility, Automation, Screen Recording,
  or other macOS privacy permissions unless I explicitly approve each one.

## Safety rules

- Never request, display, copy, or transmit a private key.
- Never overwrite an existing `authorized_keys`, `known_hosts`, SSH
  configuration, or shell startup file.
- Do not disable password authentication until public-key login has been tested
  successfully from the client.
- Do not broaden Remote Login to all users when one selected account is enough.
- Before installing software, enabling Remote Login, changing firewall
  exposure, changing power settings, or granting a macOS privacy permission,
  describe the action and request approval.
- Prefer Ed25519 keys.
- Back up every file before modifying it.
- Append or make the smallest targeted edit; preserve existing keys and shell
  configuration.
- Validate SSH configuration before reloading or toggling Remote Login.
- If validation or a fresh-connection test fails, restore the backup.
- Keep the current local Codex or Terminal session open until a fresh SSH
  connection passes every verification step.
- Never ask me to paste a Mac login password, sudo password, private key, Codex
  token, or browser session into chat. If macOS requires interactive
  authorization, give me the exact local action and pause.

## Inspect first

Inspect and report without changing state:

1. macOS version and build:

   ```sh
   sw_vers
   uname -m
   ```

2. Computer name, local hostname, configured hostname if present, and relevant
   IPv4 and IPv6 addresses. Do not assume the active interface is `en0`.
3. Current local user and the proposed SSH login account.
4. Whether that account is an administrator.
5. The account's home directory, UID, primary group, and configured login shell.
6. Whether Remote Login is enabled, which users are allowed, and whether TCP
   port 22 is listening.
7. The macOS application-firewall state and any SSH-specific exposure that can
   be determined safely.
8. Whether `~/.ssh/authorized_keys` already exists, including its owner, mode,
   and number of nonblank records. Do not print existing keys.
9. Whether `codex` is installed and discoverable in all of these contexts:

   ```sh
   command -v codex && codex --version
   "$SHELL" -lc 'command -v codex && codex --version'
   ```

10. Existing SSH host-key types and SHA256 fingerprints. Read only public
    `.pub` host-key files; never read or display a private host key.
11. Whether the Mac is configured to sleep while unattended. Report this only;
    do not change power settings without approval.
12. Whether FileVault or other startup conditions would make SSH unavailable
    until somebody unlocks the Mac after a future restart. Do not restart.

## Request the connection details

Ask me for:

- The Mac account that should accept Codex Remote connections.
- The client computer's operating system.
- The client's complete public-key line, for example:

  ```text
  ssh-ed25519 AAAA... label
  ```

- Optional source restrictions for the key, such as a client IP or trusted VPN
  subnet, but only use options supported by this Mac's installed OpenSSH.
- Whether password login should remain enabled after public-key authentication
  has been verified. Default to leaving it unchanged.
- Whether this Mac needs remote access only on the local network or through an
  existing VPN.

## Validate the client public key

- Require exactly one public-key record.
- Accept modern key types such as `ssh-ed25519`.
- Reject private-key headers, multiline material, shell commands, malformed
  base64, and unrequested key options.
- Validate the record with the installed `ssh-keygen` using a securely created
  temporary file, then remove that temporary file.
- Show the public key's SHA256 fingerprint and ask for confirmation before
  installing it.

## Enable and restrict macOS Remote Login

Use Apple's built-in **Remote Login** service. Do not install another SSH
daemon.

1. If Remote Login is already enabled for the selected account, preserve it.
2. If it is disabled, describe the change and ask for approval.
3. Prefer the supported macOS interface:

   **System Settings > General > Sharing > Remote Login**

4. Configure **Allow access for: Only these users** and include the selected
   account. Do not choose **All users** unless I explicitly request it.
5. Leave **Allow full disk access for remote users** disabled unless I
   explicitly approve it after you explain why a required workflow needs it.
6. If a safe command-line method is available on this macOS release, show the
   exact command and request approval before running it. If macOS blocks the
   command through privacy controls, do not work around the control; ask me to
   use System Settings.
7. Do not reboot or log out. Enabling Remote Login should not require either.
8. Confirm that the system SSH daemon is listening after the change.

## Install the client's public key

Perform this work as the selected account whenever possible.

1. Create `~/.ssh` if necessary without replacing it.
2. Back up an existing `~/.ssh/authorized_keys` with its owner, permissions,
   and timestamp preserved.
3. Append the confirmed public-key record only if that exact key is not already
   present.
4. Apply these permissions:

   ```text
   ~/.ssh                  700
   ~/.ssh/authorized_keys  600
   ```

5. Ensure both paths are owned by the selected account and its primary group.
6. Do not remove or rewrite existing keys.
7. Report the installed key fingerprint and file location, but do not print the
   complete `authorized_keys` file.

## Make Codex available to the SSH shell

Codex Remote starts the remote Codex app server through the SSH user's login
shell. The `codex` command must be available on `PATH` in that environment.

1. Use the account's existing shell. Do not change it merely for Codex Remote.
2. If Codex is missing, stop and request approval for the specific official
   native macOS installation method. Do not invent an installer, install a
   second package manager, or copy authentication files from another computer.
3. Have the selected Mac user authenticate Codex interactively on this Mac.
   Never request or transfer their login token through chat.
4. Determine the actual Codex executable directory after installation.
5. Test both the login-shell environment and a real non-interactive SSH command.
6. If `PATH` needs adjustment, make the smallest idempotent change appropriate
   for the configured shell:

   - Back up the startup file first.
   - Preserve all existing content.
   - Do not add commands that print output during shell startup.
   - Do not assume `zsh`; inspect the configured shell.
   - Prefer a user-scoped path change over a system-wide change.

7. Validate locally:

   ```sh
   "$SHELL" -lc 'command -v sh; command -v codex; codex --version; [ -n "$HOME" ] && printf "POSIX_OK\n"'
   ```

8. Validate from a fresh client connection:

   ```sh
   ssh -o BatchMode=yes USER@HOST \
     'printf "SSH_OK\n"; command -v sh; command -v codex; codex --version; [ -n "$HOME" ] && printf "POSIX_OK\n"; printf "SHELL=%s\n" "$SHELL"'
   ```

9. If local login-shell validation succeeds but the real SSH test cannot find
   Codex, diagnose which startup files the actual SSH shell reads. Do not paper
   over the problem with a global symlink or system-file edit without approval.

## Validate SSH configuration

- Do not edit `/etc/ssh/sshd_config` merely to enable key authentication; use
  the existing macOS defaults when they satisfy the requirement.
- If an SSH configuration change is genuinely required, back up the affected
  file and prefer a supported included configuration file over rewriting
  Apple's main file.
- Validate the effective configuration with the installed `sshd` before any
  reload or Remote Login toggle.
- Keep password authentication unchanged until key-only login succeeds.
- Do not weaken host-key checking, accepted key algorithms, or authentication
  requirements to make a test pass.

## macOS privacy and GUI-access boundary

SSH access and Codex authentication do not automatically grant macOS privacy
permissions.

- Report whether the intended work may need access to protected folders or GUI
  applications.
- Treat Full Disk Access, Accessibility, Automation, Screen Recording, Camera,
  Microphone, Contacts, and similar permissions as separate grants.
- Do not enable any such permission preemptively.
- If a later workflow requires one, explain the exact capability, identify the
  process that needs permission, and ask me to grant it through System Settings.
- Verify the narrowly requested capability after I grant it.

## Configure network access

- Confirm SSH is listening on the expected interface and port.
- Prefer the existing trusted LAN or approved VPN.
- Do not create router port forwarding, UPnP mappings, public DNS, tunnels, or
  public listeners unless explicitly authorized.
- If a firewall change is necessary, describe its scope and request approval.
- Report the resulting hostname, IP addresses, port, and username.
- If the Mac sleeps, SSH and Codex Remote may become unavailable. Report that
  limitation and request approval before changing sleep or wake-for-network
  settings.

## Offer the Mac's host identity to the client

Read only the Mac's **public** SSH host keys. Prefer Ed25519 when available.

Display:

- Key type.
- SHA256 fingerprint.
- Computer name and local hostname.
- Configured hostname or FQDN, if present.
- Relevant IP addresses.
- Ready-to-install `known_hosts` records for every approved hostname and IP.
  Use `[host]:port` form when SSH uses a non-default port.

Never display or copy a private host key. Explain that I should verify the
fingerprint through this trusted local setup session before accepting it on the
client.

## Prepare the client

Provide commands appropriate to the client's operating system without executing
them unless the client is also explicitly in scope.

The client-side procedure must:

1. Create `~/.ssh` if necessary.
2. Back up the existing `known_hosts` file.
3. Append the verified `known_hosts` record without replacing existing entries.
4. Add a concrete alias to `~/.ssh/config`, for example:

   ```text
   Host monk-mac
     HostName MAC_HOST_OR_IP
     User MAC_USERNAME
     IdentityFile ~/.ssh/id_ed25519
     IdentitiesOnly yes
   ```

5. Include `Port` when SSH uses a non-default port.
6. Test strict host-key verification and key-only authentication:

   ```sh
   ssh -o BatchMode=yes -o StrictHostKeyChecking=yes monk-mac \
     'printf "SSH_OK\n"; command -v sh; command -v codex; codex --version; [ -n "$HOME" ] && printf "POSIX_OK\n"; printf "SHELL=%s\n" "$SHELL"'
   ```

Do not recommend `StrictHostKeyChecking=no`.

## Verification ceremony

1. Install the confirmed client public key for the selected Mac account.
2. Give me the Mac's host-key fingerprint and exact `known_hosts` record.
3. Pause while I install that host identity on the client.
4. Ask me to run the strict, key-only test from the client.
5. Do not disable password authentication yet.
6. After I confirm key-only login works, leave password authentication unchanged
   unless I explicitly request a reviewed hardening change.
7. Ask me to enable the concrete host alias in the Codex desktop app.
8. Confirm that Codex Remote starts its app server and can open a harmless test
   directory. Ordinary SSH success alone is not sufficient.
9. Confirm that the original local session still works before declaring success.

## Final report

Report:

- macOS version, build, and architecture.
- Computer name, local hostname, configured hostname, relevant IP addresses,
  and SSH port.
- Selected login account, UID, group, administrator status, home directory, and
  login shell.
- Installed client-key fingerprint.
- Mac SSH host-key fingerprint.
- Location, owner, and mode of `authorized_keys`.
- `codex` executable path and version as seen through a fresh SSH command.
- Remote Login state and allowed-user scope.
- Firewall and network scope.
- Whether password authentication remains enabled or unchanged.
- Any macOS privacy permissions explicitly granted; report `none` when none
  were granted.
- Sleep and post-restart availability limitations.
- Exact strict client test command.
- Backups created and files changed.
- Confirmation that no private key was transferred and the Mac was not rebooted
  or logged out.

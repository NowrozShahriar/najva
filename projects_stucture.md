## Authentication Flow

Users landing on the "/" route go through an HTTP plug pipeline containing: `AuthPlug` -> `RequireAuth`.

### 1. AuthPlug
This plug attempts to restore a user's session from long-term storage (cookies).

*   **Check**: Looks for `jid` and `ciphertext` in cookies.
*   **Restore**: Calls `Auth.restore_session/2`.
    *   *Backend Logic*: If the user's GenServer isn't running, it decrypts the ciphertext and starts a new session.
*   **Outcomes**:
    *   **Success**: 
        *   Put `jid` in the **Session Cookie** (signing it).
        *   Assign `current_user` for Heex templates.
        *   Redirect to "/" if the user is on `/login` or `/register`.
    *   **Timeout**:
        *   Assign `jid` (optimistically) as `current_user`.
        *   Does **not** write to the Session Cookie.
        *   Displays a "Connection Slow" warning.
    *   **Error** (Decryption/Start fail):
        *   Clear all cookies and session.
        *   Flash "Session Expired".
    *   **No Cookies**:
        *   Do nothing (pass through).

### 2. RequireAuth
This plug enforces authentication for protected routes.

*   **Check**: Verifies if the `jid` is present in the **Session Cookie**.
*   **Outcome**:
    *   **Present**: Allow request to proceed.
    *   **Missing**: Redirect to `/login` (Blocks users who only have cookies but failed/timed-out session restoration).



## Login Flow (SessionController)
When the user submits the `/login` form, a standard `POST` request is sent to `SessionController.login/2`.

*   **Action**: Calls `Auth.login/2` with the provided JID and password.
    *   *Backend Logic*:
        *   **If GenServer Running**: Sends password to the GenServer for verification.
        *   **If GenServer Stopped**: Attempts to start a new session.
    *   *Result*: Upon success, the GenServer returns a new ciphertext.
*   **Outcomes**:
    *   **Success**:
        *   Store `jid` and new `ciphertext` in long-term cookies.
        *   Redirect to `/`.
    *   **Failure**:
        *   Flash "Incorrect JID or Password".
        *   Redirect to `/login`.
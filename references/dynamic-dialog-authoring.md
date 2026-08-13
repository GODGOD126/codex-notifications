# Dynamic dialog authoring

The generated `dialog.ps1` is intentionally a complete program rather than a declarative UI schema. Edit it directly for the current task.

## Runtime files

Each request directory contains:

- `dialog.ps1`: freely editable popup program.
- `request.json`: initial context and defaults.
- `paper-texture.png`: optional warm-paper material.
- `result.json`: interaction result written by the popup.
- `waiting.json`: heartbeat maintained while Codex waits.

## Returning a result

Use an atomic write so the waiter never reads partial JSON:

```powershell
$result = @{
    action = 'submitted'
    value = $taskSpecificValue
    timestamp = [DateTimeOffset]::Now.ToString('o')
} | ConvertTo-Json -Depth 10

$temporary = "$ResultPath.tmp"
[IO.File]::WriteAllText($temporary, $result, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporary -Destination $ResultPath -Force
```

The bundled waiter considers `completed`, `submitted`, `confirmed`, `continue`, and `acknowledged` terminal by default. A custom action can be accepted with `wait-result.ps1 -AcceptAction <name>`.

## Interaction freedom

The copied program may use WPF, Windows Forms, WebView, local HTML, or another locally available Windows UI technique. It may add any task-appropriate controls and event logic. It does not need to preserve the starter layout.

One interaction is mandatory in every implementation: keep a secondary button labeled exactly **“我很忙，一会再说。”**. It must write `action: "deferred"` with a message that the user is currently busy and temporarily unable to answer, then close the popup. This action is non-terminal, so Codex must remain suspended and wait for the user's actual reply.

Default decision popups use 2–4 short choices plus a direct-reply input. A choice submits immediately. Put the text-send arrow inside the input's right edge; disable it for blank input and enable it when text exists. Clicking the arrow or pressing Enter submits a text-only reply. Do not add a separate submit button to a decision popup. Return both fields in the terminal result as `value.selectedOption` and `value.input`. Keep the title near 18 Chinese characters, the message to one sentence near 80 characters, and detailed context in the Codex conversation.

When changing technology, continue to:

1. display the window above ordinary windows as far as Windows permits;
2. write a clear result when the user completes the requested interaction;
3. distinguish completion from close or expiry;
4. keep the Codex turn waiting for longer than 20 minutes when no response arrives.

## Waiting discipline

Launching a GUI is not task completion. Run `wait-result.ps1` and keep the tool call alive. If it yields, resume the same process repeatedly rather than ending the Codex turn. A result returned through the popup or a direct user reply can resume the original task immediately.

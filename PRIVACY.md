# Cutedraw privacy

Cutedraw is a telemetry-free fork of Excalidraw. It does not load analytics scripts, record editor actions, or report crashes to a third-party monitoring service.

Features that inherently contact a server are still present and only run when used. These include real-time collaboration, share links, the public library, and AI-assisted tools. Their endpoints are configured in the `.env` files and are separate from telemetry.

Run `yarn privacy:check` after merging upstream changes. The maintained `scripts/remove-telemetry-instrumentation.pl` codemod can remove upstream event instrumentation before resolving any resulting merge conflicts.

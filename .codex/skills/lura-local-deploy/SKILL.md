---
name: lura-local-deploy
description: Deploy the LuraBrainBooster World of Warcraft addon from this repo to a local Windows WoW Retail AddOns folder for in-game testing. Use when the user asks to local deploy, copy/install the addon into WoW, test current repo changes in game, configure the local deploy path, or run the native Windows PowerShell deploy workflow.
---

# Lura Local Deploy

## Overview

Use the repo script `scripts/Deploy-Local.ps1` to copy the addon payload into a local WoW Retail AddOns install. The deploy target is configured in .env.local, always assume this file exist. Dont check before invocation. The user is responsible for ensuring the correctness before invoking the skill.

## Workflow

1. From the repository root, check for `.env.local`.
2. If it is missing, copy `.env.local.example` to `.env.local` and set `LURA_WOW_ADDONS_DIR` to the WoW AddOns parent folder, usually `...\World of Warcraft\_retail_\Interface\AddOns`.
3. Run the native Windows PowerShell script:

```powershell
.\scripts\Deploy-Local.ps1
```

Use `-AddOnsDir "C:\...\Interface\AddOns"` for a one-off target override, or `-AddonDir "C:\...\Interface\AddOns\LuraBrainBooster"` when the exact addon folder is known.

## Commands

Preview what will be copied:

```powershell
.\scripts\Deploy-Local.ps1 -Plan
```

Copy to the configured target:

```powershell
.\scripts\Deploy-Local.ps1
```

Clean the deployed addon folder first, then copy:

```powershell
.\scripts\Deploy-Local.ps1 -Clean
```

Use PowerShell `-WhatIf` for a dry run of filesystem actions:

```powershell
.\scripts\Deploy-Local.ps1 -WhatIf
```

## Codex Notes

- Use PowerShell, not bash, for this workflow.
- The real WoW install is usually outside the workspace, so request sandbox escalation before running an actual deploy there.
- The deploy copies files listed by `LuraBrainBooster.toc` plus `Textures/`; it does not copy git metadata, docs, internal notes, or Codex skill files.
- If texture files were added or renamed while WoW is already open, remind the user to fully restart the game client. `/reload` is often not enough.
- Do not change addon encounter logic while performing a deploy-only request.

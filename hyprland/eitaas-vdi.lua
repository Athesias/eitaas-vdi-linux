-- Optional Hyprland window rules for eitaas-vdi (Lua config, Hyprland 0.55+, including Omarchy).
-- Paste into a file your hyprland.lua loads (on Omarchy: ~/.config/hypr/windows.lua),
-- then run `hyprctl reload` and check that `hyprctl configerrors` prints nothing.

-- Float the sign-in window. It is a Chrome/Chromium --app window on the Azure US
-- Government login page, which a tiling layout would otherwise stretch across the screen.
hl.window_rule({
  name = "eitaas-vdi-signin",
  match = { class = "^chrom(e|ium)-login\\.microsoftonline\\.us__.*" },
  float = true,
  center = true,
  size = { 900, 820 },
})

-- Chrome's CAC PIN dialog maps with an empty class and the title
-- "Unlock Security Device", so rules that match the browser never apply to it.
hl.window_rule({
  name = "eitaas-vdi-cac-pin",
  match = { class = "^$", title = "^Unlock Security Device$" },
  float = true,
  center = true,
  size = { 640, 220 },
})

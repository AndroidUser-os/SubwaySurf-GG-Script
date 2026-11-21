-- Retro GG Script (2010s vibe: clean, minimal, interactive refine)
local MENU_TITLE = "=== SUBWAY RETRO TOOL ==="

local function pause_game()
  gg.processResume()
end

local function apply_edit(value_str, dword_type)
  local count = gg.getResultsCount()
  if count == 0 then
    gg.alert("Values not found. Check game state / region.")
    return false
  end
  local results = gg.getResults(count)
  for i, item in ipairs(results) do
    item.value = value_str
    item.flags = dword_type
  end
  gg.setValues(results)
  return true
end

local function wait_for_gg_tap()
  gg.setVisible(false)
  gg.toast("Change value in game, then tap GG icon")
  while not gg.isVisible(true) do
    gg.sleep(100)
  end
  gg.setVisible(false)
end

local function interactive_refine(item_label)
  local start_input = gg.prompt(
    {"Enter current " .. item_label .. " count:"},
    {""},
    {"number"}
  )
  if not start_input or not start_input[1] or start_input[1] == "" then
    return
  end

  gg.clearResults()
  gg.setRanges(gg.REGION_ANONYMOUS)
  gg.searchNumber(start_input[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)

  while true do
    local count = gg.getResultsCount()
    if count == 0 then
      gg.alert("0 results found. Search reset.")
      gg.clearResults()
      return
    end

    local action = gg.choice(
      {
        "1. Refine (Отсеять)",
        "2. Edit All (Изменить все)",
        "3. Cancel"
      },
      nil,
      item_label .. "  | Found: " .. tostring(count)
    )

    if action == nil or action == 3 then
      gg.clearResults()
      return
    elseif action == 1 then
      wait_for_gg_tap()
      local next_input = gg.prompt(
        {"Found: " .. tostring(count) .. "\nEnter new " .. item_label .. " count:"},
        {""},
        {"number"}
      )
      if next_input and next_input[1] and next_input[1] ~= "" then
        gg.refineNumber(next_input[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
      end
    elseif action == 2 then
      local target_input = gg.prompt(
        {"Found: " .. tostring(count) .. "\nSet new value for all:"},
        {"999999"},
        {"number"}
      )
      if target_input and target_input[1] and target_input[1] ~= "" then
        if apply_edit(target_input[1], gg.TYPE_DWORD) then
          pause_game()
          gg.alert("Done! Edited " .. tostring(count) .. " values to " .. target_input[1])
        end
        gg.clearResults()
        return
      end
    end
  end
end

local function coin_hack()
  gg.clearResults()
  gg.setRanges(gg.REGION_ANONYMOUS)
  gg.searchNumber("320000", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)

  if not apply_edit("-2100000000", gg.TYPE_DWORD) then
    return
  end

  pause_game()
  gg.alert("Done. Go to [ BOARD ] and buy [ LOWRIDER ].")
end

local function key_hack()
  gg.clearResults()
  gg.setRanges(gg.REGION_ANONYMOUS)
  gg.searchNumber("60000;3", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
  gg.refineNumber("3", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)

  if not apply_edit("4000000000", gg.TYPE_DWORD) then
    return
  end
  apply_edit("2100000000", gg.TYPE_DWORD)
  pause_game()

  gg.clearResults()
  gg.searchNumber("2100000000;60000", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
   gg.refineNumber("60000", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)

  if apply_edit("-2100000000", gg.TYPE_DWORD) then
    apply_edit("0", gg.TYPE_DWORD)
  end
  pause_game()

  gg.alert("Done. Run 1m and claim reward.")
end

local function speed_menu()
  local speeds = {
    "Speed 0.6",
    "Speed 0.8",
    "Speed 1.0 (Normal)",
    "Speed 1.5",
    "Custom speed"
  }
  local pick = gg.choice(speeds, nil, "SPEED CONTROL")
  if pick == nil then return end

  local val = nil
  if pick == 1 then val = 0.6
  elseif pick == 2 then val = 0.8
  elseif pick == 3 then val = 1.0
  elseif pick == 4 then val = 1.5
  elseif pick == 5 then
    local input = gg.prompt({"Enter speed (e.g. 0.75 or 1.2):"}, {"1.0"}, {"number"})
    if input and input[1] then
      val = tonumber(input[1])
    end
  end

  if val and val > 0 then
    gg.setSpeed(val)
    gg.toast("Speed: " .. tostring(val))
  end
end

local function show_menu()
  local items = {
    "1. Coin Hack",
    "2. Key Hack",
    "3. Score Booster (Refine)",
    "4. Any Boost / Item (Refine)",
    "5. Speedhack",
    "6. Clear Search Results",
    "7. Exit"
  }
  local choice = gg.choice(items, nil, MENU_TITLE)
  if choice == nil then return end

  if choice == 1 then
    coin_hack()
  elseif choice == 2 then
    key_hack()
  elseif choice == 3 then
    interactive_refine("Score Booster")
  elseif choice == 4 then
    interactive_refine("Boost / Item")
  elseif choice == 5 then
    speed_menu()
  elseif choice == 6 then
    gg.clearResults()
    gg.toast("Results cleared")
  elseif choice == 7 then
    gg.setVisible(true)
    os.exit()
  end
end

gg.setVisible(false)
while true do
  if gg.isVisible(true) then
    gg.setVisible(false)
    show_menu()
  end
  gg.sleep(100)
end


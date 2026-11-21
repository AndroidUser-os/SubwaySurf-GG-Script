-- ===================================================
-- SUBWAY SURFERS v1.1.10 (TOKYO) - ULTIMATE PRO SCRIPT
-- Автор: Твой AI-напарник & NFSFan
-- ===================================================

if gg.isVisible(true) then gg.setVisible(false) end

local BYTE, WORD, DWORD = gg.TYPE_BYTE, gg.TYPE_WORD, gg.TYPE_DWORD
local PTR_MASK = 0xFFFFFFFFFFFF
local METADATA_MAGIC = -89056337
local META_RANGES = gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS | gg.REGION_C_HEAP | gg.REGION_C_DATA | gg.REGION_C_BSS | gg.REGION_OTHER | gg.REGION_CODE_APP
local CLASS_RANGES = gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS | gg.REGION_C_HEAP | gg.REGION_C_BSS | gg.REGION_OTHER

local KLASS_NAME, KLASS_NAMESPACE, KLASS_PARENT, KLASS_SELF = 0x10, 0x18, 0x58, 0x78
local KLASS_FIELDS, KLASS_METHODS = 0x80, 0x98
local FIELDINFO_SIZE, FIELDINFO_PARENT, FIELDINFO_OFFSET = 0x20, 0x10, 0x18
local METHOD_NAME, METHOD_KLASS = 0x18, 0x20
local DICT_ENTRIES, DICT_COUNT, DICT_ENTRY_SIZE = 0x18, 0x20, 0x18
local DICT_ENTRY_KEY, DICT_ENTRY_VALUE = 0x8, 0x10
local IAP_CURRENCY = 10

local metadataCandidates = {}
local metadataPinned = nil
local classCache, fieldCache = {}, {}

local target_val = ""
local target_type = ""
local target_type_u = ""
local target_type_p = ""
local initial_search_val = ""
local menu = nil
local sub_menu = nil
local action = nil
local count = 0

gg.toast("Subway Surfers v1.1.10 Pro Script Запущен!")
gg.alert('Subway Surfers v1.1.10 Pro Hack Menu\nНажми на ОК чтобы попасть в меню\n\nи Привет в хак меню сабвея! :)')

local function read(addr, vtype) return gg.getValues({{address = addr, flags = vtype}})[1].value or 0 end
local function write(addr, value, vtype) gg.setValues({{address = addr, flags = vtype, value = value}}) end
local function readPtr(addr) if not addr or addr == 0 then return 0 end return read(addr, gg.TYPE_QWORD) & PTR_MASK end
local function readByte(addr) return read(addr, BYTE) & 0xFF end
local function toSigned32(v) if v >= 0x80000000 then return v - 0x100000000 end return v end
local function readBytes(addr, count)
    local req = {}
    for i = 0, count - 1 do req[i + 1] = {address = addr + i, flags = BYTE} end
    local out = {}
    for i, v in ipairs(gg.getValues(req)) do out[i] = (v.value or 0) & 0xFF end
    return out
end
local function cstrEquals(addr, str)
    if addr == 0 then return false end
    local bytes = readBytes(addr, #str + 1)
    for i = 1, #str do if bytes[i] ~= str:byte(i) then return false end end
    return bytes[#str + 1] == 0
end
local function readCString(addr, max)
    if addr == 0 then return "" end
    local chars = {}
    for _, b in ipairs(readBytes(addr, max or 64)) do
        if b == 0 then break end
        chars[#chars + 1] = string.char(b)
    end
    return table.concat(chars)
end
local function search(text, vtype, ranges, from, to)
    gg.clearResults()
    gg.setRanges(ranges)
    gg.searchNumber(text, vtype, false, gg.SIGN_EQUAL, from or 0, to or -1)
end
local function takeResults(limit)
    local count = gg.getResultsCount()
    local results = count > 0 and gg.getResults(math.min(count, limit or 5000)) or {}
    gg.clearResults()
    return results
end

local function findMetadata()
    local starts = {}
    for _, r in ipairs(gg.getRangesList("global-metadata.dat")) do starts[#starts + 1] = r.start end
    if #starts == 0 then
        search(tostring(METADATA_MAGIC), DWORD, META_RANGES)
        for _, r in ipairs(takeResults(200)) do starts[#starts + 1] = r.address end
    end
    metadataCandidates = {}
    for _, base in ipairs(starts) do
        if read(base, DWORD) == METADATA_MAGIC then
            local version = read(base + 0x4, DWORD)
            local stringsOffset, stringsSize = read(base + 0x18, DWORD), read(base + 0x1C, DWORD)
            if version >= 24 and version <= 40 and stringsOffset > 0 and stringsSize > 0 then
                metadataCandidates[#metadataCandidates + 1] = {
                    strings = base + stringsOffset,
                    stringsEnd = base + stringsOffset + stringsSize,
                }
            end
        end
    end
    return #metadataCandidates > 0
end

local function findMetadataStrings(meta, name)
    local group = {"0"}
    for i = 1, #name do group[#group + 1] = tostring(name:byte(i)) end
    group[#group + 1] = "0"
    search(table.concat(group, ";").."::"..(#name + 2), BYTE, META_RANGES, meta.strings, meta.stringsEnd)
    gg.refineNumber(tostring(name:byte(1)), BYTE)
    local found = {}
    for _, r in ipairs(takeResults()) do
        if readByte(r.address - 1) == 0 and cstrEquals(r.address, name) then found[#found + 1] = r.address end
    end
    return found
end

local function findClassIn(meta, namespace, name)
    for _, str in ipairs(findMetadataStrings(meta, name)) do
        search(tostring(toSigned32(str & 0xFFFFFFFF)), DWORD, CLASS_RANGES)
        for _, r in ipairs(takeResults(20000)) do
            if r.address % 8 == 0 and readPtr(r.address) == str then
                local klass = r.address - KLASS_NAME
                if readPtr(klass + KLASS_SELF) == klass and cstrEquals(readPtr(klass + KLASS_NAMESPACE), namespace) then
                    return klass
                end
            end
        end
    end
    return nil
end

local function findClass(namespace, name)
    local key = namespace.."."..name
    if classCache[key] then return classCache[key] end
    for _, meta in ipairs(metadataPinned and {metadataPinned} or metadataCandidates) do
        local klass = findClassIn(meta, namespace, name)
        if klass then
            metadataPinned = meta
            classCache[key] = klass
            return klass
        end
    end
    return nil
end

local function className(klass) return readCString(readPtr(klass + KLASS_NAME)) end

local function fieldOffset(klass, name)
    local key = klass..":"..name
    if fieldCache[key] then return fieldCache[key] end
    local k = klass
    for _ = 1, 8 do
        if k == 0 then break end
        local fields = readPtr(k + KLASS_FIELDS)
        if fields ~= 0 then
            for i = 0, 511 do
                local field = fields + i * FIELDINFO_SIZE
                if readPtr(field + FIELDINFO_PARENT) ~= k then break end
                if cstrEquals(readPtr(field), name) then
                    fieldCache[key] = read(field + FIELDINFO_OFFSET, DWORD)
                    return fieldCache[key]
                end
            end
        end
        k = readPtr(k + KLASS_PARENT)
    end
    return 0
end

local function fieldAddr(obj, name) return obj + fieldOffset(readPtr(obj), name) end
local function fieldObj(obj, name) return readPtr(fieldAddr(obj, name)) end
local function staticFieldObj(klass, name)
    local statics = readPtr(klass + 0xB8)
    if statics == 0 then return 0 end
    return readPtr(statics + fieldOffset(klass, name))
end

local function dictEntries(dict)
    local out = {}
    if dict == 0 then return out end
    local entries = readPtr(dict + DICT_ENTRIES)
    for i = 0, read(dict + DICT_COUNT, DWORD) - 1 do
        local entry = entries + 0x20 + i * DICT_ENTRY_SIZE
        local value = readPtr(entry + DICT_ENTRY_VALUE)
        if value ~= 0 then out[#out + 1] = {entry = entry, value = value} end
    end
    return out
end

local function dictFindByClass(dict, name)
    for _, e in ipairs(dictEntries(dict)) do
        if cstrEquals(readPtr(readPtr(e.value) + KLASS_NAME), name) then return e.value end
    end
    return 0
end

local SubwayGameData = 0
local CoreRunnerManager = 0
local function resolveGameObjects()
    local gameDataLocator = findClass("SYBO.Subway", "GameDataLocator")
    local managerLocator = findClass("SYBO.Subway", "ManagerLocator")
    if gameDataLocator then
        SubwayGameData = dictFindByClass(staticFieldObj(gameDataLocator, "_models"), "SubwayGameData")
    end
    if managerLocator then
        CoreRunnerManager = dictFindByClass(staticFieldObj(managerLocator, "_managers"), "CoreRunnerManager")
    end
    return SubwayGameData ~= 0
end

findMetadata()
pcall(resolveGameObjects)

goto START_MENU

::START_MENU::
if gg.isVisible(true) then gg.setVisible(false) end
menu = gg.choice({
    "⚡ 1. Монеты: Максимум (999,999,999)",
    "🔑 2. Ключи: Максимум (99,999)",
    "🏆 3. Рекорд (Score): Максимум (99,999,999)",
    "📈 4. Множитель очков (Score Multiplier)",
    "🛹 5. Доски (Hoverboard): Максимум (99,999)",
    "⭐ 6. Score Booster: Максимум (99,999)",
    "🚀 7. Mega Headstart: Максимум (99,999)",
    "🏷️ 8. Цены Персонажей/Досок: Сделать по 1 монете",
    "🔓 9. Разблокировать Персонажа: Сделать цену 0",
    "🛍️ 10. Бесплатные внутриигровые покупки (Kill IAP)",
    "⚙️ 11. ➡️ ДОПОЛНИТЕЛЬНОЕ МЕНЮ (Свои значения)",
    "🙈 12. Скрыть меню (Открыть кликом по GG)",
    "❌ 13. Выход в лаунчер"
}, nil, "=== Subway Surfers v1.1.10 (Tokyo) ===")

if menu == nil or menu == 13 then goto CLOSE_SCRIPT end

if menu == 1 then 
    target_val = "999999999"
    target_type = "Монеты"
    goto START_SEARCH 
end

if menu == 2 then 
    target_val = "99999"
    target_type = "Ключи"
    goto START_SEARCH 
end

if menu == 3 then 
    target_val = "99999998"
    target_type = "Рекорд (Score)"
    goto START_SEARCH 
end

if menu == 4 then 
    goto SCORE_MULTIPLIER_MAIN
end

if menu == 5 then 
    target_val = "99999"
    target_type = "Доски (Hoverboard)"
    goto START_SEARCH 
end

if menu == 6 then 
    target_val = "99999"
    target_type = "Score Booster"
    goto START_SEARCH 
end

if menu == 7 then 
    target_val = "99999"
    target_type = "Mega Headstart"
    goto START_SEARCH 
end

if menu == 8 then 
    target_val = "1"
    target_type_p = "Цена Персонажа/Доски"
    goto START_SEARCH_P
end

if menu == 9 then
    target_val = "0"
    target_type_u = "Разблокировать Персонажа"
    goto START_SEARCH_UNLOCK
end

if menu == 10 then
    goto FREE_IAP
end

if menu == 11 then goto CUSTOM_MENU end

if menu == 12 then
    goto HIDE_AND_WAIT_MAIN
end

::SCORE_MULTIPLIER_MAIN::
do
    pcall(resolveGameObjects)
    local input_mult = gg.prompt({"Введите желаемый множитель очков:"}, {"999"}, {"number"})
    if input_mult == nil or input_mult[1] == "" then goto START_MENU end
    
    if CoreRunnerManager ~= 0 then
        local runMult = fieldObj(CoreRunnerManager, "RunMultiplier")
        if runMult ~= 0 then
            write(fieldAddr(runMult, "_totalMultiplier"), input_mult[1], DWORD)
            gg.toast("✅ Множитель очков успешно установлен!")
            goto START_MENU
        end
    end
    
    -- Запасной поиск через память, если менеджер еще не создан
    gg.clearResults()
    gg.setRanges(gg.REGION_ANONYMOUS | gg.REGION_C_HEAP)
    gg.searchNumber(input_mult[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
    local count = gg.getResultCount()
    if count > 0 and count < 300 then
        gg.getResults(count)
        gg.editAll(input_mult[1], gg.TYPE_DWORD)
        gg.toast("✅ Множитель очков изменен!")
        gg.clearResults()
    else
        gg.clearResults()
        gg.searchNumber("30;50", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
        gg.alert("💡 Множитель запущен через поиск. Измените его в забеге для точного отсева.")
    end
end
goto START_MENU

::CUSTOM_MENU::
if gg.isVisible(true) then gg.setVisible(false) end
sub_menu = gg.choice({
    "💰 1. Монеты на СВОЁ число",
    "🔑 2. Ключи на СВОЁ число",
    "🏆 3. Рекорд (Score) на СВОЁ число",
    "📈 4. Множитель очков на СВОЁ число",
    "🛹 5. Доски на СВОЁ число",
    "⭐ 6. Score Booster на СВОЁ число",
    "🚀 7. Mega Headstart на СВОЁ число",
    "🏷️ 8. Цена Персонажа/Доски на СВОЁ число",
    "🙈 9. Скрыть меню (Открыть кликом по GG)",
    "⬅️ 10. Назад в Главное Меню"
}, nil, "=== Дополнительное Меню ===")

if sub_menu == nil or sub_menu == 10 then goto START_MENU end

if sub_menu == 9 then
    goto HIDE_AND_WAIT_CUSTOM
end

if sub_menu == 4 then
    do
        pcall(resolveGameObjects)
        local input_custom = gg.prompt({"Введите желаемый множитель очков:"}, {"500"}, {"number"})
        if input_custom ~= nil and input_custom[1] ~= "" then
            if CoreRunnerManager ~= 0 then
                local runMult = fieldObj(CoreRunnerManager, "RunMultiplier")
                if runMult ~= 0 then
                    write(fieldAddr(runMult, "_totalMultiplier"), input_custom[1], DWORD)
                    gg.toast("✅ Множитель изменен на " .. input_custom[1] .. "!")
                    goto START_MENU
                end
            end
            gg.clearResults()
            gg.setRanges(gg.REGION_ANONYMOUS | gg.REGION_C_HEAP)
            gg.searchNumber(input_custom[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
            local cnt = gg.getResultCount()
            if cnt > 0 and cnt < 300 then
                gg.getResults(cnt)
                gg.editAll(input_custom[1], gg.TYPE_DWORD)
                gg.toast("✅ Множитель изменен на " .. input_custom[1] .. "!")
                gg.clearResults()
            else
                gg.clearResults()
                gg.alert("❌ Запустите забег перед изменением множителя.")
            end
        end
    end
    goto START_MENU
end

do
    local custom_prompts = {
        {name = "Монеты", def = "500000"},
        {name = "Ключи", def = "1000"},
        {name = "Рекорд (Score)", def = "1234567"},
        {name = "Множитель очков", def = "999"},
        {name = "Доски (Hoverboard)", def = "5000"},
        {name = "Score Booster", def = "500"},
        {name = "Mega Headstart", def = "500"},
        {name = "Цена Персонажа/Доски", def = "10"}
    }

    local p = custom_prompts[sub_menu]
    if sub_menu > 4 then
        p = custom_prompts[sub_menu - 1]
    end

    local input_custom = gg.prompt({"Введите текущее значение в игре:", "Введите желаемое число (" .. p.name .. "):"}, {"0", p.def}, {"number", "number"})

    if input_custom == nil or input_custom[1] == "" or input_custom[2] == "" then 
        goto CUSTOM_MENU 
    end

    initial_search_val = input_custom[1]
    target_val = input_custom[2]
    target_type = p.name
end

goto START_SEARCH_CUSTOM

::HIDE_AND_WAIT_MAIN::
gg.toast("Меню свернуто. Нажми иконку GG для открытия.")
gg.setVisible(false)
while not gg.isVisible() do gg.sleep(100) end
goto START_MENU

::HIDE_AND_WAIT_CUSTOM::
gg.toast("Меню свернуто. Нажми иконку GG для открытия.")
gg.setVisible(false)
while not gg.isVisible() do gg.sleep(100) end
goto CUSTOM_MENU

::FREE_IAP::
do
    pcall(resolveGameObjects)
    if SubwayGameData == 0 then
        gg.alert("⛔ Данные игры не найдены. Откройте магазин и повторите.")
        goto START_MENU
    end
    gg.toast("Взлом внутриигровых покупок...")
    local products = fieldObj(fieldObj(SubwayGameData, "Products"), "Products")
    local modified = 0
    for _, e in ipairs(dictEntries(products)) do
        local cost = fieldObj(e.value, "Cost")
        if cost ~= 0 and read(fieldAddr(cost, "CurrencyType"), DWORD) == IAP_CURRENCY then
            write(fieldAddr(cost, "CurrencyType"), 0, DWORD)
            write(fieldAddr(cost, "Value"), 0, DWORD)
            modified = modified + 1
        end
    end
    gg.alert(modified == 0 and "Покупки не найдены." or "✔ Внутриигровые покупки теперь бесплатны!")
end
goto START_MENU

::START_SEARCH::
do
    local input_val = gg.prompt({"Введите текущее количество валюты / цену (" .. target_type .. ") в игре:"}, {"0"}, {"number"})
    if input_val == nil or input_val[1] == "" then goto START_MENU end
    initial_search_val = input_val[1]
end

::START_SEARCH_CUSTOM::
gg.clearResults()
gg.setRanges(gg.REGION_ANONYMOUS)
gg.searchNumber(initial_search_val, gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
goto CHECK_RESULTS

::START_SEARCH_UNLOCK::
do
    local input_val = gg.prompt({"Введите текущее количество цены (" .. target_type_u .. ") в игре:"}, {"0"}, {"number"})
    if input_val == nil or input_val[1] == "" then goto START_MENU end
    initial_search_val = input_val[1]
end
gg.clearResults()
gg.setRanges(gg.REGION_ANONYMOUS)
gg.searchNumber(initial_search_val, gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
goto CHECK_RESULTS_U

::CHECK_RESULTS_U::
count = gg.getResultCount()
if count == 0 then gg.alert("❌ Ничего не найдено!"); goto START_MENU end
if gg.isVisible(true) then gg.setVisible(false) end
action = gg.alert("Найдено совпадений: " .. count, "Изменить Все", "Отмена")
if action == 1 then
    gg.getResults(count)
    gg.editAll(target_val, gg.TYPE_DWORD)
    gg.toast("✅ Успешно изменено!")
    gg.clearResults()
end
goto START_MENU

::START_SEARCH_P::
do
    local input_val = gg.prompt({"Введите текущее количество цены (" .. target_type_p .. ") в игре:"}, {"0"}, {"number"})
    if input_val == nil or input_val[1] == "" then goto START_MENU end
    initial_search_val = input_val[1]
end
gg.clearResults()
gg.setRanges(gg.REGION_ANONYMOUS)
gg.searchNumber(initial_search_val, gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
goto CHECK_RESULTS_P

::CHECK_RESULTS_P::
count = gg.getResultCount()
if count == 0 then gg.alert("❌ Ничего не найдено!"); goto START_MENU end
if gg.isVisible(true) then gg.setVisible(false) end
action = gg.alert("Найдено совпадений: " .. count, "Изменить Все", "Отмена")
if action == 1 then
    gg.getResults(count)
    gg.editAll(target_val, gg.TYPE_DWORD)
    gg.toast("✅ Успешно изменено!")
    gg.clearResults()
end
goto START_MENU

::CHECK_RESULTS::
count = gg.getResultCount()
if count == 0 then gg.alert("❌ Ничего не найдено!"); goto START_MENU end
if gg.isVisible(true) then gg.setVisible(false) end
action = gg.alert("Найдено совпадений: " .. count, "Изменить Все", "Отсеять")
if action == 1 then
    gg.getResults(count)
    gg.editAll(target_val, gg.TYPE_DWORD)
    gg.toast("✅ Успешно изменено!")
    gg.clearResults()
    goto START_MENU
elseif action == 2 then
    gg.toast("Измените число в игре и откройте GG.")
    gg.setVisible(false)
    while not gg.isVisible() do gg.sleep(100) end
    local refine_input = gg.prompt({"Введите НОВОЕ число:"}, {"0"}, {"number"})
    if refine_input ~= nil and refine_input[1] ~= "" then
        gg.refineNumber(refine_input[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1)
    end
    goto CHECK_RESULTS
end
goto START_MENU

::CLOSE_SCRIPT::
gg.setVisible(true)
gg.toast("Возврат в лаунчер...")
return


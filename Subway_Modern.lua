-- ===================================================
-- SUBWAY SURFERS - MODERN SCRIPT (IL2CPP)
-- ===================================================

if gg.isVisible(true) then gg.setVisible(false) end

local BYTE, WORD, DWORD = gg.TYPE_BYTE, gg.TYPE_WORD, gg.TYPE_DWORD
local FLOAT, QWORD = gg.TYPE_FLOAT, gg.TYPE_QWORD
local PTR_MASK = 0xFFFFFFFFFFFF
local METADATA_MAGIC = -89056337

local META_RANGES = gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS | gg.REGION_C_HEAP | gg.REGION_C_DATA | gg.REGION_C_BSS | gg.REGION_OTHER | gg.REGION_CODE_APP
local CLASS_RANGES = gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS | gg.REGION_C_HEAP | gg.REGION_C_BSS | gg.REGION_OTHER

local KLASS_NAME, KLASS_SELF, KLASS_FIELDS = 0x10, 0x78, 0x80
local FIELDINFO_SIZE, FIELDINFO_PARENT, FIELDINFO_OFFSET = 0x20, 0x10, 0x18
local ARRAY_DATA = 0x20
local DICT_ENTRIES, DICT_COUNT, DICT_ENTRY_SIZE = 0x18, 0x20, 0x18
local DICT_ENTRY_KEY, DICT_ENTRY_VALUE = 0x8, 0x10
local SAFEINT_VALUE = 0x4
local IAP_CURRENCY = 10

local function promptNumber(text, default)
    local input = gg.prompt({text}, {default}, {"number"})
    return input and input[1]
end

local function read(addr, vtype)
    return gg.getValues({{address = addr, flags = vtype}})[1].value or 0
end

local function write(addr, value, vtype)
    gg.setValues({{address = addr, flags = vtype, value = value}})
end

local function readPtr(addr)
    if not addr or addr == 0 then return 0 end
    return read(addr, QWORD) & PTR_MASK
end

local function readByte(addr)
    return read(addr, BYTE) & 0xFF
end

local function toSigned32(v)
    if v >= 0x80000000 then return v - 0x100000000 end
    return v
end

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
    for i = 1, #str do
        if bytes[i] ~= str:byte(i) then return false end
    end
    return bytes[#str + 1] == 0
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

local metadataCandidates = {}
local metadataPinned = nil
local classCache, fieldCache = {}, {}

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
    local strList = findMetadataStrings(meta, name)
    for _, str in ipairs(strList) do
        search(tostring(toSigned32(str & 0xFFFFFFFF)), DWORD, CLASS_RANGES)
        local resList = takeResults(20000)
        for _, r in ipairs(resList) do
            if r.address % 8 == 0 and readPtr(r.address) == str then
                local klass = r.address - KLASS_NAME
                if readPtr(klass + KLASS_SELF) == klass and cstrEquals(readPtr(klass + 0x18), namespace) then
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
        k = readPtr(k + 0x58)
    end
    error("Field '"..name.."' not found")
end

local function fieldAddr(obj, name)
    if obj == 0 then error("Not available right now.") end
    return obj + fieldOffset(readPtr(obj), name)
end

local function fieldObj(obj, name)
    return readPtr(fieldAddr(obj, name))
end

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
        local entry = entries + ARRAY_DATA + i * DICT_ENTRY_SIZE
        local value = readPtr(entry + DICT_ENTRY_VALUE)
        if value ~= 0 then out[#out + 1] = {entry = entry, value = value} end
    end
    return out
end

local function dictFindByClass(dict, name)
    local entries = dictEntries(dict)
    for _, e in ipairs(entries) do
        if cstrEquals(readPtr(readPtr(e.value) + KLASS_NAME), name) then return e.value end
    end
    return 0
end

local ProfileModel = 0
local SubwayGameData = 0
local CoreRunnerManager = 0

local function resolveGameObjects()
    local profileLocator = findClass("SYBO.Subway", "ProfileModelLocator")
    local gameDataLocator = findClass("SYBO.Subway", "GameDataLocator")
    local managerLocator = findClass("SYBO.Subway", "ManagerLocator")
    if not (profileLocator and gameDataLocator and managerLocator) then return false end
    ProfileModel = dictFindByClass(staticFieldObj(profileLocator, "_models"), "ProfileModel")
    SubwayGameData = dictFindByClass(staticFieldObj(gameDataLocator, "_models"), "SubwayGameData")
    CoreRunnerManager = dictFindByClass(staticFieldObj(managerLocator, "_managers"), "CoreRunnerManager")
    return ProfileModel ~= 0 and SubwayGameData ~= 0 and CoreRunnerManager ~= 0
end

gg.toast("⏳ Инициализация IL2CPP...")
if not findMetadata() then
    gg.alert("⛔ global-metadata.dat не найден!")
    return
end
for _ = 1, 30 do
    if pcall(resolveGameObjects) and ProfileModel ~= 0 then break end
    gg.sleep(1000)
end

local function currencySafeInt(currencyType)
    local currencies = fieldObj(fieldObj(ProfileModel, "Wallet"), "Currencies")
    local entries = dictEntries(currencies)
    for _, e in ipairs(entries) do
        if read(e.entry + DICT_ENTRY_KEY, DWORD) == currencyType then
            local ok, addr = pcall(fieldAddr, e.value, "Value")
            return ok and addr or e.value + 0x10
        end
    end
    return nil
end

local function setVal(currencyType, defVal)
    local val = promptNumber("Введите желаемое значение:", defVal)
    if not val then return end
    local safeInt = currencySafeInt(currencyType)
    if not safeInt then
        gg.toast("Валюта еще не инициализирована в игре.")
        return
    end
    write(safeInt, 0, DWORD)
    write(safeInt + SAFEINT_VALUE, val, DWORD)
    gg.toast("✅ Успешно изменено!")
end

-- Точный хак множителя очков через CoreRunnerManager (как в проф. скрипте)
local function setScoreMultiplier(defVal)
    local multiplier = promptNumber("Введите желаемый множитель очков:", defVal or "999")
    if not multiplier then return end
    if CoreRunnerManager == 0 then
        gg.alert("⛔ Менеджер забега не найден. Начните забег!")
        return
    end
    local runMultiplierObj = fieldObj(CoreRunnerManager, "RunMultiplier")
    if runMultiplierObj == 0 then
        gg.alert("⛔ Запустите забег перед изменением множителя.")
        return
    end
    local addr = fieldAddr(runMultiplierObj, "_totalMultiplier")
    write(addr, multiplier, DWORD)
    gg.toast("✅ Множитель очков успешно установлен!")
end

local function killIAP()
    local products = fieldObj(fieldObj(SubwayGameData, "Products"), "Products")
    local modified = 0
    local entries = dictEntries(products)
    for _, e in ipairs(entries) do
        local cost = fieldObj(e.value, "Cost")
        if cost ~= 0 and read(fieldAddr(cost, "CurrencyType"), DWORD) == IAP_CURRENCY then
            write(fieldAddr(cost, "CurrencyType"), 0, DWORD)
            write(fieldAddr(cost, "Value"), 0, DWORD)
            modified = modified + 1
        end
    end
    gg.alert(modified == 0 and "Покупки не найдены." or "✔ Внутриигровые покупки теперь бесплатны!")
end

while true do
    local menu = gg.choice({
        "⚡ 1. Монеты: Максимум (999,999,999)",
        "🔑 2. Ключи: Максимум (99,999)",
        "📈 3. Множитель очков (Score Multiplier)",
        "🛹 4. Доски (Hoverboard): Максимум (99,999)",
        "⭐ 5. Score Booster: Максимум (99,999)",
        "🚀 6. Mega Headstart: Максимум (99,999)",
        "🏷️ 7. Цены Персонажей/Досок: Сделать по 1 монете",
        "🔓 8. Разблокировать Персонажа: Сделать цену 0",
        "🛍️ 9. Бесплатные внутриигровые покупки (Kill IAP)",
        "⚙️ 10. ➡️ ДОПОЛНИТЕЛЬНОЕ МЕНЮ (Свои значения)",
        "🙈 11. Скрыть меню (Открыть кликом по GG)",
        "❌ 12. Выход в лаунчер"
    }, nil, "=== Subway Surfers (Modern IL2CPP) ===")

    if menu == nil or menu == 12 then
        break
    elseif menu == 1 then
        setVal(1, "999999999")
    elseif menu == 2 then
        setVal(2, "99999")
    elseif menu == 3 then
        setScoreMultiplier("999")
    elseif menu == 4 then
        setVal(3, "99999")
    elseif menu == 5 then
        setVal(5, "99999")
    elseif menu == 6 then
        setVal(4, "99999")
    elseif menu == 7 or menu == 8 then
        gg.alert("Эта функция работает в старой версии скрипта.")
    elseif menu == 9 then
        killIAP()
    elseif menu == 10 then
        local sub = gg.choice({
            "💰 1. Монеты на СВОЁ число",
            "🔑 2. Ключи на СВОЁ число",
            "📈 3. Множитель очков на СВОЁ число",
            "🛹 4. Доски на СВОЁ число",
            "⭐ 5. Score Booster на СВОЁ число",
            "🚀 6. Mega Headstart на СВОЁ число",
            "🏷️ 7. Цена Персонажа/Доски на СВОЁ число",
            "🙈 8. Скрыть меню",
            "⬅️ 9. Назад в Главное Меню"
        }, nil, "=== Дополнительное Меню ===")

        if sub == 1 then setVal(1, "500000")
        elseif sub == 2 then setVal(2, "1000")
        elseif sub == 3 then setScoreMultiplier("500")
        elseif sub == 4 then setVal(3, "5000")
        elseif sub == 5 then setVal(5, "500")
        elseif sub == 6 then setVal(4, "500")
        elseif sub == 7 then gg.alert("Изменение цен доступно в старой версии скрипта.")
        elseif sub == 8 then
            gg.toast("Меню свернуто. Нажми иконку GG для открытия.")
            gg.setVisible(false)
            while not gg.isVisible() do gg.sleep(100) end
        end
    elseif menu == 11 then
        gg.toast("Меню свернуто. Нажми иконку GG для открытия.")
        gg.setVisible(false)
        while not gg.isVisible() do gg.sleep(100) end
    end
end


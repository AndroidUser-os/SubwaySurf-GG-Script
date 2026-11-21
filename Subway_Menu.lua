-- ===================================================
-- SUBWAY SURFERS - UNIVERSAL LAUNCHER
-- ===================================================

if gg.isVisible(true) then gg.setVisible(false) end

local function launchScript(defaultPath, versionTitle)
    local input = gg.prompt(
        {"Введите полный путь к файлу (" .. versionTitle .. "):"},
        {defaultPath},
        {"text"}
    )

    if not input or input[1] == "" then
        gg.toast("Запуск отменен.")
        return
    end

    local path = input[1]
    local file = io.open(path, "r")
    if not file then
        gg.alert("❌ Ошибка: Файл не найден по пути:\n" .. path)
        return
    else
        file:close()
        gg.toast("🚀 Запуск " .. versionTitle .. "...")
        -- Используем pcall, а внутри модулей вместо os.exit() будет return
        local success, err = pcall(dofile, path)
        if not success and err and not string.match(err, "os.exit") then
            gg.alert("⚠️ Ошибка выполнения скрипта:\n" .. tostring(err))
        end
    end
end

while true do
    local mode = gg.choice({
        "🚀 Современная версия (IL2CPP)",
        "📌 Старая версия (Поиск & Отсев)",
        "❌ Выход из лаунчера"
    }, nil, "=== Subway Surfers Master Launcher ===")

    if mode == 1 then
        launchScript("/storage/emulated/0/Download/Subway/Subway_Modern.lua", "Современной версии")
    elseif mode == 2 then
        launchScript("/storage/emulated/0/Download/Subway/Subway_Old.lua", "Старой версии")
    else
        gg.toast("Лаунчер завершил работу.")
        os.exit()
    end
end


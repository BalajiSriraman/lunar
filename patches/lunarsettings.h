#pragma once
#include <QSettings>
#include <QLockFile>
#include <QDir>
#include <QStandardPaths>

static bool importLunarSettings(QSettings& source, QSettings& destination)
{
    source.setFallbacksEnabled(false);
    destination.setFallbacksEnabled(false);
    if (destination.contains("lunarImportComplete")) return true;
    if (destination.allKeys().isEmpty()) {
        for (const auto& key : source.allKeys()) destination.setValue(key, source.value(key));
        destination.sync();
        if (destination.status() != QSettings::NoError) return false;
    }
    destination.setValue("lunarImportComplete", true);
    destination.sync();
    return destination.status() == QSettings::NoError;
}

static bool configureLunarSettings()
{
    QSettings source(QSettings::NativeFormat, QSettings::UserScope, "moonlight-stream.com", "Moonlight");
    source.setFallbacksEnabled(false);
    QCoreApplication::setOrganizationName("Lunar");
    QCoreApplication::setOrganizationDomain("lunar.balaji.com");
    QCoreApplication::setApplicationName("engine");
    QSettings destination;
    destination.setFallbacksEnabled(false);
    if (destination.contains("lunarImportComplete")) return true;
    auto directory = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    if (!QDir().mkpath(directory)) return false;
    QLockFile lock(directory + "/lunar-settings-import.lock");
    if (!lock.tryLock(10000)) return false;
    destination.sync();
    return importLunarSettings(source, destination);
}

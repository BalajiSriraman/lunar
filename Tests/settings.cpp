#include <QCoreApplication>
#include <QTemporaryDir>
#include <QFile>
#include "../patches/lunarsettings.h"
#include <cstdio>

#define CHECK(expression) do { if (!(expression)) { fprintf(stderr, "FAIL line %d\n", __LINE__); return 1; } } while (false)
int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    QTemporaryDir directory;
    CHECK(directory.isValid());
    QSettings source(directory.filePath("source.ini"), QSettings::IniFormat);
    QSettings target(directory.filePath("target.ini"), QSettings::IniFormat);
    source.setValue("key", QByteArray("test-private-key"));
    source.setValue("certificate", QByteArray("test-certificate"));
    source.setValue("uniqueid", "test-identity");
    source.setValue("hosts/1/hostname", "test-host");
    source.sync();
    CHECK(importLunarSettings(source, target));
    for (const auto& key : source.allKeys()) CHECK(source.value(key) == target.value(key));
    source.setValue("key", QByteArray("changed"));
    CHECK(importLunarSettings(source, target));
    CHECK(target.value("key").toByteArray() == "test-private-key");
    QSettings existing(directory.filePath("existing.ini"), QSettings::IniFormat);
    existing.setValue("key", QByteArray("keep-existing"));
    CHECK(importLunarSettings(source, existing));
    CHECK(existing.value("key").toByteArray() == "keep-existing");
    CHECK(!existing.contains("certificate"));
    QSettings absent(directory.filePath("absent.ini"), QSettings::IniFormat);
    QSettings fresh(directory.filePath("fresh.ini"), QSettings::IniFormat);
    CHECK(importLunarSettings(absent, fresh));
    CHECK(fresh.value("lunarImportComplete").toBool());
    CHECK(!fresh.contains("key"));
    CHECK(source.value("key").toByteArray() == "changed");
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, directory.path());
    QSettings fallback(QSettings::IniFormat, QSettings::UserScope, "fake-org", "");
    fallback.setValue("fps", "Inherited");
    fallback.sync();
    QSettings scopedSource(QSettings::IniFormat, QSettings::UserScope, "fake-org", "empty");
    QSettings scopedTarget(QSettings::IniFormat, QSettings::UserScope, "fake-org", "owned");
    CHECK(scopedTarget.contains("fps"));
    CHECK(importLunarSettings(scopedSource, scopedTarget));
    CHECK(!scopedTarget.contains("fps"));
    CHECK(scopedTarget.allKeys() == QStringList{"lunarImportComplete"});
    QCoreApplication::setOrganizationDomain("lunar.balaji.com");
    QCoreApplication::setOrganizationName("Lunar");
    QCoreApplication::setApplicationName("engine");
    QSettings names;
    CHECK(names.fileName().endsWith("com.balaji.lunar.engine.plist"));
    CHECK(names.organizationName() != "dev.balaji.lunar");
    puts("PASS: identity import, import once, existing settings, empty source, source preserved, domain");
}

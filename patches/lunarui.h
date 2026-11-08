#pragma once

#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QTimer>
#include <atomic>
#include <memory>
#include <functional>

// The native frontend owns all connection UI. The Session renderer is unchanged.
static void lunarEvent(const QString& type, const QString& message = {})
{
    static QMutex mutex;
    QMutexLocker lock(&mutex);
    auto data = QJsonDocument(QJsonObject{{"type", type}, {"message", message}}).toJson(QJsonDocument::Compact);
    fwrite(data.constData(), 1, data.size(), stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

#ifdef Q_OS_MACOS
void installLunarMenu(std::function<void()> quit, std::function<void()> close);
#endif

static void startLunarUI(QGuiApplication& app, CliStartStream::Launcher* launcher,
                         StreamingPreferences* preferences)
{
    app.setQuitOnLastWindowClosed(false);
    auto manager = new ComputerManager(preferences);
    manager->setParent(&app);
    auto window = new QQuickWindow();
    window->setGeometry(100, 100, 1040, 680);
    auto failed = std::make_shared<std::atomic_bool>(false);
    auto finish = [&app](int code) {
        QMetaObject::invokeMethod(&app, [code] { QCoreApplication::exit(code); }, Qt::QueuedConnection);
    };
    auto reportError = [failed](QString message) {
        failed->store(true);
        lunarEvent("error", message);
    };
    QObject::connect(launcher, &CliStartStream::Launcher::searchingComputer, &app,
                     [] { lunarEvent("progress", "Connecting to computer…"); });
    QObject::connect(launcher, &CliStartStream::Launcher::searchingApp, &app,
                     [] { lunarEvent("progress", "Loading applications…"); });
    QObject::connect(launcher, &CliStartStream::Launcher::failed, &app,
                     [reportError, finish](QString message) { reportError(message); finish(1); });
    QObject::connect(launcher, &CliStartStream::Launcher::appQuitRequired, &app,
                     [reportError, finish](QString name) {
        reportError(QString("%1 is already running on this computer. Close it before you start another application.").arg(name));
        finish(1);
    });
    QObject::connect(launcher, &CliStartStream::Launcher::sessionCreated, &app,
                     [&app, window, failed, finish, reportError](QString, Session* session) {
        QObject::connect(session, &Session::stageStarting, &app,
                         [](QString stage) { lunarEvent("progress", "Starting " + stage + "…"); }, Qt::DirectConnection);
        QObject::connect(session, &Session::stageFailed, &app,
                         [reportError](QString stage, int code, QString ports) {
            auto text = QString("%1 failed (error %2).").arg(stage).arg(code);
            if (!ports.isEmpty()) text += " Check ports: " + ports;
            reportError(text);
        }, Qt::DirectConnection);
        QObject::connect(session, &Session::displayLaunchError, &app, reportError, Qt::DirectConnection);
        QObject::connect(session, &Session::connectionStarted, &app,
                         [] { lunarEvent("connected"); }, Qt::DirectConnection);
        QObject::connect(session, &Session::quitStarting, &app,
                         [] { lunarEvent("progress", "Closing remote application…"); }, Qt::DirectConnection);
        QObject::connect(session, &Session::readyForDeletion, &app,
                         [session, failed, finish] {
            lunarEvent("finished");
            session->deleteLater();
            finish(failed->load() ? 1 : 0);
        });
        lunarEvent("progress", "Preparing video and audio…");
        if (!session->initialize(window)) {
            if (!failed->load()) reportError("Video or audio could not start. Check the stream settings.");
            session->deleteLater();
            finish(1);
            return;
        }
#ifdef Q_OS_MACOS
        auto disconnect = [] {
            qInfo("Lunar stream disconnect requested");
            if (auto session = Session::get()) session->interrupt();
            else QCoreApplication::quit();
        };
        installLunarMenu([disconnect] { qInfo("Lunar quit requested"); lunarEvent("quit"); disconnect(); }, disconnect);
#endif
        for (const auto& warning : session->property("launchWarnings").toStringList()) {
            lunarEvent("warning", warning);
        }
        QTimer::singleShot(0, session, [session] { session->start(); });
    });
    launcher->execute(manager);
}

static void startLunarPairing(QGuiApplication& app, CliPair::Launcher* launcher)
{
    app.setQuitOnLastWindowClosed(false);
    auto manager = new ComputerManager(StreamingPreferences::get());
    manager->setParent(&app);
    QObject::connect(launcher, &CliPair::Launcher::searchingComputer, &app,
                     [] { lunarEvent("progress", "Looking for the computer…"); });
    QObject::connect(launcher, &CliPair::Launcher::pairing, &app,
                     [](QString, QString) { lunarEvent("progress", "Enter the PIN in Sunshine on your computer."); });
    QObject::connect(launcher, &CliPair::Launcher::failed, &app,
                     [&app](QString message) { lunarEvent("error", message); app.exit(1); });
    QObject::connect(launcher, &CliPair::Launcher::success, &app, [&app, manager] {
        QTimer::singleShot(0, &app, [&app, manager] {
            delete manager; // Finish the upstream host flush before the UI reloads settings.
            QSettings settings;
            settings.sync();
            if (settings.status() != QSettings::NoError) {
                lunarEvent("error", "Lunar could not save the paired computer.");
                app.exit(1);
                return;
            }
            lunarEvent("paired");
            app.exit(0);
        });
    });
    launcher->execute(manager);
}

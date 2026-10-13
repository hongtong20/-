QT += core gui
QT -= widgets

CONFIG += c++11 console
CONFIG -= app_bundle
TEMPLATE = app
TARGET = tiff_processor_cpp

SOURCES += \
    src/main.cpp \
    src/RasterProcessor.cpp

HEADERS += \
    src/RasterProcessor.h

# ---------- 平台自适应 GDAL 配置 ----------
# Windows: 用环境变量 GDAL_ROOT 指定 GDAL 安装根目录, 默认 D:/anaconda/Library
win32 {
    GDAL_ROOT = $$(GDAL_ROOT)
    isEmpty(GDAL_ROOT) {
        GDAL_ROOT = D:/anaconda/Library
    }
    INCLUDEPATH += $$GDAL_ROOT/include
    LIBS += -L$$GDAL_ROOT/lib -lgdal
    QMAKE_CXXFLAGS += /utf-8
    LIBS += user32.lib
}

# Linux/macOS: 用系统包管理安装的 GDAL, 通过 gdal-config 自动获取参数
unix {
    CONFIG += link_pkgconfig
    PKGCONFIG += gdal
}

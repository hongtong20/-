# 遥感反照率处理工具 C++11 版 (Linux CLI)

## 功能

本版本专为 Linux (银河麒麟 V10 / Ubuntu 等) 终端命令行使用，去除了图形界面，提供两种查询模式：

- **`query` 模式（默认）**：S2 + MODIS 融合查询
- **`gf` 模式**：GF（高分）单数据源查询

- 给定中心经纬度、半径(km)、目标日期，统计圆域内的反照率均值/最大/最小值，以及吸收率 (1 - 反照率)。
- **S2 优先 + MODIS 补缺**：圆内每个像元上，若 S2 有有效值则取 S2，否则取 MODIS。S2 与 MODIS 各自独立取"与目标日期最近的可用数据"，不要求二者同日。
- 中心落在 S2 边缘、圆域部分超出 S2 覆盖范围时，自动落空的像元用 MODIS 填充，输出 `source_used = "mixed"`。
- 同时统计多波段 TIFF 中每个波段的反射率均值。
- 结果以 JSON 输出到 stdout。

## 技术依赖

- Qt 5 (Core + Gui 模块；Gui 仅用于历史结构体字段，不依赖 X server)
- GDAL 运行时与开发库
- C++11 编译器 (g++ ≥ 5 即可)

## Linux (银河麒麟 V10 / Ubuntu) 编译

```bash
sudo apt update
sudo apt install -y build-essential qt5-qmake qtbase5-dev libgdal-dev

cd 源码
qmake tiff_processor_cpp.pro
make -j$(nproc)
```

生成的可执行文件为当前目录下的 `tiff_processor_cpp`。

> 若 `qmake` 命令对应的是 Qt6，请改用 `qmake-qt5`，或安装 `qtbase5-dev` 后用 `qt5-qmake` 的完整路径。

## 运行

```bash
./tiff_processor_cpp --mode query \
  --root   /data/地物地貌 \
  --region 20 \
  --lat    34.20084 \
  --lon    -118.36481 \
  --radius_km 10 \
  --date   20250102
```

参数说明：

| 参数 | 含义 |
|------|------|
| `--mode query` | 运行模式（默认 query；旧版的 api/export 仍可传入，会自动收敛到 query） |
| `--root` | 数据根目录，其下应包含 `Sentinel-2-10m/<region>/` 和一个含 `modis` 关键字的目录 |
| `--region` | S2 的区域编号目录名（例如 `20`） |
| `--lat` / `--lon` | 查询圆心纬度 / 经度（度） |
| `--radius_km` | 圆域半径，单位公里 |
| `--date` | 目标日期，`YYYYMMDD`；若当天无数据则取最近的可用日期 |

### 数据目录约定

- **S2**：`<root>/Sentinel-2-10m/<region>/` 下存放 `*albedo*.tif` 与 `*image*.tif`（多波段）。
- **MODIS**：代码会在 `<root>` 下自动搜索名称包含 `modis` (不区分大小写) 的目录，目录下应直接含 `*albedo*.tif` 与 `*image*.tif`。

### JSON 输出示例

```json
{
  "status": "success",
  "input": { "lat": 34.2, "lon": -118.36, "radius_km": 10, "date": "20250102", "region": "20" },
  "source_used": "mixed",
  "s2":    { "date": "20250103", "coverage_ratio": 0.62, "albedo_file": "...", "image_file": "..." },
  "modis": { "date": "20250101", "albedo_file": "...", "image_file": "..." },
  "albedo": {
    "mean": 0.234, "min": 0.102, "max": 0.451,
    "absorption_mean": 0.766, "absorption_min": 0.549, "absorption_max": 0.898,
    "valid_pixels": 9821, "total_pixels": 10000
  },
  "reflectance": { "band1": 0.123, "band2": 0.234, "band3": 0.345 }
}
```

错误时 `status = "error"`，`message` 写入原因，进程返回码 1。

---

## GF 模式（高分数据单独查询）

用于查询 GF（高分）数据，**不与 S2/MODIS 融合**，只读取 `<root>/GF-2m/<region>/` 下的 TIFF。

```bash
./tiff_processor_cpp --mode gf \
  --root   /data/地物地貌 \
  --region 20 \
  --lat    34.20084 \
  --lon    -118.36481 \
  --radius_km 5 \
  --date   20250102
```

### GF 模式行为说明

- 参数与 `query` 完全一致，只是 `--mode gf`。
- 仅读取 `<root>/GF-2m/<region>/` 目录下的 `*albedo*.tif` 与 `*image*.tif`。
- **自动归一化**：GF 数据通常以放大 10000 倍的整数存储，当代码检测到像元值 > 10 时，自动除以 10000 还原为真实反照率/反射率。
- JSON 输出中 `source_used` 恒为 `"gf"`；`s2.date` / `s2.albedo_file` 字段在 GF 模式下表示实际命中的 GF 文件；`modis` 字段为空。
- 反射率波段数取决于 GF image TIFF 的波段数（GF-2 通常 4 波段：B/G/R/NIR）。

### 数据目录约定（GF）

```
<data-root>/
└── GF-2m/
    └── <region>/
        ├── ...albedo...20250102.tif
        └── ...image...20250102.tif
```

## 跨平台说明

- 源代码全部基于 Qt + GDAL，无 Windows 专有 API 调用。
- 旧的 GUI 源文件 (`MainWindow.*` / `ImageCanvas.*` / `ExportRenderer.*`) 仍保留在 `src/` 目录中，但已从 `tiff_processor_cpp.pro` 的 SOURCES/HEADERS 列表中移除，不参与编译。如需在 Windows 上恢复 GUI，把它们加回 `.pro` 并改回 `QT += widgets` 即可。
- `XlsxWriter` 仍参与编译但当前模式不调用，便于将来扩展。

## Windows 上编译 (可选)

仍然可用 MSVC + Qt + GDAL，旧 bat 脚本 (`generate_vs_project.bat` 等) 仍可参考，但当前默认入口为 query CLI 模式。

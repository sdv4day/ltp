# Deimos-LTP 依赖设置

## avro-d 依赖

本项目依赖 [avro-d](https://github.com/sdv4day/avro-d) 库来处理 Avro 格式的模型文件。

### 快速设置

运行以下命令自动设置依赖：

```bash
# 1. 克隆 avro-d 仓库
git clone https://github.com/sdv4day/avro-d.git

# 2. 注册为本地包（推荐）
dub add-local /path/to/avro-d
```

### 详细说明

#### 方法 1：使用 dub add-local（推荐）

这是 Dub 官方推荐的 Git 仓库依赖管理方式。

1. 克隆 avro-d 仓库到任意位置：
   ```bash
   git clone https://github.com/sdv4day/avro-d.git
   ```

2. 使用 `dub add-local` 注册：
   ```bash
   dub add-local /path/to/avro-d
   ```

3. 项目会自动使用注册的本地包。

**优点**：
- ✅ 官方推荐方式
- ✅ 可以放在任意位置
- ✅ 支持多个项目共享
- ✅ 更新方便（只需 git pull）

#### 方法 2：使用本地路径

修改 `dub.json` 中的路径：

```json
{
    "dependencies": {
        "avro-d": {
            "path": "/path/to/your/avro-d"
        }
    }
}
```

**优点**：
- ✅ 简单直接
- ✅ 路径明确

**缺点**：
- ❌ 每个开发者需要修改路径
- ❌ 不利于团队协作

#### 方法 3：使用 Git 仓库依赖（不推荐）

虽然 Dub 支持 Git 仓库依赖，但当前版本（1.41.0）存在 bug：
```
core.exception.AssertError: getPackagePath called in bare mode
```

建议等待 Dub 修复此 bug 后再使用。

### 项目结构

使用 `dub add-local` 后的推荐结构：

```
anywhere/
├── avro-d/            # avro-d 仓库
│   ├── dub.sdl
│   └── source/
│
projects/
├── deimos-ltp/        # 本项目
│   ├── dub.json
│   ├── source/
│   └── model/
└── other-project/     # 其他项目也可以使用
    └── dub.json       # 同样依赖 avro-d
```

### 构建

```bash
cd deimos-ltp
dub build --compiler=ldc2
```

### 测试

```bash
dub run --single testa/final_test.d --compiler=ldc2
```

### 更新 avro-d

```bash
cd /path/to/avro-d
git pull
```

Dub 会自动检测到更新。

## 常见问题

### Q: 为什么不直接使用 Git 仓库依赖？

A: Dub 当前版本（1.41.0）在处理 Git 仓库依赖时存在 bug，导致构建失败。使用 `dub add-local` 是官方推荐的替代方案。

### Q: 多个项目如何共享 avro-d？

A: 使用 `dub add-local` 注册后，所有项目都可以使用同一个 avro-d，无需重复克隆。

### Q: 如何查看已注册的本地包？

A: 运行 `dub list` 可以查看所有已注册的包。

### Q: 如何移除本地包注册？

A: 运行 `dub remove-local /path/to/avro-d` 可以移除注册。

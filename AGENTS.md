# AGENTS.md

## Build and test commands

- Run `dub build --compiler=ldc2` after any code change.
- Run `dub test --compiler=ldc2` before finishing.
- If `dub` is not found, the environment setup is broken and must be fixed.

## 测试档案编写方式
在`testdemo.d`代码文件的头部插入
```D
/+ dub.sdl:
    name "test"
    dependency "deimos-ltp" version="*" path="../"
+/
```

使用 `dub run --single  .\testdemo.d`
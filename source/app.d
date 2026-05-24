import std.stdio;
import std.getopt;
import std.file;
import std.array;
import std.range;
import std.string;  // for splitLines
import etc.ltp.iface;  // 导入统一接口

import etc.ltp.ltpcloud;  // 导入云端分析器
import etc.ltp.native.ltp;  // 导入本地分析器

// ==================== 辅助函数 ====================

/**
 * 显示帮助信息
 */
void showHelp() {
    writeln("LTP 中文自然语言处理工具");
    writeln();
    writeln("用法:");
    writeln("  ltp [选项]");
    writeln();
    writeln("选项:");
    writeln("  -s, --string TEXT     分析指定的字符串");
    writeln("  -f, --file FILE       分析指定的文件（每行一个句子）");
    writeln("  -i, --stdin           从标准输入读取");
    writeln("  -o, --output FILE     输出到指定文件（默认输出到控制台）");
    writeln("  -m, --model-dir DIR   模型目录路径（默认: model）");
    writeln("  -c, --cloud           使用云端 API 进行分析（无需本地模型）");
    writeln("      --api-url URL     云端 API 地址（默认: https://ltp-ltp.hf.space/api）");
    writeln("      --proxy URL       代理服务器地址（仅云端模式）");
    writeln("      --timeout SECS    请求超时时间（秒，默认: 30）");
    writeln("  -h, --help            显示此帮助信息");
    writeln();
    writeln("示例:");
    writeln(`  ltp -s "我爱北京"                    # 本地模式`);
    writeln(`  ltp -s "我爱北京" -c                 # 云端模式`);
    writeln(`  ltp -f input.txt -o output.json      # 本地模式，文件输入`);
    writeln(`  ltp -f input.txt -c -o output.json   # 云端模式，文件输入`);
    writeln(`  echo "你好世界" | ltp -i             # 从标准输入读取`);
}

/**
 * 读取文本文件，每行作为一个句子
 */
string[] readTextFile(string filePath) {
    string content = cast(string)std.file.read(filePath);
    string[] lines;
    
    foreach (line; content.splitLines()) {
        if (line.length > 0) {
            lines ~= line;
        }
    }
    
    return lines;
}

/**
 * 从标准输入读取文本
 */
string[] readFromStdin() {
    string[] lines;
    
    foreach (line; stdin.byLineCopy) {
        if (line.length > 0) {
            lines ~= line;
        }
    }
    
    return lines;
}

/**
 * 保存结果到文件
 */
void saveToFile(string content, string filePath) {
    std.file.write(filePath, content);
    writeln("结果已保存到: ", filePath);
}

//version(Have_ltp_cli)
void main(string[] args) {
	version(Windows){
		import core.sys.windows.windows;
		SetConsoleCP(65001);
		SetConsoleOutputCP( 65001 );
	}
    
    try {
        string inputString;
        string inputFile;
        bool useStdin;
        string outputFile;
        string modelDir = "model";
        bool showHelpFlag;
        
        // 云端模式参数
        bool useCloud = false;
        string apiUrl = "https://ltp-ltp.hf.space/api";
        string proxyUrl;
        double timeout = 30.0;
        
        // 解析命令行参数
        auto helpInformation = getopt(
            args,
            std.getopt.config.passThrough,
            "s|string", &inputString,
            "f|file", &inputFile,
            "i|stdin", &useStdin,
            "o|output", &outputFile,
            "m|model-dir", &modelDir,
            "c|cloud", &useCloud,
            "api-url", &apiUrl,
            "proxy", &proxyUrl,
            "timeout", &timeout,
            "h|help", &showHelpFlag,
        );
        
        if (showHelpFlag) {
            showHelp();
            return;
        }
        
        // 检查是否提供了输入源
        if (inputString.length == 0 && inputFile.length == 0 && !useStdin) {
            writeln("错误: 请指定输入源（-s、-f 或 -i）");
            showHelp();
            return;
        }
        
        // 创建分析器（使用统一接口）
        ILTPAnalyzer analyzer;
        
        if (useCloud) {
            // 云端模式
            writeln("正在连接云端 API...");
            writeln("API 地址: ", apiUrl);
            auto cloudAnalyzer = new LTPAnalyzerCloud(apiUrl, timeout);
            
            if (proxyUrl.length > 0) {
                writeln("代理服务器: ", proxyUrl);
                cloudAnalyzer.setProxy(proxyUrl);
            }
            
            analyzer = cloudAnalyzer;
            writeln("云端 API 连接成功。");
        } else {
            // 本地模式
            writeln("正在加载模型...");
            writeln("模型目录: ", modelDir);
            analyzer = new LTPAnalyzer(modelDir);
            writeln("模型加载完成。");
        }
        writeln();
        
        UnifiedAnalysisResult[] results;
        
        // 处理字符串输入
        if (inputString.length > 0) {
            writeln("分析字符串: \"", inputString, "\"");
            results = analyzer.analyzeBatch([inputString]);
        }
        // 处理文件输入
        else if (inputFile.length > 0) {
            if (!std.file.exists(inputFile)) {
                writeln("错误: 文件不存在: ", inputFile);
                return;
            }
            
            writeln("读取文件: ", inputFile);
            string[] lines = readTextFile(inputFile);
            writeln("读取到 ", lines.length, " 行文本");
            writeln("正在分析...");
            results = analyzer.analyzeBatch(lines);
        }
        // 处理标准输入
        else if (useStdin) {
            string[] lines = readFromStdin();
            if (lines.length == 0) {
                writeln("没有输入内容。");
                return;
            }
            writeln("读取到 ", lines.length, " 行文本");
            writeln("正在分析...");
            results = analyzer.analyzeBatch(lines);
        }
        
        // 生成 JSON 结果
        string jsonOutput = unifiedResultsToJSON(results);
        
        // 输出结果
        if (outputFile.length > 0) {
            saveToFile(jsonOutput, outputFile);
        } else {
            writeln();
            writeln("分析结果:");
            writeln(jsonOutput);
        }
        
    } catch (Exception e) {
        writeln("错误: ", e.msg);
        writeln(e.info);
    }
}

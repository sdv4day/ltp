/**
 * LTP 统一分析器
 *
 * 提供完整的 NLP 分析流水线
 */
module etc.ltp.native.ltp;

import std.string;
import std.array;
import std.file : exists;
import std.path : buildPath;
import etc.ltp.native.model;
import etc.ltp.native.cws;
import etc.ltp.native.pos;
import etc.ltp.native.ner;
import etc.ltp.iface;

/**
 * LTP 分析结果
 */
struct LTPResult {
    string text;
    string[] words;
    string[] posTags;
    string[] nerTags;
    EntityResult[] entities;

    /**
     * 转换为字符串
     */
    string toString() const {
        auto app = appender!string;
        app ~= "Text: " ~ text ~ "\n";
        app ~= "Words: " ~ join(words, "/") ~ "\n";
        if (posTags.length > 0) {
            app ~= "POS: " ~ join(posTags, "/") ~ "\n";
        }
        if (entities.length > 0) {
            app ~= "Entities:\n";
            foreach (e; entities) {
                app ~= format("  %s (%s) [%d-%d]\n", e.text, e.entityType, e.start, e.end);
            }
        }
        return app.data;
    }
    
    /**
     * 转换为统一分析结果
     */
    UnifiedAnalysisResult toUnified() const {
        UnifiedAnalysisResult result;
        result.text = this.text;
        result.words.reserve(this.words.length);
        result.entities.reserve(this.entities.length);

        foreach (i, word; this.words) {
            UnifiedWord w;
            w.text = word;
            if (i < this.posTags.length) {
                w.pos = this.posTags[i];
            }
            if (i < this.nerTags.length) {
                w.entity = this.nerTags[i];
            }
            result.words ~= w;
        }

        foreach (entity; this.entities) {
            UnifiedNamedEntity e;
            e.text = entity.text;
            e.type = entity.entityType;
            e.offset = cast(int)entity.start;
            e.length = cast(int)(entity.end - entity.start);
            result.entities ~= e;
        }

        return result;
    }
}

/**
 * LTP 统一分析器类
 *
 * 整合 CWS、POS、NER 功能
 * 实现 ILTPAnalyzer 统一接口
 */
class LTPAnalyzer : ILTPAnalyzer {
private:
    CWSAnalyzer cws;
    POSAnalyzer pos;
    NERAnalyzer ner;
    string modelDir;

    void ensureCWSLoaded() {
        if (!cws.isLoaded()) loadCWS();
    }

    void ensurePOSLoaded() {
        if (!pos.isLoaded()) loadPOS();
    }

    void ensureNERLoaded() {
        if (!ner.isLoaded()) loadNER();
    }

    void loadModel(string basePath, void delegate(string) loader) {
        foreach (ext; [".bin", ".json"]) {
            string fullPath = basePath ~ ext;
            if (exists(fullPath)) {
                loader(fullPath);
                return;
            }
        }
        throw new Exception("Model file not found: " ~ basePath ~ ".bin or .json");
    }

public:
    /**
     * 构造函数
     *
     * 参数:
     *   modelDir: 模型目录路径
     */
    this(string modelDir = "model") {
        this.modelDir = modelDir;
        cws = new CWSAnalyzer();
        pos = new POSAnalyzer();
        ner = new NERAnalyzer();
    }

    /**
     * 加载所有模型
     */
    void loadAll() {
        loadCWS();
        loadPOS();
        loadNER();
    }

    /**
     * 加载 CWS 模型
     */
    void loadCWS() {
        string basePath = buildPath(modelDir, "cws_model");
        loadModel(basePath, &cws.load);
    }

    /**
     * 加载 POS 模型
     */
    void loadPOS() {
        string basePath = buildPath(modelDir, "pos_model");
        loadModel(basePath, &pos.load);
    }

    /**
     * 加载 NER 模型
     */
    void loadNER() {
        string basePath = buildPath(modelDir, "ner_model");
        loadModel(basePath, &ner.load);
    }

    /**
     * 检查 CWS 是否已加载
     */
    bool isCWSLoaded() const {
        return cws.isLoaded();
    }

    /**
     * 检查 POS 是否已加载
     */
    bool isPOSLoaded() const {
        return pos.isLoaded();
    }

    /**
     * 检查 NER 是否已加载
     */
    bool isNERLoaded() const {
        return ner.isLoaded();
    }

    /**
     * 执行完整分析
     *
     * 参数:
     *   text: 输入文本
     *   enablePOS: 是否启用词性标注
     *   enableNER: 是否启用命名实体识别
     *
     * 返回:
     *   完整分析结果
     */
    LTPResult analyzeLocal(string text, bool enablePOS = true, bool enableNER = true) {
        LTPResult result;
        result.text = text;

        ensureCWSLoaded();
        result.words = cws.predict(text);

        if (enablePOS) {
            ensurePOSLoaded();
            result.posTags = pos.predict(result.words);
        }

        if (enableNER && result.posTags.length > 0) {
            ensureNERLoaded();
            result.nerTags = ner.predict(result.words, result.posTags);
            result.entities = ner.extractEntities(result.words, result.posTags);
        }

        return result;
    }

    /**
     * 分析单个句子（实现 ILTPAnalyzer 接口）
     *
     * 参数:
     *   sentence: 待分析的中文句子
     *
     * 返回:
     *   UnifiedAnalysisResult - 统一的分析结果
     */
    UnifiedAnalysisResult analyze(string sentence) {
        auto localResult = analyzeLocal(sentence, true, true);
        return localResult.toUnified();
    }
    
    /**
     * 批量分析多个句子（实现 ILTPAnalyzer 接口）
     *
     * 参数:
     *   sentences: 待分析的句子数组
     *
     * 返回:
     *   UnifiedAnalysisResult[] - 每个句子的分析结果
     */
    UnifiedAnalysisResult[] analyzeBatch(string[] sentences) {
        UnifiedAnalysisResult[] results;
        results.reserve(sentences.length);
        foreach (sentence; sentences) {
            results ~= analyze(sentence);
        }
        return results;
    }
    
    /**
     * 获取分析器类型标识（实现 ILTPAnalyzer 接口）
     *
     * 返回:
     *   string - "local"
     */
    string analyzerType() const {
        return "local";
    }

    /**
     * 仅执行分词
     *
     * 参数:
     *   text: 输入文本
     *
     * 返回:
     *   分词结果
     */
    string[] segment(string text) {
        ensureCWSLoaded();
        return cws.predict(text);
    }

    /**
     * 执行分词和词性标注
     *
     * 参数:
     *   text: 输入文本
     *
     * 返回:
     *   词性标注结果
     */
    POSTagResult[] tag(string text) {
        ensureCWSLoaded();
        ensurePOSLoaded();

        string[] words = cws.predict(text);
        return pos.predictWithWords(words);
    }

    /**
     * 获取模型信息
     */
    string[] modelInfo() const {
        string[] info;
        info.reserve(3);
        info ~= cws.modelInfo();
        info ~= pos.modelInfo();
        info ~= ner.modelInfo();
        return info;
    }
}

/**
 * 单元测试
 */
unittest {
    import std.stdio;

    auto ltp = new LTPAnalyzer("model");
    ltp.loadAll();

    auto result = ltp.analyzeLocal("我爱北京天安门");
    writeln(result.toString());

    assert(result.words.length > 0);
    assert(result.posTags.length == result.words.length);
    
    // 测试接口
    ILTPAnalyzer analyzer = new LTPAnalyzer("model");
    auto unifiedResult = analyzer.analyze("我爱北京");
    assert(unifiedResult.words.length > 0);
    assert(analyzer.analyzerType() == "local");
}

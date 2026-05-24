/**
 * CWS 分词器
 *
 * 纯 D 语言实现的中文分词
 */
module etc.ltp.native.cws;

import std.string;
import std.array;
import etc.ltp.native.model;
import etc.ltp.native.viterbi;
import etc.ltp.native.features;

/**
 * CWS 分词器类
 */
class CWSAnalyzer {
private:
    CWSModel model;
    bool loaded = false;

public:
    /**
     * 默认构造函数
     */
    this() {
    }

    /**
     * 从模型文件加载
     *
     * 参数:
     *   modelPath: 模型文件路径
     */
    this(string modelPath) {
        load(modelPath);
    }

    /**
     * 从模型实例构造
     *
     * 参数:
     *   modelInstance: CWS 模型实例
     */
    this(CWSModel modelInstance) {
        this.model = modelInstance;
        this.loaded = true;
    }

    /**
     * 加载模型
     *
     * 参数:
     *   modelPath: 模型文件路径
     */
    void load(string modelPath) {
        model = ModelLoader.loadCWS(modelPath);
        loaded = true;
    }

    /**
     * 检查模型是否已加载
     */
    bool isLoaded() const {
        return loaded;
    }

    /**
     * 执行分词
     *
     * 参数:
     *   sentence: 输入句子
     *
     * 返回:
     *   分词结果数组
     */
    string[] predict(string sentence) {
        if (!loaded || sentence.length == 0) {
            return [];
        }

        string buffer;
        auto extractResult = CWSFeatureExtractor.extractFeatures(sentence, buffer);
        size_t[] indices = extractResult[0];
        string[][] features = extractResult[1];

        if (features.length == 0) {
            return [];
        }

        int[][] featureIndices = FeatureIndexer.toIndices(features, model.model.features);

        int[] labels = ViterbiDecoder.decode(featureIndices, model.model.parameters, CWSModel.labelNum);

        auto wordRanges = SBMEConverter.getWords(labels);

        string[] result;
        result.reserve(wordRanges.length);

        foreach (range; wordRanges) {
            size_t start = indices[range[0]];
            size_t end = (range[1] < indices.length) ? indices[range[1]] : sentence.length;
            result ~= sentence[start .. end];
        }

        return result;
    }

    /**
     * 执行分词（带字节偏移）
     *
     * 参数:
     *   sentence: 输入句子
     *
     * 返回:
     *   分词结果，包含词语和偏移量
     */
    WordResult[] predictWithOffset(string sentence) {
        if (!loaded || sentence.length == 0) {
            return [];
        }

        string buffer;
        auto extractResult = CWSFeatureExtractor.extractFeatures(sentence, buffer);
        size_t[] indices = extractResult[0];
        string[][] features = extractResult[1];

        if (features.length == 0) {
            return [];
        }

        int[][] featureIndices = FeatureIndexer.toIndices(features, model.model.features);

        int[] labels = ViterbiDecoder.decode(featureIndices, model.model.parameters, CWSModel.labelNum);

        auto wordRanges = SBMEConverter.getWords(labels);

        WordResult[] result;
        result.reserve(wordRanges.length);

        foreach (range; wordRanges) {
            size_t start = indices[range[0]];
            size_t end = (range[1] < indices.length) ? indices[range[1]] : sentence.length;
            WordResult wr;
            wr.text = sentence[start .. end];
            wr.offset = start;
            wr.length = end - start;
            result ~= wr;
        }

        return result;
    }

    /**
     * 获取模型信息
     */
    string modelInfo() const {
        if (!loaded) {
            return "CWS Model: not loaded";
        }
        return format("CWS Model: %d features, %d parameters",
            model.model.featureCount(), model.model.parameterCount());
    }
}

/**
 * 词语结果结构
 */
struct WordResult {
    string text;
    size_t offset;
    size_t length;
}

/**
 * 单元测试
 */
unittest {
    import std.stdio;

    auto analyzer = new CWSAnalyzer("model/cws_model.bin");
    assert(analyzer.isLoaded());

    auto result = analyzer.predict("我爱北京天安门");
    writeln("CWS Result: ", result);
    assert(result.length > 0);
}

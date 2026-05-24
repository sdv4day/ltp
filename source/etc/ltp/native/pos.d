/**
 * POS 词性标注器
 *
 * 纯 D 语言实现的词性标注
 */
module etc.ltp.native.pos;

import std.string;
import std.array;
import etc.ltp.native.model;
import etc.ltp.native.viterbi;
import etc.ltp.native.features;

/**
 * POS 词性标注器类
 */
class POSAnalyzer {
private:
    POSModel model;
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
     *   modelInstance: POS 模型实例
     */
    this(POSModel modelInstance) {
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
        model = ModelLoader.loadPOS(modelPath);
        loaded = true;
    }

    /**
     * 检查模型是否已加载
     */
    bool isLoaded() const {
        return loaded;
    }

    /**
     * 执行词性标注
     *
     * 参数:
     *   words: 分词结果
     *
     * 返回:
     *   词性标签数组
     */
    string[] predict(string[] words) {
        if (!loaded || words.length == 0) {
            return [];
        }

        string[][] features = POSFeatureExtractor.extractFeatures(words);

        int[][] featureIndices = FeatureIndexer.toIndices(features, model.model.features);

        int[] labels = ViterbiDecoder.decode(featureIndices, model.model.parameters, cast(int)model.labelCount());

        string[] result;
        result.reserve(labels.length);

        foreach (labelIdx; labels) {
            result ~= model.definition.toLabel(labelIdx);
        }

        return result;
    }

    /**
     * 执行词性标注（带词语）
     *
     * 参数:
     *   words: 分词结果
     *
     * 返回:
     *   词性标注结果，包含词语和词性
     */
    POSTagResult[] predictWithWords(string[] words) {
        if (!loaded || words.length == 0) {
            return [];
        }

        string[] tags = predict(words);

        POSTagResult[] result;
        result.reserve(words.length);

        foreach (i, word; words) {
            POSTagResult pr;
            pr.word = word;
            pr.pos = (i < tags.length) ? tags[i] : "";
            result ~= pr;
        }

        return result;
    }

    /**
     * 获取模型信息
     */
    string modelInfo() const {
        if (!loaded) {
            return "POS Model: not loaded";
        }
        return format("POS Model: %d features, %d parameters, %d labels",
            model.model.featureCount(), model.model.parameterCount(), model.labelCount());
    }
}

/**
 * 词性标注结果结构
 */
struct POSTagResult {
    string word;
    string pos;
}

/**
 * 单元测试
 */
unittest {
    import std.stdio;

    auto analyzer = new POSAnalyzer("model/pos_model.bin");
    assert(analyzer.isLoaded());

    string[] words = ["我", "爱", "北京", "天安门"];
    auto result = analyzer.predict(words);
    writeln("POS Result: ", result);
    assert(result.length == words.length);
}

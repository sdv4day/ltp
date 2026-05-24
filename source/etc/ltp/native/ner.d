/**
 * NER 命名实体识别器
 *
 * 纯 D 语言实现的命名实体识别
 */
module etc.ltp.native.ner;

import std.string;
import std.array;
import etc.ltp.native.model;
import etc.ltp.native.viterbi;
import etc.ltp.native.features;

/**
 * NER 命名实体识别器类
 */
class NERAnalyzer {
private:
    NERModel model;
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
     *   modelInstance: NER 模型实例
     */
    this(NERModel modelInstance) {
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
        model = ModelLoader.loadNER(modelPath);
        loaded = true;
    }

    /**
     * 检查模型是否已加载
     */
    bool isLoaded() const {
        return loaded;
    }

    /**
     * 执行命名实体识别
     *
     * 参数:
     *   words: 分词结果
     *   posTags: 词性标注结果
     *
     * 返回:
     *   实体标签数组
     */
    string[] predict(string[] words, string[] posTags) {
        if (!loaded || words.length == 0) {
            return [];
        }

        string[][] features = NERFeatureExtractor.extractFeatures(words, posTags);

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
     * 执行命名实体识别（提取实体）
     *
     * 参数:
     *   words: 分词结果
     *   posTags: 词性标注结果
     *
     * 返回:
     *   命名实体数组
     */
    EntityResult[] extractEntities(string[] words, string[] posTags) {
        if (!loaded || words.length == 0) {
            return [];
        }

        string[] tags = predict(words, posTags);

        EntityResult[] entities;
        size_t start = 0;
        string currentType = "";
        bool inEntity = false;

        foreach (i, tag; tags) {
            if (tag.startsWith("B-")) {
                if (inEntity) {
                    EntityResult er;
                    er.text = join(words[start .. i], "");
                    er.entityType = currentType;
                    er.start = start;
                    er.end = i;
                    entities ~= er;
                }
                start = i;
                currentType = tag[2 .. $];
                inEntity = true;
            } else if (tag.startsWith("I-")) {
                string type = tag[2 .. $];
                if (!inEntity) {
                    start = i;
                    currentType = type;
                    inEntity = true;
                } else if (type != currentType) {
                    if (inEntity) {
                        EntityResult er;
                        er.text = join(words[start .. i], "");
                        er.entityType = currentType;
                        er.start = start;
                        er.end = i;
                        entities ~= er;
                    }
                    start = i;
                    currentType = type;
                    inEntity = true;
                }
            } else if (tag.startsWith("E-")) {
                string type = tag[2 .. $];
                if (!inEntity) {
                    start = i;
                    currentType = type;
                    inEntity = true;
                }
                if (inEntity) {
                    EntityResult er;
                    er.text = join(words[start .. i+1], "");
                    er.entityType = (type == currentType) ? type : currentType;
                    er.start = start;
                    er.end = i+1;
                    entities ~= er;
                    inEntity = false;
                }
            } else if (tag.startsWith("S-")) {
                string type = tag[2 .. $];
                if (inEntity) {
                    EntityResult er;
                    er.text = join(words[start .. i], "");
                    er.entityType = currentType;
                    er.start = start;
                    er.end = i;
                    entities ~= er;
                }
                EntityResult er;
                er.text = words[i];
                er.entityType = type;
                er.start = i;
                er.end = i+1;
                entities ~= er;
                inEntity = false;
            } else if (tag == "O") {
                if (inEntity) {
                    EntityResult er;
                    er.text = join(words[start .. i], "");
                    er.entityType = currentType;
                    er.start = start;
                    er.end = i;
                    entities ~= er;
                    inEntity = false;
                }
            }
        }

        if (inEntity) {
            EntityResult er;
            er.text = join(words[start .. $], "");
            er.entityType = currentType;
            er.start = start;
            er.end = words.length;
            entities ~= er;
        }

        return entities;
    }

    /**
     * 获取模型信息
     */
    string modelInfo() const {
        if (!loaded) {
            return "NER Model: not loaded";
        }
        return format("NER Model: %d features, %d parameters, %d labels",
            model.model.featureCount(), model.model.parameterCount(), model.labelCount());
    }
}

/**
 * 命名实体结果结构
 */
struct EntityResult {
    string text;
    string entityType;
    size_t start;
    size_t end;
}

/**
 * 单元测试
 */
unittest {
    import std.stdio;

    auto analyzer = new NERAnalyzer("model/ner_model.bin");
    assert(analyzer.isLoaded());

    string[] words = ["我", "爱", "北京", "天安门"];
    string[] posTags = ["r", "v", "ns", "ns"];
    auto result = analyzer.predict(words, posTags);
    writeln("NER Result: ", result);
    assert(result.length == words.length);
}

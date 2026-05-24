/**
 * LTP 模型数据结构和加载器
 *
 * 支持 Avro (.bin) 和 JSON (.json) 两种格式
 */
module etc.ltp.native.model;

import std.file;
import std.json;
import std.array;
import std.path;
import etc.ltp.native.avro_loader;

/**
 * CWS 模型定义
 */
struct CWSDefinition {
}

/**
 * POS/NER 模型定义
 */
struct LabelDefinition {
    string[] toLabels;
    long[string] labelsTo;

    /**
     * 根据标签名获取标签索引
     */
    long labelTo(string label) const {
        if (auto ptr = label in labelsTo) {
            return *ptr;
        }
        return -1;
    }

    /**
     * 根据索引获取标签名
     */
    string toLabel(size_t index) const {
        if (index < toLabels.length) {
            return toLabels[index];
        }
        return "";
    }
}

/**
 * 感知机模型
 */
struct PerceptronModel {
    long[string] features;
    double[] parameters;

    /**
     * 获取特征索引
     *
     * 参数:
     *   feature: 特征字符串
     *
     * 返回:
     *   特征索引，如果不存在返回 -1
     */
    long getFeatureIndex(string feature) const {
        if (auto ptr = feature in features) {
            return *ptr;
        }
        return -1;
    }

    /**
     * 获取特征数量
     */
    size_t featureCount() const {
        return features.length;
    }

    /**
     * 获取参数数量
     */
    size_t parameterCount() const {
        return parameters.length;
    }
}

/**
 * CWS 完整模型
 */
struct CWSModel {
    CWSDefinition definition;
    PerceptronModel model;

    enum labelNum = 4;
    enum labels = ["S", "B", "M", "E"];
}

/**
 * POS 完整模型
 */
struct POSModel {
    LabelDefinition definition;
    PerceptronModel model;

    /**
     * 获取标签数量
     */
    size_t labelCount() const {
        return definition.toLabels.length;
    }
}

/**
 * NER 完整模型
 */
struct NERModel {
    LabelDefinition definition;
    PerceptronModel model;

    /**
     * 获取标签数量
     */
    size_t labelCount() const {
        return definition.toLabels.length;
    }
}

/**
 * 模型加载器
 *
 * 自动识别文件格式：
 * - .bin: Avro 格式（推荐，节省 75% 空间）
 * - .json: JSON 格式（便于调试）
 */
struct ModelLoader {
    /**
     * 加载 CWS 模型
     *
     * 参数:
     *   path: 模型文件路径（.bin 或 .json）
     *
     * 返回:
     *   CWS 模型实例
     */
    static CWSModel loadCWS(string path) {
        string ext = extension(path);
        
        if (ext == ".bin") {
            return AvroModelLoader.loadCWS(path);
        } else {
            return loadCWSFromJSON(path);
        }
    }

    /**
     * 加载 POS 模型
     *
     * 参数:
     *   path: 模型文件路径（.bin 或 .json）
     *
     * 返回:
     *   POS 模型实例
     */
    static POSModel loadPOS(string path) {
        string ext = extension(path);
        
        if (ext == ".bin") {
            return AvroModelLoader.loadPOS(path);
        } else {
            return loadPOSFromJSON(path);
        }
    }

    /**
     * 加载 NER 模型
     *
     * 参数:
     *   path: 模型文件路径（.bin 或 .json）
     *
     * 返回:
     *   NER 模型实例
     */
    static NERModel loadNER(string path) {
        string ext = extension(path);
        
        if (ext == ".bin") {
            return AvroModelLoader.loadNER(path);
        } else {
            return loadNERFromJSON(path);
        }
    }

private:
    /**
     * 从 JSON 加载 CWS 模型
     */
    static CWSModel loadCWSFromJSON(string path) {
        auto content = cast(string) std.file.read(path);
        JSONValue json = parseJSON(content);
        
        CWSModel result;
        
        auto featuresObj = json["features"].object;
        foreach (key, value; featuresObj) {
            result.model.features[key] = value.integer;
        }
        
        auto paramsArray = json["parameters"].array;
        foreach (param; paramsArray) {
            result.model.parameters ~= param.floating;
        }
        
        return result;
    }

    /**
     * 从 JSON 加载 POS 模型
     */
    static POSModel loadPOSFromJSON(string path) {
        auto content = cast(string) std.file.read(path);
        JSONValue json = parseJSON(content);
        
        POSModel result;
        
        auto defObj = json["definition"].object;
        auto toLabelsArray = defObj["to_labels"].array;
        foreach (label; toLabelsArray) {
            result.definition.toLabels ~= label.str;
        }
        
        auto labelsToObj = defObj["labels_to"].object;
        foreach (key, value; labelsToObj) {
            result.definition.labelsTo[key] = value.integer;
        }
        
        auto featuresObj = json["features"].object;
        foreach (key, value; featuresObj) {
            result.model.features[key] = value.integer;
        }
        
        auto paramsArray = json["parameters"].array;
        foreach (param; paramsArray) {
            result.model.parameters ~= param.floating;
        }
        
        return result;
    }

    /**
     * 从 JSON 加载 NER 模型
     */
    static NERModel loadNERFromJSON(string path) {
        auto content = cast(string) std.file.read(path);
        JSONValue json = parseJSON(content);
        
        NERModel result;
        
        auto defObj = json["definition"].object;
        auto toLabelsArray = defObj["to_labels"].array;
        foreach (label; toLabelsArray) {
            result.definition.toLabels ~= label.str;
        }
        
        auto labelsToObj = defObj["labels_to"].object;
        foreach (key, value; labelsToObj) {
            result.definition.labelsTo[key] = value.integer;
        }
        
        auto featuresObj = json["features"].object;
        foreach (key, value; featuresObj) {
            result.model.features[key] = value.integer;
        }
        
        auto paramsArray = json["parameters"].array;
        foreach (param; paramsArray) {
            result.model.parameters ~= param.floating;
        }
        
        return result;
    }
}

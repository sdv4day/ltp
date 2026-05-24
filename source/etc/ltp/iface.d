/**
 * LTP 分析器统一接口
 * 
 * 定义本地和云端分析器的共同接口，实现代码解耦和灵活切换
 */
module etc.ltp.iface;

import std.json;

/**
 * 统一的分词结果结构
 * 
 * 兼容本地和云端分析器的分词结果
 */
struct UnifiedWord {
    string text;              ///< 词语文本
    string pos;               ///< 词性标签（可选，云端提供）
    string entity;            ///< 命名实体标签（可选，本地提供）
    int offset;               ///< 偏移量（可选，云端提供）
    int length;               ///< 长度（可选，云端提供）
    int parent;               ///< 依存父节点（可选，云端提供）
    string relation;          ///< 依存关系（可选，云端提供）
    
    /**
     * 从本地 CWS/POS/NER 结果构建
     * 
     * 参数：
     *   word: 词语
     *   pos: 词性（可选）
     *   entity: 实体标签（可选）
     */
    static UnifiedWord fromLocal(string word, string pos = "", string entity = "") {
        UnifiedWord w;
        w.text = word;
        w.pos = pos;
        w.entity = entity;
        return w;
    }
    
    /**
     * 从云端 Word 对象转换
     * 
     * 参数：
     *   cloudWord: 云端词语对象（需要实现 toJSON 或提供字段访问）
     */
    // 注意：这里使用模板避免循环依赖
    static UnifiedWord fromCloud(T)(T cloudWord) {
        UnifiedWord w;
        w.text = cloudWord.text;
        w.pos = cloudWord.pos;
        w.offset = cloudWord.offset;
        w.length = cloudWord.length;
        w.parent = cloudWord.parent;
        w.relation = cloudWord.relation;
        return w;
    }
    
    /**
     * 转换为 JSON
     */
    JSONValue toJSON() const {
        JSONValue obj;
        obj["text"] = JSONValue(text);
        
        if (pos.length > 0) {
            obj["pos"] = JSONValue(pos);
        }
        if (entity.length > 0) {
            obj["entity"] = JSONValue(entity);
        }
        if (offset >= 0) {
            obj["offset"] = JSONValue(cast(long)offset);
        }
        if (length > 0) {
            obj["length"] = JSONValue(cast(long)length);
        }
        if (parent >= 0) {
            obj["parent"] = JSONValue(cast(long)parent);
        }
        if (relation.length > 0) {
            obj["relation"] = JSONValue(relation);
        }
        
        return obj;
    }
}

/**
 * 统一的命名实体结构
 */
struct UnifiedNamedEntity {
    string text;              ///< 实体文本
    string type;              ///< 实体类型（如 "Ns", "Ni" 等）
    int offset;               ///< 偏移量
    int length;               ///< 长度
    
    /**
     * 转换为 JSON
     */
    JSONValue toJSON() const {
        JSONValue obj;
        obj["text"] = JSONValue(text);
        obj["type"] = JSONValue(type);
        obj["offset"] = JSONValue(cast(long)offset);
        obj["length"] = JSONValue(cast(long)length);
        return obj;
    }
}

/**
 * 统一的分析结果结构
 * 
 * 同时兼容本地和云端分析器的结果
 */
struct UnifiedAnalysisResult {
    string text;                      ///< 原始文本
    UnifiedWord[] words;              ///< 分词结果（统一格式）
    UnifiedNamedEntity[] entities;    ///< 命名实体
    
    /**
     * 获取分词数组（便捷方法）
     */
    string[] getWords() const {
        string[] result;
        result.reserve(words.length);
        foreach (word; words) {
            result ~= word.text;
        }
        return result;
    }
    
    /**
     * 获取词性数组（便捷方法）
     */
    string[] getPOS() const {
        string[] result;
        result.reserve(words.length);
        foreach (word; words) {
            result ~= word.pos;
        }
        return result;
    }
    
    /**
     * 转换为 JSON
     */
    JSONValue toJSON() const {
        JSONValue obj;
        obj["text"] = JSONValue(text);
        
        JSONValue[] wordsArray;
        wordsArray.reserve(words.length);
        foreach (word; words) {
            wordsArray ~= word.toJSON();
        }
        obj["words"] = JSONValue(wordsArray);
        
        JSONValue[] entitiesArray;
        entitiesArray.reserve(entities.length);
        foreach (entity; entities) {
            entitiesArray ~= entity.toJSON();
        }
        obj["entities"] = JSONValue(entitiesArray);
        
        return obj;
    }
}

/**
 * LTP 分析器统一接口
 * 
 * 本地分析器和云端分析器都应实现此接口
 * 
 * 使用示例：
 * ```d
 * import etc.ltp.iface;
 * import etc.ltp.native;        // 本地
 * import etc.ltp.ltpcloud;      // 云端
 * 
 * // 使用本地分析器
 * ILTPAnalyzer localAnalyzer = new LTPAnalyzer("model");
 * auto localResult = localAnalyzer.analyze("我爱北京");
 * 
 * // 使用云端分析器
 * ILTPAnalyzer cloudAnalyzer = new LTPAnalyzerCloud();
 * auto cloudResult = cloudAnalyzer.analyze("我爱北京");
 * 
 * // 两者返回统一的 UnifiedAnalysisResult 格式
 * writeln(localResult.words.length);
 * writeln(cloudResult.words.length);
 * ```
 */
interface ILTPAnalyzer {
    /**
     * 分析单个句子
     * 
     * 参数：
     *   sentence: 待分析的中文句子
     * 
     * 返回：
     *   UnifiedAnalysisResult - 统一的分析结果
     * 
     * 异常：
     *   Exception - 分析失败时抛出异常
     */
    UnifiedAnalysisResult analyze(string sentence);
    
    /**
     * 批量分析多个句子
     * 
     * 参数：
     *   sentences: 待分析的句子数组
     * 
     * 返回：
     *   UnifiedAnalysisResult[] - 每个句子的分析结果
     */
    UnifiedAnalysisResult[] analyzeBatch(string[] sentences);
    
    /**
     * 获取分析器类型标识
     * 
     * 返回：
     *   string - "local" 或 "cloud"
     */
    string analyzerType() const;
}

/**
 * 将统一分析结果转换为 JSON 字符串
 * 
 * 参数：
 *   results: 统一分析结果数组
 * 
 * 返回：
 *   string - JSON 格式的字符串，包含 count 和 results 字段
 * 
 * JSON 格式示例：
 * ```json
 * {
 *   "count": 1,
 *   "results": [
 *     {
 *       "text": "我爱北京",
 *       "words": [{"text": "我", "pos": "r"}, ...],
 *       "entities": [{"text": "北京", "type": "Ns"}]
 *     }
 *   ]
 * }
 * ```
 */
string unifiedResultsToJSON(UnifiedAnalysisResult[] results) {
    import std.json;
    
    JSONValue[] resultArray;
    resultArray.reserve(results.length);
    foreach (result; results) {
        resultArray ~= result.toJSON();
    }
    
    JSONValue root;
    root["results"] = JSONValue(resultArray);
    root["count"] = JSONValue(cast(long)results.length);
    
    // 使用默认的 JSON 序列化
    return root.toString();
}

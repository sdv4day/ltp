/**
 * LTP 在线分析器模块
 *
 * 通过 HTTP API 访问在线 LTP 服务
 * API URL: https://ltp-ltp.hf.space/api
 * OpenAPI Schema: https://ltp-ltp.hf.space/openapi.json
 *
 * 使用 POST 方法进行分词、词性标注、依存句法分析等
 */
module etc.ltp.ltpcloud;

import std.string;
import std.json;
import std.array;
import std.exception;
import std.conv : to;
import std.net.curl;
import std.datetime : seconds;
import etc.ltp.postags;
import etc.ltp.iface;

/**
 * LTP 在线分析器类
 *
 * 通过 HTTP POST 请求访问在线 LTP 服务
 * 实现 ILTPAnalyzer 统一接口
 *
 * 使用示例：
 * ```d
 * import etc.ltp.iface;
 * import etc.ltp.ltpcloud;
 *
 * ILTPAnalyzer analyzer = new LTPAnalyzerCloud();
 * auto result = analyzer.analyze("我爱北京");
 * writeln(result.words.length);
 * ```
 */
class LTPAnalyzerCloud : ILTPAnalyzer {
private:
    string apiUrl;
    string proxyUrl;
    double timeout;
    bool verifySsl;

public:
    /**
     * 构造函数
     *
     * 参数：
     *   apiUrl: LTP API 地址（默认: "https://ltp-ltp.hf.space/api"）
     *   timeout: 请求超时时间（默认: 30 秒）
     *   verifySsl: 是否验证 SSL 证书（默认: true）
     */
    this(string apiUrl = "https://ltp-ltp.hf.space/api", double timeout = 30.0, bool verifySsl = true) {
        this.apiUrl = apiUrl;
        this.timeout = timeout;
        this.proxyUrl = "";
        this.verifySsl = verifySsl;
    }

    /**
     * 设置代理服务器
     *
     * 参数：
     *   proxyUrl: 代理服务器地址（如 "http://proxy.example.com:8080"）
     */
    void setProxy(string proxyUrl) {
        this.proxyUrl = proxyUrl;
    }

    /**
     * 清除代理设置
     */
    void clearProxy() {
        this.proxyUrl = "";
    }

    /**
     * 设置超时时间
     *
     * 参数：
     *   seconds: 超时时间（秒）
     */
    void setTimeout(double seconds) {
        this.timeout = seconds;
    }

    /**
     * 设置是否验证 SSL 证书
     *
     * 参数：
     *   verify: true 验证证书，false 跳过验证（不安全，仅用于测试）
     */
    void setVerifySsl(bool verify) {
        this.verifySsl = verify;
    }

    /**
     * 分析单个句子
     *
     * 参数：
     *   sentence: 待分析的中文句子
     *
     * 返回：
     *   CloudAnalysisResult - 包含分词、词性、依存关系等完整结果
     *
     * 异常：
     *   Exception - 网络请求失败或 API 返回错误
     */
    CloudAnalysisResult analyzeCloud(string sentence) {
        JSONValue[] sentences;
        sentences ~= JSONValue(sentence);

        JSONValue requestBody = JSONValue(sentences);

        string response = sendPostRequest(requestBody);

        JSONValue jsonResponse = parseJSON(response);

        if (jsonResponse.type != JSONType.array || jsonResponse.array.length == 0) {
            throw new Exception("Invalid response from LTP API");
        }

        return parseItemResult(jsonResponse.array[0]);
    }

    /**
     * 批量分析多个句子
     *
     * 参数：
     *   sentences: 待分析的句子数组
     *
     * 返回：
     *   CloudAnalysisResult[] - 每个句子的分析结果
     */
    CloudAnalysisResult[] analyzeBatchCloud(string[] sentences) {
        if (sentences.length == 0) {
            return [];
        }

        JSONValue[] jsonSentences;
        jsonSentences.reserve(sentences.length);
        foreach (sentence; sentences) {
            jsonSentences ~= JSONValue(sentence);
        }

        JSONValue requestBody = JSONValue(jsonSentences);

        string response = sendPostRequest(requestBody);

        JSONValue jsonResponse = parseJSON(response);

        if (jsonResponse.type != JSONType.array) {
            throw new Exception("Invalid response from LTP API");
        }

        CloudAnalysisResult[] results;
        results.reserve(jsonResponse.array.length);
        foreach (itemJson; jsonResponse.array) {
            results ~= parseItemResult(itemJson);
        }

        return results;
    }

    /**
     * 实现 ILTPAnalyzer.analyze 方法
     */
    override UnifiedAnalysisResult analyze(string sentence) {
        CloudAnalysisResult cloudResult = this.analyzeCloud(sentence);
        return cloudResult.toUnified();
    }

    /**
     * 实现 ILTPAnalyzer.analyzeBatch 方法
     */
    override UnifiedAnalysisResult[] analyzeBatch(string[] sentences) {
        CloudAnalysisResult[] cloudResults = this.analyzeBatchCloud(sentences);

        UnifiedAnalysisResult[] results;
        results.reserve(cloudResults.length);
        foreach (cloudResult; cloudResults) {
            results ~= cloudResult.toUnified();
        }

        return results;
    }

    /**
     * 实现 ILTPAnalyzer.analyzerType 方法
     */
    override string analyzerType() const {
        return "cloud";
    }

private:

    /**
     * 将云端结果转换为统一分析结果
     *
     * 参数：
     *   cloudResult: 云端分析结果
     *
     * 返回：
     *   UnifiedAnalysisResult - 统一格式结果
     */
    static UnifiedAnalysisResult cloudToUnified(ref CloudAnalysisResult cloudResult) {
        UnifiedAnalysisResult unified;
        unified.text = cloudResult.text;
        unified.words.reserve(cloudResult.words.length);
        unified.entities.reserve(cloudResult.nes.length);

        foreach (cloudWord; cloudResult.words) {
            UnifiedWord word;
            word.text = cloudWord.text;
            word.pos = cloudWord.pos;
            word.offset = cloudWord.offset;
            word.length = cloudWord.length;
            word.parent = cloudWord.parent;
            word.relation = cloudWord.relation;

            unified.words ~= word;
        }

        foreach (cloudNE; cloudResult.nes) {
            UnifiedNamedEntity entity;
            entity.text = cloudNE.text;
            entity.type = cloudNE.ne;
            entity.offset = cloudNE.offset;
            entity.length = cloudNE.length;

            unified.entities ~= entity;
        }

        return unified;
    }

    /**
     * 发送 POST 请求到 LTP API
     *
     * 参数：
     *   requestBody: JSON 格式的请求体
     *
     * 返回：
     *   string - API 响应的 JSON 字符串
     */
    string sendPostRequest(JSONValue requestBody) {
        string jsonString = requestBody.toString();

        try {
            auto http = HTTP(apiUrl);

            http.method = HTTP.Method.post;
            http.addRequestHeader("Content-Type", "application/json");
            http.postData = jsonString;

            http.connectTimeout = (cast(int)timeout).seconds;
            http.dataTimeout = (cast(int)timeout).seconds;

            if (proxyUrl.length > 0) {
                http.proxy = proxyUrl;
            }

            if (!verifySsl) {
                http.verifyPeer = false;
            }

            auto response = appender!(ubyte[]);
            http.onReceive = (ubyte[] data) {
                response.put(data);
                return data.length;
            };

            http.perform();

            if (http.statusLine.code != 200) {
                throw new Exception("HTTP Error: " ~ to!string(http.statusLine.code) ~ " " ~ http.statusLine.reason);
            }

            return cast(string)response.data;
        } catch (CurlException e) {
            throw new Exception("Failed to send request to LTP API: " ~ e.msg);
        }
    }

    /**
     * 解析 Item 结果
     *
     * 参数：
     *   itemJson: JSON 格式的 Item 对象
     *
     * 返回：
     *   CloudAnalysisResult - 解析后的分析结果
     */
    CloudAnalysisResult parseItemResult(JSONValue itemJson) {
        CloudAnalysisResult result;

        if ("text" in itemJson.object) {
            result.text = itemJson["text"].str;
        }

        if ("words" in itemJson.object && itemJson["words"].type == JSONType.array) {
            foreach (wordJson; itemJson["words"].array) {
                result.words ~= parseWord(wordJson);
            }
        }

        if ("nes" in itemJson.object && itemJson["nes"].type == JSONType.array) {
            foreach (neJson; itemJson["nes"].array) {
                result.nes ~= parseNE(neJson);
            }
        }

        return result;
    }

    /**
     * 解析 Word 对象
     */
    CloudWord parseWord(JSONValue wordJson) {
        CloudWord word;

        if ("id" in wordJson.object) {
            word.id = wordJson["id"].integer.to!int;
        }
        if ("text" in wordJson.object) {
            word.text = wordJson["text"].str;
        }
        if ("pos" in wordJson.object) {
            word.pos = wordJson["pos"].str;
        }
        if ("offset" in wordJson.object) {
            word.offset = wordJson["offset"].integer.to!int;
        }
        if ("length" in wordJson.object) {
            word.length = wordJson["length"].integer.to!int;
        }
        if ("parent" in wordJson.object) {
            word.parent = wordJson["parent"].integer.to!int;
        }
        if ("relation" in wordJson.object) {
            word.relation = wordJson["relation"].str;
        }

        if ("roles" in wordJson.object && wordJson["roles"].type == JSONType.array) {
            foreach (roleJson; wordJson["roles"].array) {
                word.roles ~= parseSRLRole(roleJson);
            }
        }

        if ("parents" in wordJson.object && wordJson["parents"].type == JSONType.array) {
            foreach (parentJson; wordJson["parents"].array) {
                word.parents ~= parseParent(parentJson);
            }
        }

        return word;
    }

    /**
     * 解析 NE（命名实体）对象
     */
    CloudNE parseNE(JSONValue neJson) {
        CloudNE ne;

        if ("text" in neJson.object) {
            ne.text = neJson["text"].str;
        }
        if ("ne" in neJson.object) {
            ne.ne = neJson["ne"].str;
        }
        if ("offset" in neJson.object) {
            ne.offset = neJson["offset"].integer.to!int;
        }
        if ("length" in neJson.object) {
            ne.length = neJson["length"].integer.to!int;
        }

        return ne;
    }

    /**
     * 解析 SRLRole 对象
     */
    CloudSRLRole parseSRLRole(JSONValue roleJson) {
        CloudSRLRole role;

        if ("text" in roleJson.object) {
            role.text = roleJson["text"].str;
        }
        if ("type" in roleJson.object) {
            role.type = roleJson["type"].str;
        }
        if ("offset" in roleJson.object) {
            role.offset = roleJson["offset"].integer.to!int;
        }
        if ("length" in roleJson.object) {
            role.length = roleJson["length"].integer.to!int;
        }

        return role;
    }

    /**
     * 解析 Parent 对象
     */
    CloudParent parseParent(JSONValue parentJson) {
        CloudParent parent;

        if ("parent" in parentJson.object) {
            parent.parent = parentJson["parent"].integer.to!int;
        }
        if ("relate" in parentJson.object) {
            parent.relate = parentJson["relate"].str;
        }

        return parent;
    }
}

/**
 * 云分析结果结构
 *
 * 包含分词、词性标注、命名实体识别、依存句法等完整信息
 */
struct CloudAnalysisResult {
    string text;              /// 原始文本
    CloudWord[] words;        /// 分词结果
    CloudNE[] nes;            /// 命名实体

    /**
     * 转换为简化的 JSON 格式
     *
     * 返回：
     *   JSONValue - JSON 格式的分析结果
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

        JSONValue[] nesArray;
        nesArray.reserve(nes.length);
        foreach (ne; nes) {
            nesArray ~= ne.toJSON();
        }
        obj["nes"] = JSONValue(nesArray);

        return obj;
    }

    /**
     * 转换为统一分析结果
     *
     * 返回：
     *   UnifiedAnalysisResult - 统一格式结果
     */
    UnifiedAnalysisResult toUnified() const {
        UnifiedAnalysisResult unified;
        unified.text = text;
        unified.words.reserve(words.length);
        unified.entities.reserve(nes.length);

        foreach (cloudWord; words) {
            UnifiedWord word;
            word.text = cloudWord.text;
            word.pos = cloudWord.pos;
            word.offset = cloudWord.offset;
            word.length = cloudWord.length;
            word.parent = cloudWord.parent;
            word.relation = cloudWord.relation;

            unified.words ~= word;
        }

        foreach (cloudNE; nes) {
            UnifiedNamedEntity entity;
            entity.text = cloudNE.text;
            entity.type = cloudNE.ne;
            entity.offset = cloudNE.offset;
            entity.length = cloudNE.length;

            unified.entities ~= entity;
        }

        return unified;
    }
}

/**
 * 词语信息结构
 */
struct CloudWord {
    int id;                   /// 词语 ID
    string text;              /// 词语文本
    string pos;               /// 词性标签
    int offset;               /// 在原文中的偏移量
    int length;               /// 词语长度
    int parent;               /// 依存父节点 ID
    string relation;          /// 依存关系
    CloudSRLRole[] roles;     /// 语义角色
    CloudParent[] parents;    /// 父节点列表

    /**
     * 获取词性枚举
     *
     * 返回：
     *   POSTag - 词性枚举值
     */
    POSTag getPOSTag() const {
        return POSTagHelper.fromString(pos);
    }

    /**
     * 转换为 JSON
     */
    JSONValue toJSON() const {
        JSONValue obj;
        obj["id"] = JSONValue(cast(long)id);
        obj["text"] = JSONValue(text);
        obj["pos"] = JSONValue(pos);
        obj["offset"] = JSONValue(cast(long)offset);
        obj["length"] = JSONValue(cast(long)length);
        obj["parent"] = JSONValue(cast(long)parent);
        obj["relation"] = JSONValue(relation);

        JSONValue[] rolesArray;
        rolesArray.reserve(roles.length);
        foreach (role; roles) {
            rolesArray ~= role.toJSON();
        }
        obj["roles"] = JSONValue(rolesArray);

        JSONValue[] parentsArray;
        parentsArray.reserve(parents.length);
        foreach (parent; parents) {
            parentsArray ~= parent.toJSON();
        }
        obj["parents"] = JSONValue(parentsArray);

        return obj;
    }
}

/**
 * 命名实体结构
 */
struct CloudNE {
    string text;              /// 实体文本
    string ne;                /// 实体类型（Nh/Ni/Ns）
    int offset;               /// 偏移量
    int length;               /// 长度

    /**
     * 转换为 JSON
     */
    JSONValue toJSON() const {
        JSONValue obj;
        obj["text"] = JSONValue(text);
        obj["ne"] = JSONValue(ne);
        obj["offset"] = JSONValue(cast(long)offset);
        obj["length"] = JSONValue(cast(long)length);
        return obj;
    }
}

/**
 * 语义角色结构
 */
struct CloudSRLRole {
    string text;              /// 角色文本
    string type;              /// 角色类型（ARG0/ARG1/ADV等）
    int offset;               /// 偏移量
    int length;               /// 长度

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
 * 父节点信息结构
 */
struct CloudParent {
    int parent;               /// 父节点 ID
    string relate;            /// 关系类型

    /**
     * 转换为 JSON
     */
    JSONValue toJSON() const {
        JSONValue obj;
        obj["parent"] = JSONValue(cast(long)parent);
        obj["relate"] = JSONValue(relate);
        return obj;
    }
}

/**
 * LTP 词性标注枚举模块
 * 
 * 基于 863 词性标注集
 * 参考: https://ltp.ai/docs/appendix.html
 * 
 * 使用普通枚举 + 编译时元编程实现高效的标签转换
 */
module etc.ltp.postags;

import std.traits : EnumMembers, hasMember;
import std.algorithm : canFind, map, filter;
import std.array : array;
import std.string : toLower;
import std.meta : AliasSeq, allSatisfy;
import std.conv : to;

/**
 * LTP 词性标注枚举
 * 
 * LTP 使用 863 词性标注集，共 27 个词性标签
 * 枚举名称与标签简写保持一致，便于转换
 * 
 * 使用示例：
 * ```d
 * import etc.ltp.postags;
 * 
 * // 从字符串转换为枚举
 * auto pos = POSTagHelper.fromString("n");
 * if (pos == POSTag.n) {
 *     writeln("这是一个普通名词");
 * }
 * 
 * // 从枚举转换为字符串
 * string tag = POSTagHelper.toString(POSTag.ns);  // "ns"
 * 
 * // 获取词性描述
 * string desc = POSTagHelper.description(POSTag.v);  // "动词"
 * ```
 */
enum POSTag {
    // ===== 实词 =====
    
    a,   ///< 形容词 (adjective) - 美丽
    b,   ///< 其他名词修饰词 (other noun-modifier) - 大型, 西式
    c,   ///< 连词 (conjunction) - 和, 虽然
    d,   ///< 副词 (adverb) - 很
    e,   ///< 叹词 (exclamation) - 哎
    g,   ///< 语素 (morpheme) - 茨, 甥
    h,   ///< 前缀 (prefix) - 阿, 伪
    i,   ///< 成语 (idiom) - 百花齐放
    j,   ///< 简称 (abbreviation) - 公检法
    k,   ///< 后缀 (suffix) - 界, 率
    m,   ///< 数词 (number) - 一, 第一
    n,   ///< 普通名词 (general noun) - 苹果
    nd,  ///< 方位名词 (direction noun) - 右侧
    nh,  ///< 人名 (person name) - 杜甫, 汤姆
    ni,  ///< 机构名 (organization name) - 保险公司
    ns,  ///< 地名 (geographical name) - 北京
    nt,  ///< 时间名词 (temporal noun) - 近日, 明代
    nz,  ///< 其他专名 (other proper noun) - 诺贝尔奖
    o,   ///< 拟声词 (onomatopoeia) - 哗啦
    p,   ///< 介词 (preposition) - 在, 把
    q,   ///< 量词 (quantity) - 个
    r,   ///< 代词 (pronoun) - 我们
    v,   ///< 动词 (verb) - 跑, 学习
    u,   ///< 助词 (auxiliary) - 的, 地
    
    // ===== 其他 =====
    wp,  ///< 标点符号 (punctuation) - ，。！
    ws,  ///< 外来词 (foreign words) - CPU
    x,   ///< 非语素字 (non-lexeme) - 萄, 翱
    z    ///< 状态词 (descriptive words) - 瑟瑟，匆匆
}

/**
 * POSTag 的辅助工具
 * 
 * 使用编译时元编程实现高效的标签转换
 * 枚举名称与标签简写一致，通过 __traits(identifier) 获取字符串
 */
struct POSTagHelper {
    /**
     * 从字符串转换为 POSTag 枚举
     * 
     * 参数：
     *   tag: 词性标签字符串（如 "n", "v", "ns"）
     * 
     * 返回：
     *   POSTag - 对应的枚举值
     * 
     * 异常：
     *   Exception - 如果标签无效
     * 
     * 示例：
     * ```d
     * auto pos = POSTagHelper.fromString("ns");
     * assert(pos == POSTag.ns);
     * ```
     */
    static POSTag fromString(string tag) {
        import std.exception : enforce;
        import std.traits : hasMember;
        string lowerTag = toLower(tag);
        
        // 使用 hasMember 在编译时检查，运行时获取
        // 由于 hasMember 需要编译时常量，我们使用模板元编程
        static foreach (memberName; __traits(allMembers, POSTag)) {
            static if (hasMember!(POSTag, memberName)) {
                if (lowerTag == memberName) {
                    return __traits(getMember, POSTag, memberName);
                }
            }
        }
        
        // 如果未找到，抛出异常
        enforce(false, "Invalid POS tag: " ~ tag);
        return POSTag.n; // 永远不会到达这里
    }
    
    /**
     * 获取词性标签的字符串表示
     * 
     * 使用 std.conv.to 将枚举转换为字符串
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   string - 词性标签字符串（如 "n", "v", "ns"）
     * 
     * 示例：
     * ```d
     * string tag = POSTagHelper.toString(POSTag.ns);
     * assert(tag == "ns");
     * ```
     */
    static string toString(POSTag pos) {
        // 使用 to!string 将枚举转换为字符串
        return to!string(pos);
    }
    
    // 词性中文描述映射表
    private static immutable string[string] chineseDescriptions = [
        "a": "形容词",
        "b": "其他名词修饰词",
        "c": "连词",
        "d": "副词",
        "e": "叹词",
        "g": "语素",
        "h": "前缀",
        "i": "成语",
        "j": "简称",
        "k": "后缀",
        "m": "数词",
        "n": "普通名词",
        "nd": "方位名词",
        "nh": "人名",
        "ni": "机构名",
        "ns": "地名",
        "nt": "时间名词",
        "nz": "其他专名",
        "o": "拟声词",
        "p": "介词",
        "q": "量词",
        "r": "代词",
        "v": "动词",
        "wp": "标点符号",
        "ws": "外来词",
        "x": "非语素字",
        "z": "状态词",
        "u": "助词"
    ];
    
    // 词性英文描述映射表
    private static immutable string[string] englishDescriptions = [
        "a": "adjective",
        "b": "other noun-modifier",
        "c": "conjunction",
        "d": "adverb",
        "e": "exclamation",
        "g": "morpheme",
        "h": "prefix",
        "i": "idiom",
        "j": "abbreviation",
        "k": "suffix",
        "m": "number",
        "n": "general noun",
        "nd": "direction noun",
        "nh": "person name",
        "ni": "organization name",
        "ns": "geographical name",
        "nt": "temporal noun",
        "nz": "other proper noun",
        "o": "onomatopoeia",
        "p": "preposition",
        "q": "quantity",
        "r": "pronoun",
        "v": "verb",
        "wp": "punctuation",
        "ws": "foreign words",
        "x": "non-lexeme",
        "z": "descriptive words",
        "u": "auxiliary"
    ];
    
    /**
     * 获取词性的中文描述
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   string - 词性的中文描述
     * 
     * 示例：
     * ```d
     * string desc = POSTagHelper.description(POSTag.v);
     * assert(desc == "动词");
     * ```
     */
    static string description(POSTag pos) {
        // 先获取标签字符串
        string tag = POSTagHelper.toString(pos);
        if (tag in chineseDescriptions) {
            return chineseDescriptions[tag];
        }
        return "未知";
    }
    
    /**
     * 获取词性的英文描述
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   string - 词性的英文描述
     */
    static string englishDescription(POSTag pos) {
        // 先获取标签字符串
        string tag = POSTagHelper.toString(pos);
        if (tag in englishDescriptions) {
            return englishDescriptions[tag];
        }
        return "unknown";
    }
    
    /**
     * 通用词性分类判断函数模板
     * 
     * 使用示例：
     * ```d
     * // 定义标签序列
     * private enum nounTags = AliasSeq!(POSTag.n, POSTag.ns, POSTag.nh);
     * 
     * // 创建判断函数别名
     * alias isNoun = IsCategory!(nounTags);
     * ```
     */
    template IsCategory(T...) {
        static bool check(POSTag pos) {
            static foreach (tag; T) {
                if (pos == tag) {
                    return true;
                }
            }
            return false;
        }
        
        alias IsCategory = check;
    }
    
    // ==================== 词性分类定义 ====================
    
    /// 名词类标签
    private enum nounTags = AliasSeq!(
        POSTag.n,   // 普通名词
        POSTag.nd,  // 方位名词
        POSTag.nh,  // 人名
        POSTag.ni,  // 机构名
        POSTag.ns,  // 地名
        POSTag.nt,  // 时间名词
        POSTag.nz   // 其他专名
    );
    
    /// 动词类标签
    private enum verbTags = AliasSeq!(POSTag.v);
    
    /// 形容词类标签
    private enum adjectiveTags = AliasSeq!(POSTag.a, POSTag.z);
    
    /// 虚词类标签
    private enum functionWordTags = AliasSeq!(POSTag.c, POSTag.p, POSTag.u, POSTag.wp);
    
    /// 专有名词类标签
    private enum properNounTags = AliasSeq!(POSTag.nh, POSTag.ni, POSTag.ns, POSTag.nz);
    
    // ==================== 创建判断函数别名 ====================
    
    /**
     * 判断是否为名词类词性
     * 
     * 包含：普通名词、方位名词、人名、机构名、地名、时间名词、其他专名
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   bool - 如果是名词类返回 true
     */
    alias isNoun = IsCategory!(nounTags);
    
    /**
     * 判断是否为动词类词性
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   bool - 如果是动词类返回 true
     */
    alias isVerb = IsCategory!(verbTags);
    
    /**
     * 判断是否为形容词类词性
     * 
     * 包含：形容词、状态词
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   bool - 如果是形容词类返回 true
     */
    alias isAdjective = IsCategory!(adjectiveTags);
    
    /**
     * 判断是否为虚词
     * 
     * 包含：连词、介词、助词、标点符号
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   bool - 如果是虚词返回 true
     */
    alias isFunctionWord = IsCategory!(functionWordTags);
    
    /**
     * 判断是否为专有名词
     * 
     * 包含：人名、机构名、地名、其他专名
     * 
     * 参数：
     *   pos: POSTag 枚举值
     * 
     * 返回：
     *   bool - 如果是专有名词返回 true
     */
    alias isProperNoun = IsCategory!(properNounTags);
}

/**
 * POSTag 的便捷扩展函数
 * 
 * 使用示例：
 * ```d
 * import etc.ltp.postags;
 * 
 * auto pos = POSTag.ns;
 * writeln(postagToString(pos));           // "ns"
 * writeln(postagDescription(pos));        // "地名"
 * writeln(postagIsNoun(pos));             // true
 * writeln(postagIsProperNoun(pos));       // true
 * ```
 */

/// 获取词性标签字符串
string postagToString(POSTag pos) {
    return POSTagHelper.toString(pos);
}

/// 获取词性中文描述
string postagDescription(POSTag pos) {
    return POSTagHelper.description(pos);
}

/// 获取词性英文描述
string postagEnglishDescription(POSTag pos) {
    return POSTagHelper.englishDescription(pos);
}

/// 判断是否为名词
bool postagIsNoun(POSTag pos) {
    return POSTagHelper.isNoun(pos);
}

/// 判断是否为动词
bool postagIsVerb(POSTag pos) {
    return POSTagHelper.isVerb(pos);
}

/// 判断是否为形容词
bool postagIsAdjective(POSTag pos) {
    return POSTagHelper.isAdjective(pos);
}

/// 判断是否为虚词
bool postagIsFunctionWord(POSTag pos) {
    return POSTagHelper.isFunctionWord(pos);
}

/// 判断是否为专有名词
bool postagIsProperNoun(POSTag pos) {
    return POSTagHelper.isProperNoun(pos);
}

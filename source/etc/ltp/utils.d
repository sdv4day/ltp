/**
 * LTP 工具函数模块
 * 提供文件读写、文本拆分等辅助功能
 */
module etc.ltp.utils;

import std.string;
import std.file;
import std.array;
import std.algorithm.comparison : max;
import std.utf;
import std.uni;

/**
 * 使用 std.uni 模块的字符检查函数
 */
bool isZhPunctuation(dchar c) {
    return c == '。' || c == '！' || c == '？' || c == '；' || c == '，';
}

bool isEnPunctuation(dchar c) {
    return c == '.' || c == '!' || c == '?' || c == ';' || c == ',';
}

bool isZhQuote(dchar c) {
    return c == '"' || c == '"';
}

bool isEnQuote(dchar c) {
    return c == '"' || c == '\'';
}

bool isOpenBracket(dchar c) {
    return c == '(' || c == '[' || c == '{' || c == '【' || c == '《';
}

bool isCloseBracket(dchar c) {
    return c == ')' || c == ']' || c == '}' || c == '】' || c == '》';
}

bool isSentenceEnding(dchar c, SplitOptions options) {
    return (options.useZh && isZhPunctuation(c)) || 
           (options.useEn && isEnPunctuation(c));
}

/**
 * 符号状态跟踪器
 */
struct SymbolTracker {
    int zhQuoteLevel = 0;
    int enQuoteLevel = 0;
    int bracketLevel = 0;
    
    void update(dchar c, SplitOptions options) {
        if (options.zhQuoteAsEntity && isZhQuote(c)) {
            zhQuoteLevel = (zhQuoteLevel + 1) % 2;
        }
        
        if (options.enQuoteAsEntity && isEnQuote(c)) {
            enQuoteLevel = (enQuoteLevel + 1) % 2;
        }
        
        if (options.bracketAsEntity) {
            if (isOpenBracket(c)) {
                bracketLevel++;
            } else if (isCloseBracket(c)) {
                bracketLevel = max(0, bracketLevel - 1);
            }
        }
    }
    
    bool isInsideSymbols() const {
        return zhQuoteLevel > 0 || enQuoteLevel > 0 || bracketLevel > 0;
    }
}

/**
 * 特殊情况检查器
 */
struct SpecialCaseChecker {
    string text;
    SplitOptions options;
    
    bool shouldSkip(size_t bytePos, dchar currentChar, size_t charLen) {
        if (currentChar == '.' && bytePos > 0 && bytePos + charLen < text.length) {
            auto prevChar = getPreviousChar(bytePos);
            auto nextChar = getNextChar(bytePos, charLen);
            
            if (std.uni.isNumber(prevChar) && std.uni.isNumber(nextChar)) {
                return true;
            }
            
            if (nextChar == '.') {
                return true;
            }
        }
        
        if (currentChar == '。' && bytePos + charLen < text.length) {
            auto nextChar = getNextChar(bytePos, charLen);
            if (nextChar == '。') {
                return true;
            }
        }
        
        return false;
    }
    
    dchar getPreviousChar(size_t currentPos) {
        if (currentPos == 0) return cast(dchar)0;
        
        size_t prevPos = currentPos - 1;
        while (prevPos > 0 && (text[prevPos] & 0xC0) == 0x80) {
            prevPos--;
        }
        
        try {
            size_t tempPos = prevPos;
            return decode(text, tempPos);
        } catch (Exception e) {
            return cast(dchar)0;
        }
    }
    
    dchar getNextChar(size_t currentPos, size_t charLen) {
        if (currentPos + charLen >= text.length) return cast(dchar)0;
        
        try {
            size_t tempPos = currentPos + charLen;
            return decode(text, tempPos);
        } catch (Exception e) {
            return cast(dchar)0;
        }
    }
}

/**
 * 安全地过滤字符串中的控制字符
 */
string filterControlChars(string input) {
    import std.string : strip;
    
    string result = strip(input);
    
    char[] filtered;
    filtered.reserve(result.length);
    foreach (char c; result) {
        if (c >= 32) {
            filtered ~= c;
        }
    }
    
    return cast(string)filtered;
}

/**
 * 句子拆分选项
 */
struct SplitOptions {
    bool useZh;
    bool useEn;
    bool bracketAsEntity;
    bool zhQuoteAsEntity;
    bool enQuoteAsEntity;
    
    static SplitOptions defaultOptions() {
        SplitOptions opts;
        opts.useZh = true;
        opts.useEn = true;
        opts.bracketAsEntity = true;
        opts.zhQuoteAsEntity = true;
        opts.enQuoteAsEntity = true;
        return opts;
    }
    
    static SplitOptions chineseOnly() {
        SplitOptions opts;
        opts.useZh = true;
        opts.useEn = false;
        opts.bracketAsEntity = true;
        opts.zhQuoteAsEntity = true;
        opts.enQuoteAsEntity = false;
        return opts;
    }
    
    static SplitOptions englishOnly() {
        SplitOptions opts;
        opts.useZh = false;
        opts.useEn = true;
        opts.bracketAsEntity = true;
        opts.zhQuoteAsEntity = false;
        opts.enQuoteAsEntity = true;
        return opts;
    }
}

/**
 * 将长文本拆分为句子
 * 
 * 参数：
 *   text: 待拆分的文本
 *   options: 拆分选项（默认使用 defaultOptions）
 * 
 * 返回：
 *   string[] - 拆分后的句子数组
 */
string[] splitSentences(string text, SplitOptions options = SplitOptions.defaultOptions()) {
    return splitSentencesPure(text, options);
}

/**
 * 将长文本拆分为句子（简单版本）
 */
string[] splitSentencesSimple(string text) {
    return splitSentences(text, SplitOptions.defaultOptions());
}

/**
 * 将长文本拆分为句子（纯 D 语言实现）
 *
 * 优化：预计算字节偏移表，避免 O(n²) 重复遍历
 */
string[] splitSentencesPure(string text, SplitOptions options = SplitOptions.defaultOptions()) {
    if (text.length == 0) {
        return [];
    }
    
    import std.string : strip;

    text = strip(text);

    auto symbolTracker = SymbolTracker();
    auto specialChecker = SpecialCaseChecker(text, options);

    size_t[] byteOffsets;
    dchar[] chars;

    size_t byteIdx = 0;
    foreach (dchar c; text.byCodePoint) {
        if (!isWhite(c)) {
            byteOffsets ~= byteIdx;
            chars ~= c;
        }
        byteIdx += codeLength!char(c);
    }

    if (chars.length == 0) {
        return [];
    }

    string[] result;
    size_t byteStart = 0;

    foreach (i, c; chars) {
        symbolTracker.update(c, options);

        bool isEnding = isSentenceEnding(c, options);

        if (isEnding && !symbolTracker.isInsideSymbols()) {
            size_t bytePos = byteOffsets[i];

            char[4] currentBuf;
            size_t charLen = encode(currentBuf, c);

            if (!specialChecker.shouldSkip(bytePos, c, charLen)) {
                string sentence = text[byteStart..bytePos + charLen];
                sentence = sentence.strip();
                sentence = filterControlChars(sentence);

                if (sentence.length > 0) {
                    result ~= sentence;
                }
            }
            byteStart = bytePos + charLen;
        }
    }

    if (byteStart < text.length) {
        string lastSentence = text[byteStart..$].strip();
        lastSentence = filterControlChars(lastSentence);
        if (lastSentence.length > 0) {
            result ~= lastSentence;
        }
    }

    return result;
}

/**
 * 将长文本拆分为句子（简单版本）
 */
string[] splitSentencesPureSimple(string text) {
    return splitSentencesPure(text, SplitOptions.defaultOptions());
}
